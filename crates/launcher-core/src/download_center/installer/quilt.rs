use super::super::model::{DownloadCenterError, DownloadSourceKind, InstallResult};
use super::super::processor::libraries::LibraryResolver;
use super::super::repository::DownloadRepository;
use super::super::resolver::{DownloadResolver, simple_error};
use super::minecraft::MinecraftInstaller;
use crate::download::DownloadManager;
use serde_json::Value;
use std::fs;

pub struct QuiltInstaller;

impl QuiltInstaller {
    pub fn install(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        game_version: &str,
        loader_version: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        if loader_version.is_empty() {
            return Err(simple_error("没有选择 Quilt loader 版本。"));
        }

        let mut base = MinecraftInstaller::install(manager, source, game_version)?;
        let client = DownloadResolver::http_client()?;
        let profile_urls = DownloadResolver::inject_url_candidates(
            source,
            &format!(
                "https://meta.quiltmc.org/v3/versions/loader/{game_version}/{loader_version}/profile/json"
            ),
        );

        manager.set_message("正在获取 Quilt profile...")?;
        let profile_json: Value =
            DownloadResolver::get_json_from_candidates(&client, &profile_urls)?;

        let version_id = profile_json
            .get("id")
            .and_then(Value::as_str)
            .map(ToString::to_string)
            .unwrap_or_else(|| format!("quilt-loader-{loader_version}-{game_version}"));

        let root = DownloadRepository::minecraft_root()?;
        let version_dir = root.join("versions").join(&version_id);
        fs::create_dir_all(&version_dir)?;

        let version_json_path = version_dir.join(format!("{version_id}.json"));
        fs::write(
            &version_json_path,
            serde_json::to_string_pretty(&profile_json)?,
        )?;
        manager.track_created_file(version_json_path.clone())?;

        manager.set_message("正在下载 Quilt libraries...")?;
        let libraries =
            LibraryResolver::collect_libraries_from_version_json(source, &root, &profile_json)?;
        let library_count = manager.download_files(libraries)?;

        base.kind = "loader".to_string();
        base.loader_kind = "quilt".to_string();
        base.loader_version = loader_version.to_string();
        base.version_id = version_id;
        base.downloaded_files += library_count + 1;
        base.message = format!("Quilt 已安装。已先安装原版 {game_version}，并写入 Quilt profile。");

        Ok(base)
    }
}
