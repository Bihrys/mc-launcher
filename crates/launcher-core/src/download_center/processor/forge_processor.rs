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
        base_version_id: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        manager.set_message(format!("正在解析 {loader_kind} installer profile..."))?;

        let profile_text = Self::read_zip_text(installer_path, &["install_profile.json"])?;
        let profile: Value = serde_json::from_str(&profile_text)?;

        let version_json =
            Self::read_zip_text(installer_path, &["version.json", "data/client.lzma"])
                .ok()
                .and_then(|text| serde_json::from_str::<Value>(&text).ok());

        let mut version_info = profile
            .get("versionInfo")
            .cloned()
            .or(version_json)
            .ok_or_else(|| {
                simple_error("installer 中没有 versionInfo/version.json，无法生成版本。")
            })?;

        if version_info.get("inheritsFrom").is_none() {
            if let Some(object) = version_info.as_object_mut() {
                object.insert(
                    "inheritsFrom".to_string(),
                    Value::String(base_version_id.to_string()),
                );
            }
        }

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

        files.extend(Self::collect_profile_data_artifacts(source, &root, &profile));

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
                base_version_id,
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
        _version_info: &Value,
        game_version: &str,
        base_version_id: &str,
    ) -> Result<usize, DownloadCenterError> {
        let Some(processors) = profile.get("processors").and_then(Value::as_array) else {
            return Ok(0);
        };

        let libraries_dir = root.join("libraries");
        let minecraft_jar = root
            .join("versions")
            .join(base_version_id)
            .join(format!("{base_version_id}.jar"));

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
                        profile,
                        game_version,
                    )?);
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
        profile: &Value,
        game_version: &str,
    ) -> Result<String, DownloadCenterError> {
        if value.starts_with('[') && value.ends_with(']') {
            let descriptor = &value[1..value.len() - 1];

            if let Some(path) = Self::artifact_path(libraries_dir, descriptor) {
                return Ok(path.to_string_lossy().to_string());
            }
        }

        let mut out = value
            .replace("{ROOT}", &root.to_string_lossy())
            .replace("{LIBRARY_DIR}", &libraries_dir.to_string_lossy())
            .replace("{INSTALLER}", &installer_path.to_string_lossy())
            .replace("{MINECRAFT_JAR}", &minecraft_jar.to_string_lossy())
            .replace("{MINECRAFT_VERSION}", game_version)
            .replace("{SIDE}", "client");

        if let Some(data) = profile.get("data").and_then(Value::as_object) {
            for (key, entry) in data {
                let token = format!("{{{key}}}");

                if !out.contains(&token) {
                    continue;
                }

                let Some(raw) = Self::profile_data_client_value(entry) else {
                    continue;
                };

                let resolved = Self::resolve_profile_data_value(
                    raw,
                    root,
                    libraries_dir,
                    installer_path,
                )?;

                out = out.replace(&token, &resolved);
            }
        }

        Ok(out)
    }

    fn profile_data_client_value(value: &Value) -> Option<&str> {
        value
            .get("client")
            .and_then(Value::as_str)
            .or_else(|| value.as_str())
    }

    fn resolve_profile_data_value(
        raw: &str,
        root: &Path,
        libraries_dir: &Path,
        installer_path: &Path,
    ) -> Result<String, DownloadCenterError> {
        if raw.starts_with('[') && raw.ends_with(']') {
            let descriptor = &raw[1..raw.len() - 1];

            if let Some(path) = Self::artifact_path(libraries_dir, descriptor) {
                return Ok(path.to_string_lossy().to_string());
            }
        }

        if let Some(name) = raw.strip_prefix('/') {
            let target = root
                .join("versions")
                .join("forge-installer-data")
                .join(name.trim_start_matches('/'));

            if !target.exists() {
                Self::extract_zip_entry(installer_path, name, &target)?;
            }

            return Ok(target.to_string_lossy().to_string());
        }

        Ok(raw.to_string())
    }

    fn collect_profile_data_artifacts(
        source: DownloadSourceKind,
        root: &Path,
        profile: &Value,
    ) -> Vec<crate::download::DownloadFile> {
        let mut files = Vec::new();
        let Some(data) = profile.get("data").and_then(Value::as_object) else {
            return files;
        };

        for value in data.values() {
            let Some(raw) = Self::profile_data_client_value(value) else {
                continue;
            };

            if raw.starts_with('[') && raw.ends_with(']') {
                let descriptor = &raw[1..raw.len() - 1];

                if let Some(file) = LibraryResolver::library_from_name_to_file(
                    source,
                    root,
                    "https://maven.minecraftforge.net/",
                    descriptor,
                ) {
                    files.push(file);
                }
            }
        }

        files
    }

    fn extract_zip_entry(
        installer_path: &Path,
        name: &str,
        target: &Path,
    ) -> Result<(), DownloadCenterError> {
        let file = fs::File::open(installer_path)?;
        let mut zip = ZipArchive::new(file)?;
        let mut entry = zip.by_name(name)?;

        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent)?;
        }

        let mut output = fs::File::create(target)?;
        std::io::copy(&mut entry, &mut output)?;

        Ok(())
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
