use super::super::catalog::DownloadCatalogService;
use super::super::model::{DownloadCenterError, DownloadSourceKind, InstallResult};
use super::super::processor::ForgeProcessor;
use super::super::repository::DownloadRepository;
use super::super::resolver::{simple_error, DownloadResolver};
use crate::download::{DownloadFile, DownloadManager};
use std::fs;

pub struct NeoForgeInstaller;

impl NeoForgeInstaller {
    pub fn install(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        game_version: &str,
        loader_version: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        if loader_version.is_empty() {
            return Err(simple_error("没有选择 NeoForge 版本。"));
        }

        manager.set_message("正在查找 NeoForge installer...")?;

        let catalog = DownloadCatalogService::fetch(source)?;
        let installer = catalog
            .neoforge_installers
            .into_iter()
            .find(|item| item.game_version == game_version && item.loader_version == loader_version)
            .ok_or_else(|| simple_error(format!(
                "没有找到 NeoForge installer：Minecraft {game_version}, NeoForge {loader_version}"
            )))?;

        let cache_dir = DownloadRepository::cache_root()?.join("installers").join("neoforge");
        fs::create_dir_all(&cache_dir)?;

        let file_name = DownloadResolver::file_name_from_url(&installer.url);
        let target = cache_dir.join(file_name);

        manager.download_files(vec![DownloadFile::new(installer.url, target.clone())])?;

        ForgeProcessor::install_installer(
            manager,
            source,
            "neoforge",
            game_version,
            loader_version,
            &target,
        )
    }
}
