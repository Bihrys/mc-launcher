use super::catalog::DownloadCatalogService;
use super::installer::{
    FabricInstaller, ForgeInstaller, MinecraftInstaller, NeoForgeInstaller, QuiltInstaller,
};
use super::model::{DownloadCenterError, DownloadSourceKind, InstallResult, LoaderKind};
use crate::download::DownloadManager;

pub struct DownloadService;

impl DownloadService {
    pub fn fetch_catalog_json(source: &str) -> Result<String, DownloadCenterError> {
        DownloadCatalogService::fetch_json(DownloadSourceKind::from_raw(source))
    }

    pub fn fetch_installer_metadata_json(
        source: &str,
        game_version: &str,
    ) -> Result<String, DownloadCenterError> {
        DownloadCatalogService::fetch_installer_metadata_json(
            DownloadSourceKind::from_raw(source),
            game_version,
        )
    }

    pub fn fetch_loader_versions_json(
        source: &str,
        game_version: &str,
        loader_kind: &str,
    ) -> Result<String, DownloadCenterError> {
        DownloadCatalogService::fetch_loader_versions_json(
            DownloadSourceKind::from_raw(source),
            game_version,
            loader_kind,
        )
    }

    pub fn install_game_version_with_manager(
        manager: &DownloadManager,
        source: &str,
        game_version: &str,
        loader_kind: &str,
        loader_version: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        let source = DownloadSourceKind::from_raw(source);
        let game_version = game_version.trim();
        let loader_version = loader_version.trim();

        if game_version.is_empty() {
            return Err(Box::new(std::io::Error::other("没有选择 Minecraft 版本。")));
        }

        match LoaderKind::from_raw(loader_kind) {
            LoaderKind::Vanilla => MinecraftInstaller::install(manager, source, game_version),
            LoaderKind::Fabric => {
                FabricInstaller::install(manager, source, game_version, loader_version)
            }
            LoaderKind::Quilt => {
                QuiltInstaller::install(manager, source, game_version, loader_version)
            }
            LoaderKind::Forge => {
                ForgeInstaller::install(manager, source, game_version, loader_version)
            }
            LoaderKind::NeoForge => {
                NeoForgeInstaller::install(manager, source, game_version, loader_version)
            }
        }
    }
}
