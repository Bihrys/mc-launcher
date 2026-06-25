use super::super::model::{DownloadCenterError, DownloadSourceKind, InstallResult};
use super::super::repository::DownloadRepository;
use super::super::resolver::{DownloadResolver, simple_error};
use super::libraries::LibraryResolver;
use crate::download::DownloadManager;
use serde_json::Value;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;
use zip::ZipArchive;

pub struct ForgeProcessor;

impl ForgeProcessor {
    pub fn install_installer(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        loader_kind: &str,
        game_version: &str,
        loader_version: &str,
        installer_path: &Path,
    ) -> Result<InstallResult, DownloadCenterError> {
        manager.set_message(format!("正在解析 {loader_kind} installer profile..."))?;

        let profile_text = Self::read_zip_text(installer_path, &["install_profile.json"])?;
        let profile: Value = serde_json::from_str(&profile_text)?;

        let version_json =
            Self::read_zip_text(installer_path, &["version.json", "data/client.lzma"])
                .ok()
                .and_then(|text| serde_json::from_str::<Value>(&text).ok());

        let version_info = profile
            .get("versionInfo")
            .cloned()
            .or(version_json)
            .ok_or_else(|| {
                simple_error("installer 中没有 versionInfo/version.json，无法生成版本。")
            })?;

        let version_id = version_info
            .get("id")
            .and_then(Value::as_str)
            .map(ToString::to_string)
            .unwrap_or_else(|| format!("{loader_kind}-{loader_version}-{game_version}"));

        let root = DownloadRepository::minecraft_root()?;
        let version_dir = root.join("versions").join(&version_id);
        fs::create_dir_all(&version_dir)?;

        let version_json_path = version_dir.join(format!("{version_id}.json"));
        fs::write(
            &version_json_path,
            serde_json::to_string_pretty(&version_info)?,
        )?;
        manager.track_created_file(version_json_path.clone())?;

        let mut files = Vec::new();

        manager.set_message(format!("正在收集 {loader_kind} libraries..."))?;

        files.extend(LibraryResolver::collect_libraries_from_version_json(
            source,
            &root,
            &version_info,
        )?);

        if let Some(libraries) = profile.get("libraries").and_then(Value::as_array) {
            let wrapper = serde_json::json!({ "libraries": libraries });
            files.extend(LibraryResolver::collect_libraries_from_version_json(
                source, &root, &wrapper,
            )?);
        }

        let downloaded_libraries = manager.download_files(files)?;

        let mut executed_processors = 0;

        if profile.get("processors").is_some() {
            manager.set_message(format!("正在执行 {loader_kind} installer processors..."))?;
            executed_processors = Self::run_processors(
                manager,
                &root,
                installer_path,
                &profile,
                &version_info,
                game_version,
            )?;
        }

        Ok(InstallResult {
            kind: "loader".to_string(),
            game_version: game_version.to_string(),
            loader_kind: loader_kind.to_string(),
            loader_version: loader_version.to_string(),
            version_id,
            install_dir: version_dir,
            downloaded_files: downloaded_libraries + 1,
            message: format!(
                "{loader_kind} 已安装。已写入 version json，下载 libraries，并执行 {executed_processors} 个 processor。"
            ),
        })
    }

    fn run_processors(
        manager: &DownloadManager,
        root: &Path,
        installer_path: &Path,
        profile: &Value,
        version_info: &Value,
        game_version: &str,
    ) -> Result<usize, DownloadCenterError> {
        let Some(processors) = profile.get("processors").and_then(Value::as_array) else {
            return Ok(0);
        };

        let libraries_dir = root.join("libraries");
        let version_id = version_info
            .get("id")
            .and_then(Value::as_str)
            .unwrap_or(game_version);

        let minecraft_jar = root
            .join("versions")
            .join(version_id)
            .join(format!("{version_id}.jar"));

        let mut count = 0;

        for processor in processors {
            manager.check_cancelled()?;

            if !Self::processor_is_for_client(processor) {
                continue;
            }

            let Some(jar_descriptor) = processor.get("jar").and_then(Value::as_str) else {
                continue;
            };

            let Some(jar_path) = Self::artifact_path(&libraries_dir, jar_descriptor) else {
                continue;
            };

            if !jar_path.exists() {
                continue;
            }

            let Some(main_class) = Self::main_class_from_jar(&jar_path)? else {
                continue;
            };

            let mut classpath = vec![jar_path.clone()];

            if let Some(items) = processor.get("classpath").and_then(Value::as_array) {
                for item in items {
                    let Some(descriptor) = item.as_str() else {
                        continue;
                    };

                    if let Some(path) = Self::artifact_path(&libraries_dir, descriptor) {
                        classpath.push(path);
                    }
                }
            }

            let classpath_string = classpath
                .iter()
                .map(|path| path.to_string_lossy().to_string())
                .collect::<Vec<_>>()
                .join(if cfg!(windows) { ";" } else { ":" });

            let mut args = Vec::new();

            if let Some(raw_args) = processor.get("args").and_then(Value::as_array) {
                for arg in raw_args {
                    let Some(arg) = arg.as_str() else {
                        continue;
                    };

                    args.push(Self::replace_processor_token(
                        arg,
                        root,
                        &libraries_dir,
                        installer_path,
                        &minecraft_jar,
                        game_version,
                    ));
                }
            }

            manager.set_message(format!("正在执行 processor：{main_class}"))?;

            let status = Command::new("java")
                .arg("-cp")
                .arg(classpath_string)
                .arg(main_class)
                .args(args)
                .status()?;

            if !status.success() {
                return Err(simple_error(format!("Forge processor 执行失败：{status}")));
            }

            count += 1;
        }

        Ok(count)
    }

    fn processor_is_for_client(processor: &Value) -> bool {
        let Some(sides) = processor.get("sides").and_then(Value::as_array) else {
            return true;
        };

        sides.iter().any(|side| side.as_str() == Some("client"))
    }

    fn artifact_path(libraries_dir: &Path, descriptor: &str) -> Option<PathBuf> {
        DownloadResolver::maven_path(descriptor).map(|path| libraries_dir.join(path))
    }

    fn replace_processor_token(
        value: &str,
        root: &Path,
        libraries_dir: &Path,
        installer_path: &Path,
        minecraft_jar: &Path,
        game_version: &str,
    ) -> String {
        if value.starts_with('[') && value.ends_with(']') {
            let descriptor = &value[1..value.len() - 1];

            if let Some(path) = Self::artifact_path(libraries_dir, descriptor) {
                return path.to_string_lossy().to_string();
            }
        }

        value
            .replace("{ROOT}", &root.to_string_lossy())
            .replace("{LIBRARY_DIR}", &libraries_dir.to_string_lossy())
            .replace("{INSTALLER}", &installer_path.to_string_lossy())
            .replace("{MINECRAFT_JAR}", &minecraft_jar.to_string_lossy())
            .replace("{MINECRAFT_VERSION}", game_version)
            .replace("{SIDE}", "client")
    }

    fn main_class_from_jar(path: &Path) -> Result<Option<String>, DownloadCenterError> {
        let file = fs::File::open(path)?;
        let mut zip = ZipArchive::new(file)?;

        let Ok(mut manifest) = zip.by_name("META-INF/MANIFEST.MF") else {
            return Ok(None);
        };

        let mut text = String::new();
        manifest.read_to_string(&mut text)?;

        for line in text.lines() {
            if let Some(value) = line.strip_prefix("Main-Class:") {
                return Ok(Some(value.trim().to_string()));
            }
        }

        Ok(None)
    }

    fn read_zip_text(path: &Path, names: &[&str]) -> Result<String, DownloadCenterError> {
        let file = fs::File::open(path)?;
        let mut zip = ZipArchive::new(file)?;

        for name in names {
            if let Ok(mut file) = zip.by_name(name) {
                let mut text = String::new();
                file.read_to_string(&mut text)?;
                return Ok(text);
            }
        }

        Err(simple_error(format!(
            "installer 中找不到文件：{}",
            names.join(", ")
        )))
    }
}
