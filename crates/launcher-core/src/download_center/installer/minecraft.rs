use super::super::model::{DownloadCenterError, DownloadSourceKind, InstallResult, MojangManifest};
use super::super::processor::libraries::LibraryResolver;
use super::super::repository::DownloadRepository;
use super::super::resolver::{DownloadResolver, simple_error};
use crate::download::DownloadManager;
use serde_json::Value;
use std::fs;

pub struct MinecraftInstaller;

impl MinecraftInstaller {
    pub fn install(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        game_version: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        manager.set_message("正在获取版本 manifest...")?;

        let client = DownloadResolver::http_client()?;
        let manifest: MojangManifest =
            DownloadResolver::get_json(&client, &DownloadResolver::manifest_url(source))?;

        let version = manifest
            .versions
            .into_iter()
            .find(|version| version.id == game_version)
            .ok_or_else(|| simple_error(format!("没有找到 Minecraft 版本：{game_version}")))?;

        let version_json_url = DownloadResolver::inject_url(source, &version.url);

        manager.set_message(format!("正在获取 version json：{game_version}"))?;

        let version_json: Value = DownloadResolver::get_json(&client, &version_json_url)?;

        Self::install_version_json(
            manager,
            source,
            &client,
            game_version,
            &version_json,
            "vanilla",
            "",
            game_version,
        )
    }

    pub fn install_version_json(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        client: &reqwest::blocking::Client,
        game_version: &str,
        version_json: &Value,
        loader_kind: &str,
        loader_version: &str,
        version_id: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        let root = DownloadRepository::minecraft_root()?;
        let version_dir = root.join("versions").join(version_id);
        fs::create_dir_all(&version_dir)?;

        let version_json_path = version_dir.join(format!("{version_id}.json"));
        fs::write(
            &version_json_path,
            serde_json::to_string_pretty(version_json)?,
        )?;
        manager.track_created_file(version_json_path.clone())?;

        let mut files = Vec::new();

        if let Some(client_download) = version_json
            .get("downloads")
            .and_then(|value| value.get("client"))
        {
            if let Some(url) = client_download.get("url").and_then(Value::as_str) {
                let jar_path = version_dir.join(format!("{version_id}.jar"));

                files.push(LibraryResolver::download_file_from_artifact(
                    source,
                    url,
                    &jar_path,
                    client_download,
                ));
            }
        }

        manager.set_message("正在收集 libraries...")?;
        files.extend(LibraryResolver::collect_libraries_from_version_json(
            source,
            &root,
            version_json,
        )?);

        manager.set_message("正在收集 assets...")?;
        files.extend(LibraryResolver::collect_assets_from_version_json(
            manager,
            source,
            client,
            &root,
            version_json,
        )?);

        manager.set_message(format!("开始下载 Minecraft {game_version} 文件..."))?;

        let downloaded_files = manager.download_files(files)? + 1;

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
}
