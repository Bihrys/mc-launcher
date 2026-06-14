use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde::de::DeserializeOwned;
use serde_json::Value;
use std::collections::HashMap;
use std::fs::{self, File};
use std::io;
use std::path::{Path, PathBuf};

pub type DownloadError = Box<dyn std::error::Error + Send + Sync + 'static>;

#[derive(Debug, Copy, Clone)]
enum DownloadSource {
    Official,
    Bmcl,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InstallResult {
    pub kind: String,
    pub game_version: String,
    pub loader_kind: String,
    pub loader_version: String,
    pub version_id: String,
    pub install_dir: PathBuf,
    pub downloaded_files: usize,
    pub message: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DownloadCatalog {
    source: String,
    latest_release: String,
    latest_snapshot: String,
    game_versions: Vec<GameEntry>,
    fabric_loaders: Vec<LoaderEntry>,
    quilt_loaders: Vec<LoaderEntry>,
    forge_installers: Vec<InstallerEntry>,
    neoforge_installers: Vec<InstallerEntry>,
    warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct GameEntry {
    id: String,
    version_type: String,
    release_time: String,
    url: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct LoaderEntry {
    version: String,
    stable: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct InstallerEntry {
    game_version: String,
    loader_version: String,
    url: String,
    release_time: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MojangManifest {
    latest: MojangLatest,
    versions: Vec<MojangVersion>,
}

#[derive(Debug, Deserialize)]
struct MojangLatest {
    release: String,
    snapshot: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MojangVersion {
    id: String,

    #[serde(rename = "type")]
    version_type: String,

    url: String,
    release_time: String,
}

#[derive(Debug, Deserialize)]
struct MetaLoaderVersion {
    version: String,
    stable: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct ForgeRoot {
    artifact: Option<String>,
    webpath: Option<String>,
    mcversion: Option<HashMap<String, Vec<u32>>>,
    number: Option<HashMap<String, ForgeVersion>>,
}

#[derive(Debug, Deserialize)]
struct ForgeVersion {
    branch: Option<String>,
    mcversion: Option<String>,
    version: Option<String>,
    modified: Option<i64>,
    files: Option<Vec<Vec<String>>>,
}

#[derive(Debug, Deserialize)]
struct NeoForgeApiResult {
    versions: Vec<String>,
}

pub fn fetch_download_catalog_json(source: &str) -> Result<String, DownloadError> {
    let source = parse_source(source)?;
    let catalog = fetch_download_catalog(source)?;

    Ok(serde_json::to_string(&catalog)?)
}

pub fn install_game_version(
    source: &str,
    game_version: &str,
    loader_kind: &str,
    loader_version: &str,
) -> Result<InstallResult, DownloadError> {
    let source = parse_source(source)?;
    let game_version = game_version.trim();
    let loader_kind = loader_kind.trim().to_ascii_lowercase();
    let loader_version = loader_version.trim();

    if game_version.is_empty() {
        return Err(simple_error("没有选择 Minecraft 版本。"));
    }

    match loader_kind.as_str() {
        "" | "vanilla" => install_vanilla(source, game_version),
        "fabric" => install_fabric_or_quilt(source, "fabric", game_version, loader_version),
        "quilt" => install_fabric_or_quilt(source, "quilt", game_version, loader_version),
        "forge" => download_loader_installer(source, "forge", game_version, loader_version),
        "neoforge" => download_loader_installer(source, "neoforge", game_version, loader_version),
        other => Err(simple_error(format!("不支持的加载器类型：{other}"))),
    }
}

fn fetch_download_catalog(source: DownloadSource) -> Result<DownloadCatalog, DownloadError> {
    let client = http_client()?;
    let mut warnings = Vec::new();

    let manifest: MojangManifest = get_json(&client, &manifest_url(source))?;

    let game_versions = manifest
        .versions
        .iter()
        .map(|version| GameEntry {
            id: version.id.clone(),
            version_type: version.version_type.clone(),
            release_time: version.release_time.clone(),
            url: inject_url(source, &version.url),
        })
        .collect::<Vec<_>>();

    let fabric_loaders = match fetch_meta_loaders(&client, source, "https://meta.fabricmc.net/v2/versions/loader") {
        Ok(value) => value,
        Err(err) => {
            warnings.push(format!("Fabric loader 列表获取失败：{err}"));
            Vec::new()
        }
    };

    let quilt_loaders = match fetch_meta_loaders(&client, source, "https://meta.quiltmc.org/v3/versions/loader") {
        Ok(value) => value,
        Err(err) => {
            warnings.push(format!("Quilt loader 列表获取失败：{err}"));
            Vec::new()
        }
    };

    let forge_installers = match fetch_forge_installers(&client, source) {
        Ok(value) => value,
        Err(err) => {
            warnings.push(format!("Forge 列表获取失败：{err}"));
            Vec::new()
        }
    };

    let neoforge_installers = match fetch_neoforge_installers(&client, source) {
        Ok(value) => value,
        Err(err) => {
            warnings.push(format!("NeoForge 列表获取失败：{err}"));
            Vec::new()
        }
    };

    Ok(DownloadCatalog {
        source: source.as_str().to_string(),
        latest_release: manifest.latest.release,
        latest_snapshot: manifest.latest.snapshot,
        game_versions,
        fabric_loaders,
        quilt_loaders,
        forge_installers,
        neoforge_installers,
        warnings,
    })
}

fn fetch_meta_loaders(
    client: &Client,
    source: DownloadSource,
    url: &str,
) -> Result<Vec<LoaderEntry>, DownloadError> {
    let url = inject_url(source, url);
    let values: Vec<MetaLoaderVersion> = get_json(client, &url)?;

    Ok(values
        .into_iter()
        .map(|item| LoaderEntry {
            version: item.version,
            stable: item.stable.unwrap_or(false),
        })
        .collect())
}

fn fetch_forge_installers(
    client: &Client,
    source: DownloadSource,
) -> Result<Vec<InstallerEntry>, DownloadError> {
    let url = inject_url(source, "https://hmcl.glavo.site/metadata/forge/");
    let root: ForgeRoot = get_json(client, &url)?;

    let artifact = root.artifact.unwrap_or_else(|| "forge".to_string());
    let webpath = root
        .webpath
        .unwrap_or_else(|| "https://maven.minecraftforge.net/net/minecraftforge/forge/".to_string());

    let mcversion = root.mcversion.unwrap_or_default();
    let number = root.number.unwrap_or_default();
    let mut out = Vec::new();

    for (game_version, builds) in mcversion {
        let game_version = if game_version == "1.7.10_pre4" {
            "1.7.10-pre4".to_string()
        } else {
            game_version
        };

        for build in builds {
            let Some(version) = number.get(&build.to_string()) else {
                continue;
            };

            let Some(loader_version) = version.version.as_ref() else {
                continue;
            };

            let Some(files) = version.files.as_ref() else {
                continue;
            };

            let mut installer_url = None;

            for file in files {
                if file.len() < 2 || file[1] != "installer" {
                    continue;
                }

                let ext = &file[0];
                let branch = version.branch.as_deref().unwrap_or_default();
                let mc = version.mcversion.as_deref().unwrap_or(&game_version);

                let classifier = if branch.is_empty() {
                    format!("{mc}-{loader_version}")
                } else {
                    format!("{mc}-{loader_version}-{branch}")
                };

                let file_name = format!("{artifact}-{classifier}-installer.{ext}");
                installer_url = Some(format!("{webpath}{classifier}/{file_name}"));
                break;
            }

            if let Some(url) = installer_url {
                out.push(InstallerEntry {
                    game_version: game_version.clone(),
                    loader_version: loader_version.clone(),
                    url: inject_url(source, &url),
                    release_time: version.modified.map(|value| value.to_string()),
                });
            }
        }
    }

    out.sort_by(|a, b| {
        b.game_version
            .cmp(&a.game_version)
            .then_with(|| b.loader_version.cmp(&a.loader_version))
    });

    Ok(out)
}

fn fetch_neoforge_installers(
    client: &Client,
    source: DownloadSource,
) -> Result<Vec<InstallerEntry>, DownloadError> {
    let old_url = inject_url(
        source,
        "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/forge",
    );
    let new_url = inject_url(
        source,
        "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge",
    );

    let mut out = Vec::new();

    let old_result: NeoForgeApiResult = get_json(client, &old_url)?;
    for version in old_result.versions {
        out.push(InstallerEntry {
            game_version: "1.20.1".to_string(),
            loader_version: normalize_neoforge_version(&version),
            url: inject_url(source, &format!(
                "https://maven.neoforged.net/releases/net/neoforged/forge/{version}/forge-{version}-installer.jar"
            )),
            release_time: None,
        });
    }

    let new_result: NeoForgeApiResult = get_json(client, &new_url)?;
    for version in new_result.versions {
        let Some(game_version) = neoforge_game_version(&version) else {
            continue;
        };

        out.push(InstallerEntry {
            game_version,
            loader_version: normalize_neoforge_version(&version),
            url: inject_url(source, &format!(
                "https://maven.neoforged.net/releases/net/neoforged/neoforge/{version}/neoforge-{version}-installer.jar"
            )),
            release_time: None,
        });
    }

    out.sort_by(|a, b| {
        b.game_version
            .cmp(&a.game_version)
            .then_with(|| b.loader_version.cmp(&a.loader_version))
    });

    Ok(out)
}

fn install_vanilla(source: DownloadSource, game_version: &str) -> Result<InstallResult, DownloadError> {
    let client = http_client()?;
    let manifest: MojangManifest = get_json(&client, &manifest_url(source))?;

    let version = manifest
        .versions
        .into_iter()
        .find(|version| version.id == game_version)
        .ok_or_else(|| simple_error(format!("没有找到 Minecraft 版本：{game_version}")))?;

    let version_json_url = inject_url(source, &version.url);
    let version_json: Value = get_json(&client, &version_json_url)?;

    install_version_json(source, &client, game_version, &version_json, "vanilla", "", game_version)
}

fn install_fabric_or_quilt(
    source: DownloadSource,
    loader_kind: &str,
    game_version: &str,
    loader_version: &str,
) -> Result<InstallResult, DownloadError> {
    if loader_version.is_empty() {
        return Err(simple_error(format!("没有选择 {loader_kind} loader 版本。")));
    }

    let mut base = install_vanilla(source, game_version)?;
    let client = http_client()?;

    let profile_url = match loader_kind {
        "fabric" => format!(
            "https://meta.fabricmc.net/v2/versions/loader/{game_version}/{loader_version}/profile/json"
        ),
        "quilt" => format!(
            "https://meta.quiltmc.org/v3/versions/loader/{game_version}/{loader_version}/profile/json"
        ),
        _ => return Err(simple_error("内部错误：未知 loader kind。")),
    };

    let profile_url = inject_url(source, &profile_url);
    let profile_json: Value = get_json(&client, &profile_url)?;

    let version_id = profile_json
        .get("id")
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .unwrap_or_else(|| format!("{loader_kind}-loader-{loader_version}-{game_version}"));

    let root = minecraft_root()?;
    let version_dir = root.join("versions").join(&version_id);
    fs::create_dir_all(&version_dir)?;

    let version_json_path = version_dir.join(format!("{version_id}.json"));
    fs::write(&version_json_path, serde_json::to_string_pretty(&profile_json)?)?;

    let library_count = download_libraries_from_version_json(source, &client, &root, &profile_json)?;

    base.kind = "loader".to_string();
    base.loader_kind = loader_kind.to_string();
    base.loader_version = loader_version.to_string();
    base.version_id = version_id;
    base.downloaded_files += library_count + 1;
    base.message = format!(
        "{loader_kind} 已安装。已先安装原版 {game_version}，并写入 loader profile。"
    );

    Ok(base)
}

fn download_loader_installer(
    source: DownloadSource,
    loader_kind: &str,
    game_version: &str,
    loader_version: &str,
) -> Result<InstallResult, DownloadError> {
    if loader_version.is_empty() {
        return Err(simple_error(format!("没有选择 {loader_kind} 版本。")));
    }

    let client = http_client()?;
    let catalog = fetch_download_catalog(source)?;

    let installers = match loader_kind {
        "forge" => catalog.forge_installers,
        "neoforge" => catalog.neoforge_installers,
        _ => return Err(simple_error("内部错误：未知 installer kind。")),
    };

    let installer = installers
        .into_iter()
        .find(|item| item.game_version == game_version && item.loader_version == loader_version)
        .ok_or_else(|| simple_error(format!(
            "没有找到 {loader_kind} installer：Minecraft {game_version}, loader {loader_version}"
        )))?;

    let cache_dir = cache_root()?.join("installers").join(loader_kind);
    fs::create_dir_all(&cache_dir)?;

    let file_name = file_name_from_url(&installer.url);
    let target = cache_dir.join(file_name);

    download_to_file(&client, &installer.url, &target)?;

    Ok(InstallResult {
        kind: "installer".to_string(),
        game_version: game_version.to_string(),
        loader_kind: loader_kind.to_string(),
        loader_version: loader_version.to_string(),
        version_id: format!("{loader_kind}-{loader_version}-{game_version}"),
        install_dir: target,
        downloaded_files: 1,
        message: format!(
            "{loader_kind} installer 已下载。下一步需要实现 HMCL 的 installer processor 执行流程。"
        ),
    })
}

fn install_version_json(
    source: DownloadSource,
    client: &Client,
    game_version: &str,
    version_json: &Value,
    loader_kind: &str,
    loader_version: &str,
    version_id: &str,
) -> Result<InstallResult, DownloadError> {
    let root = minecraft_root()?;
    let version_dir = root.join("versions").join(version_id);
    fs::create_dir_all(&version_dir)?;

    let version_json_path = version_dir.join(format!("{version_id}.json"));
    fs::write(&version_json_path, serde_json::to_string_pretty(version_json)?)?;

    let mut downloaded_files = 1;

    if let Some(client_download) = version_json
        .get("downloads")
        .and_then(|value| value.get("client"))
    {
        if let Some(url) = client_download.get("url").and_then(Value::as_str) {
            let jar_path = version_dir.join(format!("{version_id}.jar"));
            download_to_file(client, &inject_url(source, url), &jar_path)?;
            downloaded_files += 1;
        }
    }

    downloaded_files += download_libraries_from_version_json(source, client, &root, version_json)?;
    downloaded_files += download_assets_from_version_json(source, client, &root, version_json)?;

    Ok(InstallResult {
        kind: "game".to_string(),
        game_version: game_version.to_string(),
        loader_kind: loader_kind.to_string(),
        loader_version: loader_version.to_string(),
        version_id: version_id.to_string(),
        install_dir: version_dir,
        downloaded_files,
        message: format!("Minecraft {game_version} 原版文件已下载。"),
    })
}

fn download_libraries_from_version_json(
    source: DownloadSource,
    client: &Client,
    root: &Path,
    version_json: &Value,
) -> Result<usize, DownloadError> {
    let libraries = match version_json.get("libraries").and_then(Value::as_array) {
        Some(value) => value,
        None => return Ok(0),
    };

    let mut count = 0;

    for lib in libraries {
        if let Some(artifact) = lib
            .get("downloads")
            .and_then(|value| value.get("artifact"))
        {
            if download_library_artifact(source, client, root, artifact)? {
                count += 1;
            }
        } else if let Some(name) = lib.get("name").and_then(Value::as_str) {
            let base_url = lib
                .get("url")
                .and_then(Value::as_str)
                .unwrap_or("https://libraries.minecraft.net/");

            if download_library_from_name(source, client, root, base_url, name)? {
                count += 1;
            }
        }

        let native_key = match std::env::consts::OS {
            "linux" => "linux",
            "macos" => "osx",
            "windows" => "windows",
            _ => "",
        };

        if native_key.is_empty() {
            continue;
        }

        let Some(classifier_name) = lib
            .get("natives")
            .and_then(|value| value.get(native_key))
            .and_then(Value::as_str)
        else {
            continue;
        };

        let classifier_name = classifier_name.replace("${arch}", if cfg!(target_pointer_width = "64") { "64" } else { "32" });

        if let Some(classifier) = lib
            .get("downloads")
            .and_then(|value| value.get("classifiers"))
            .and_then(|value| value.get(&classifier_name))
        {
            if download_library_artifact(source, client, root, classifier)? {
                count += 1;
            }
        }
    }

    Ok(count)
}

fn download_library_artifact(
    source: DownloadSource,
    client: &Client,
    root: &Path,
    artifact: &Value,
) -> Result<bool, DownloadError> {
    let Some(path) = artifact.get("path").and_then(Value::as_str) else {
        return Ok(false);
    };

    let Some(url) = artifact.get("url").and_then(Value::as_str) else {
        return Ok(false);
    };

    if url.is_empty() {
        return Ok(false);
    }

    let target = root.join("libraries").join(path);
    download_to_file(client, &inject_url(source, url), &target)?;

    Ok(true)
}

fn download_library_from_name(
    source: DownloadSource,
    client: &Client,
    root: &Path,
    base_url: &str,
    descriptor: &str,
) -> Result<bool, DownloadError> {
    let Some(path) = maven_path(descriptor) else {
        return Ok(false);
    };

    let base_url = if base_url.ends_with('/') {
        base_url.to_string()
    } else {
        format!("{base_url}/")
    };

    let url = inject_url(source, &(base_url + &path));
    let target = root.join("libraries").join(path);

    download_to_file(client, &url, &target)?;

    Ok(true)
}

fn download_assets_from_version_json(
    source: DownloadSource,
    client: &Client,
    root: &Path,
    version_json: &Value,
) -> Result<usize, DownloadError> {
    let Some(asset_index) = version_json.get("assetIndex") else {
        return Ok(0);
    };

    let Some(asset_id) = asset_index.get("id").and_then(Value::as_str) else {
        return Ok(0);
    };

    let Some(asset_index_url) = asset_index.get("url").and_then(Value::as_str) else {
        return Ok(0);
    };

    let asset_index_url = inject_url(source, asset_index_url);
    let asset_json: Value = get_json(client, &asset_index_url)?;

    let index_path = root
        .join("assets")
        .join("indexes")
        .join(format!("{asset_id}.json"));

    ensure_parent(&index_path)?;
    fs::write(&index_path, serde_json::to_string_pretty(&asset_json)?)?;

    let mut count = 1;

    let Some(objects) = asset_json.get("objects").and_then(Value::as_object) else {
        return Ok(count);
    };

    for object in objects.values() {
        let Some(hash) = object.get("hash").and_then(Value::as_str) else {
            continue;
        };

        if hash.len() < 2 {
            continue;
        }

        let prefix = &hash[0..2];
        let target = root.join("assets").join("objects").join(prefix).join(hash);

        if target.exists() && target.metadata().map(|m| m.len() > 0).unwrap_or(false) {
            continue;
        }

        let url = match source {
            DownloadSource::Official => {
                format!("https://resources.download.minecraft.net/{prefix}/{hash}")
            }
            DownloadSource::Bmcl => {
                format!("https://bmclapi2.bangbang93.com/assets/{prefix}/{hash}")
            }
        };

        download_to_file(client, &url, &target)?;
        count += 1;
    }

    Ok(count)
}

fn manifest_url(source: DownloadSource) -> String {
    match source {
        DownloadSource::Official => "https://piston-meta.mojang.com/mc/game/version_manifest.json".to_string(),
        DownloadSource::Bmcl => "https://bmclapi2.bangbang93.com/mc/game/version_manifest.json".to_string(),
    }
}

fn inject_url(source: DownloadSource, url: &str) -> String {
    if !matches!(source, DownloadSource::Bmcl) {
        return url.to_string();
    }

    let replacements = [
        ("https://bmclapi2.bangbang93.com", "https://bmclapi2.bangbang93.com"),
        ("https://launchermeta.mojang.com", "https://bmclapi2.bangbang93.com"),
        ("https://piston-meta.mojang.com", "https://bmclapi2.bangbang93.com"),
        ("https://piston-data.mojang.com", "https://bmclapi2.bangbang93.com"),
        ("https://launcher.mojang.com", "https://bmclapi2.bangbang93.com"),
        ("https://libraries.minecraft.net", "https://bmclapi2.bangbang93.com/libraries"),
        ("https://maven.minecraftforge.net", "https://bmclapi2.bangbang93.com/maven"),
        ("https://files.minecraftforge.net/maven", "https://bmclapi2.bangbang93.com/maven"),
        ("http://files.minecraftforge.net/maven", "https://bmclapi2.bangbang93.com/maven"),
        ("https://maven.neoforged.net/releases/", "https://bmclapi2.bangbang93.com/maven/"),
        ("https://meta.fabricmc.net", "https://bmclapi2.bangbang93.com/fabric-meta"),
        ("https://maven.fabricmc.net", "https://bmclapi2.bangbang93.com/maven"),
        ("https://hmcl.glavo.site/metadata/forge", "https://bmclapi2.bangbang93.com/maven/net/minecraftforge/forge/json"),
    ];

    for (from, to) in replacements {
        if let Some(rest) = url.strip_prefix(from) {
            return format!("{to}{rest}");
        }
    }

    url.to_string()
}

fn maven_path(descriptor: &str) -> Option<String> {
    let mut parts = descriptor.split(':').collect::<Vec<_>>();

    if parts.len() < 3 {
        return None;
    }

    let mut ext = "jar".to_string();

    if let Some(last) = parts.last_mut() {
        if let Some((before, after)) = last.split_once('@') {
            *last = before;
            ext = after.to_string();
        }
    }

    let group = parts[0].replace('.', "/");
    let artifact = parts[1];
    let version = parts[2];

    let file_name = if parts.len() >= 4 {
        let classifier = parts[3];
        format!("{artifact}-{version}-{classifier}.{ext}")
    } else {
        format!("{artifact}-{version}.{ext}")
    };

    Some(format!("{group}/{artifact}/{version}/{file_name}"))
}

fn parse_source(source: &str) -> Result<DownloadSource, DownloadError> {
    match source.trim().to_ascii_lowercase().as_str() {
        "" | "official" | "mojang" => Ok(DownloadSource::Official),
        "bmcl" | "bmclapi" => Ok(DownloadSource::Bmcl),
        other => Err(simple_error(format!("未知下载源：{other}"))),
    }
}

fn normalize_neoforge_version(version: &str) -> String {
    version
        .strip_prefix("1.20.1-")
        .unwrap_or(version)
        .to_string()
}

fn neoforge_game_version(version: &str) -> Option<String> {
    let si1 = version.find('.')?;
    let si2 = version[si1 + 1..].find('.').map(|v| v + si1 + 1)?;
    let major = version[..si1].parse::<i32>().ok()?;

    if major == 0 {
        return Some(version[si1 + 1..si2].to_string());
    }

    if major >= 26 {
        let si3 = version[si2 + 1..].find('.').map(|v| v + si2 + 1)?;
        let patch = version[si2 + 1..si3].parse::<i32>().ok()?;

        let ver = if patch == 0 {
            version[..si2].to_string()
        } else {
            version[..si3].to_string()
        };

        if let Some(separator) = version.find('+') {
            Some(format!("{ver}-{}", &version[separator + 1..]))
        } else {
            Some(ver)
        }
    } else {
        let minor = version[si1 + 1..si2].parse::<i32>().ok()?;

        if minor == 0 {
            Some(format!("1.{}", &version[..si1]))
        } else {
            Some(format!("1.{}", &version[..si2]))
        }
    }
}

fn http_client() -> Result<Client, DownloadError> {
    Ok(Client::builder()
        .user_agent("mc-launcher/0.1 download-center")
        .build()?)
}

fn get_json<T: DeserializeOwned>(client: &Client, url: &str) -> Result<T, DownloadError> {
    Ok(client
        .get(url)
        .send()?
        .error_for_status()?
        .json()?)
}

fn download_to_file(client: &Client, url: &str, target: &Path) -> Result<(), DownloadError> {
    if target.exists() && target.metadata().map(|m| m.len() > 0).unwrap_or(false) {
        return Ok(());
    }

    ensure_parent(target)?;

    let mut response = client.get(url).send()?.error_for_status()?;
    let mut file = File::create(target)?;
    response.copy_to(&mut file)?;

    Ok(())
}

fn ensure_parent(path: &Path) -> Result<(), DownloadError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    Ok(())
}

fn minecraft_root() -> Result<PathBuf, DownloadError> {
    Ok(data_root()?.join("minecraft"))
}

fn cache_root() -> Result<PathBuf, DownloadError> {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".cache").join("mc-launcher"))
}

fn data_root() -> Result<PathBuf, DownloadError> {
    if let Some(value) = std::env::var_os("XDG_DATA_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".local").join("share").join("mc-launcher"))
}

fn home_dir() -> Result<PathBuf, DownloadError> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
}

fn file_name_from_url(url: &str) -> String {
    url.rsplit('/')
        .next()
        .filter(|value| !value.is_empty())
        .unwrap_or("download.bin")
        .to_string()
}

impl DownloadSource {
    fn as_str(self) -> &'static str {
        match self {
            DownloadSource::Official => "official",
            DownloadSource::Bmcl => "bmcl",
        }
    }
}

fn simple_error(message: impl Into<String>) -> DownloadError {
    Box::new(io::Error::other(message.into()))
}
