use flate2::read::GzDecoder;
use serde::Deserialize;
use std::cmp::Ordering;
use std::ffi::OsStr;
use std::fs::{self, File};
use std::io;
use std::path::{Path, PathBuf};
use tar::Archive;

const DISCO_API_ROOT: &str = "https://api.foojay.io/disco/v3.0";

pub type JavaDownloadError = Box<dyn std::error::Error + Send + Sync + 'static>;

#[derive(Debug, Clone)]
pub struct JavaDownloadResult {
    pub distribution: String,
    pub package_type: String,
    pub major: u32,
    pub java_version: String,
    pub distribution_version: String,
    pub file_name: String,
    pub archive_path: PathBuf,
    pub install_dir: PathBuf,
    pub java_binary: PathBuf,
}

#[derive(Debug, Deserialize)]
struct DiscoResponse {
    result: Vec<DiscoPackage>,
}

#[derive(Debug, Clone, Deserialize)]
struct DiscoPackage {
    #[serde(rename = "archive_type")]
    archive_type: String,

    distribution: String,

    #[serde(rename = "java_version")]
    java_version: String,

    #[serde(rename = "distribution_version")]
    distribution_version: String,

    #[serde(rename = "jdk_version")]
    jdk_version: u32,

    #[serde(rename = "package_type")]
    package_type: String,

    #[serde(rename = "javafx_bundled")]
    javafx_bundled: bool,

    #[serde(rename = "directly_downloadable")]
    directly_downloadable: bool,

    filename: String,

    links: Option<DiscoLinks>,
}

#[derive(Debug, Clone, Deserialize)]
struct DiscoLinks {
    #[serde(rename = "pkg_download_redirect")]
    pkg_download_redirect: Option<String>,
}

pub fn download_java_runtime(
    distribution: &str,
    major: u32,
    package_type: &str,
) -> Result<JavaDownloadResult, JavaDownloadError> {
    let distribution = normalize_distribution(distribution)?;
    let package_type = normalize_package_type(package_type)?;
    let operating_system = current_disco_os()?;
    let architecture = current_disco_arch()?;
    let archive_type = if operating_system == "windows" { "zip" } else { "tar.gz" };

    if archive_type != "tar.gz" {
        return Err(simple_error("当前第一版只实现 Linux/macOS tar.gz 下载与解压。"));
    }

    let api_url = format!(
        "{DISCO_API_ROOT}/packages?distribution={distribution}&operating_system={operating_system}&architecture={architecture}&archive_type={archive_type}&directly_downloadable=true{}",
        if operating_system == "linux" {
            "&lib_c_type=glibc"
        } else {
            ""
        }
    );

    let client = reqwest::blocking::Client::builder()
        .user_agent("mc-launcher/0.1 JavaDownloader")
        .build()?;

    let response: DiscoResponse = client
        .get(&api_url)
        .send()?
        .error_for_status()?
        .json()?;

    let mut candidates: Vec<DiscoPackage> = response
        .result
        .into_iter()
        .filter(|pkg| pkg.distribution.eq_ignore_ascii_case(distribution))
        .filter(|pkg| pkg.archive_type == archive_type)
        .filter(|pkg| pkg.directly_downloadable)
        .filter(|pkg| pkg.jdk_version == major)
        .filter(|pkg| pkg.package_type.eq_ignore_ascii_case(package_type))
        .filter(|pkg| !pkg.javafx_bundled)
        .filter(|pkg| {
            pkg.links
                .as_ref()
                .and_then(|links| links.pkg_download_redirect.as_ref())
                .is_some()
        })
        .collect();

    if candidates.is_empty() {
        return Err(simple_error(format!(
            "没有找到可直接下载的 Java：distribution={distribution}, major={major}, package_type={package_type}"
        )));
    }

    candidates.sort_by(|a, b| {
        compare_version_strings(&a.distribution_version, &b.distribution_version)
            .then_with(|| a.java_version.cmp(&b.java_version))
    });

    let selected = candidates
        .pop()
        .ok_or_else(|| simple_error("没有可用 Java 下载项。"))?;

    let download_url = selected
        .links
        .as_ref()
        .and_then(|links| links.pkg_download_redirect.as_ref())
        .ok_or_else(|| simple_error("Java 下载项缺少下载链接。"))?
        .clone();

    let cache_dir = cache_root()?.join("java");
    fs::create_dir_all(&cache_dir)?;

    let archive_path = cache_dir.join(safe_segment(&selected.filename));

    let mut download_response = client.get(download_url).send()?.error_for_status()?;
    let mut archive_file = File::create(&archive_path)?;
    download_response.copy_to(&mut archive_file)?;

    let install_name = format!(
        "{}-{}-{}-{}",
        distribution,
        package_type,
        major,
        safe_segment(&selected.distribution_version)
    );

    let install_dir = data_root()?.join("java").join(install_name);

    if install_dir.exists() {
        fs::remove_dir_all(&install_dir)?;
    }

    fs::create_dir_all(&install_dir)?;

    let archive_file = File::open(&archive_path)?;
    let decoder = GzDecoder::new(archive_file);
    let mut archive = Archive::new(decoder);
    archive.unpack(&install_dir)?;

    let java_binary = find_java_binary(&install_dir)
        .ok_or_else(|| simple_error("Java 已解压，但没有找到 bin/java。"))?;

    Ok(JavaDownloadResult {
        distribution: distribution.to_string(),
        package_type: package_type.to_string(),
        major,
        java_version: selected.java_version,
        distribution_version: selected.distribution_version,
        file_name: selected.filename,
        archive_path,
        install_dir,
        java_binary,
    })
}

fn normalize_distribution(value: &str) -> Result<&'static str, JavaDownloadError> {
    match value.trim().to_ascii_lowercase().as_str() {
        "temurin" => Ok("temurin"),
        "liberica" => Ok("liberica"),
        "zulu" => Ok("zulu"),
        "graalvm" => Ok("graalvm"),
        "semeru" => Ok("semeru"),
        "corretto" => Ok("corretto"),
        other => Err(simple_error(format!("不支持的 Java 发行版：{other}"))),
    }
}

fn normalize_package_type(value: &str) -> Result<&'static str, JavaDownloadError> {
    match value.trim().to_ascii_lowercase().as_str() {
        "jdk" => Ok("jdk"),
        "jre" => Ok("jre"),
        other => Err(simple_error(format!("不支持的 Java 包类型：{other}"))),
    }
}

fn current_disco_os() -> Result<&'static str, JavaDownloadError> {
    match std::env::consts::OS {
        "linux" => Ok("linux"),
        "macos" => Ok("macos"),
        "windows" => Ok("windows"),
        other => Err(simple_error(format!("暂不支持的系统：{other}"))),
    }
}

fn current_disco_arch() -> Result<&'static str, JavaDownloadError> {
    match std::env::consts::ARCH {
        "x86_64" => Ok("x86_64"),
        "x86" => Ok("x86"),
        "aarch64" => Ok("arm64"),
        "arm" => Ok("arm32"),
        "riscv64" => Ok("riscv64"),
        "powerpc64" => Ok("ppc64"),
        "powerpc64le" => Ok("ppc64le"),
        "s390x" => Ok("s390x"),
        other => Err(simple_error(format!("暂不支持的 CPU 架构：{other}"))),
    }
}

fn cache_root() -> Result<PathBuf, JavaDownloadError> {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.as_os_str().is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".cache").join("mc-launcher"))
}

fn data_root() -> Result<PathBuf, JavaDownloadError> {
    if let Some(value) = std::env::var_os("XDG_DATA_HOME") {
        if !value.as_os_str().is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".local").join("share").join("mc-launcher"))
}

fn home_dir() -> Result<PathBuf, JavaDownloadError> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
}

fn find_java_binary(root: &Path) -> Option<PathBuf> {
    let mut stack = vec![root.to_path_buf()];

    while let Some(dir) = stack.pop() {
        let Ok(entries) = fs::read_dir(&dir) else {
            continue;
        };

        for entry in entries.flatten() {
            let path = entry.path();

            if path.is_dir() {
                stack.push(path);
                continue;
            }

            if path.file_name() == Some(OsStr::new("java"))
                && path.parent().and_then(Path::file_name) == Some(OsStr::new("bin"))
            {
                return Some(path);
            }
        }
    }

    None
}

fn compare_version_strings(a: &str, b: &str) -> Ordering {
    version_score(a).cmp(&version_score(b)).then_with(|| a.cmp(b))
}

fn version_score(value: &str) -> Vec<u64> {
    value
        .split(|ch: char| !ch.is_ascii_digit())
        .filter(|part| !part.is_empty())
        .filter_map(|part| part.parse::<u64>().ok())
        .collect()
}

fn safe_segment(value: &str) -> String {
    let mut out = String::new();

    for ch in value.chars() {
        if ch.is_ascii_alphanumeric() || ch == '.' || ch == '-' || ch == '_' || ch == '+' {
            out.push(ch);
        } else {
            out.push('_');
        }
    }

    if out.is_empty() {
        "unknown".to_string()
    } else {
        out
    }
}

fn simple_error(message: impl Into<String>) -> JavaDownloadError {
    Box::new(io::Error::new(io::ErrorKind::Other, message.into()))
}
