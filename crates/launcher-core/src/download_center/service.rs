use super::catalog::DownloadCatalogService;
use super::installer::GameInstallerService;
use super::model::{DownloadCenterError, DownloadSourceKind, LoaderKind};
use crate::download::DownloadManager;
use crate::game_download::InstallResult;

pub struct DownloadService;

impl DownloadService {
    pub fn fetch_catalog_json(source: &str) -> Result<String, DownloadCenterError> {
        DownloadCatalogService::fetch_json(DownloadSourceKind::from_raw(source))
    }

    pub fn install_game_version_with_manager(
        manager: &DownloadManager,
        source: &str,
        game_version: &str,
        loader_kind: &str,
        loader_version: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        GameInstallerService::install(
            manager,
            DownloadSourceKind::from_raw(source),
            game_version,
            LoaderKind::from_raw(loader_kind),
            loader_version,
        )
    }
}
