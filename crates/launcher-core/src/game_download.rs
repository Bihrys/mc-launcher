use crate::download::{DownloadError, DownloadManager};
use crate::download_center::DownloadService;

pub use crate::download_center::InstallResult;

pub fn fetch_download_catalog_json(source: &str) -> Result<String, DownloadError> {
    DownloadService::fetch_catalog_json(source)
}

pub fn install_game_version(
    source: &str,
    game_version: &str,
    loader_kind: &str,
    loader_version: &str,
) -> Result<InstallResult, DownloadError> {
    let manager = DownloadManager::silent(format!("安装 Minecraft {game_version}"))?;

    install_game_version_with_manager(&manager, source, game_version, loader_kind, loader_version)
}

pub fn install_game_version_with_manager(
    manager: &DownloadManager,
    source: &str,
    game_version: &str,
    loader_kind: &str,
    loader_version: &str,
) -> Result<InstallResult, DownloadError> {
    DownloadService::install_game_version_with_manager(
        manager,
        source,
        game_version,
        loader_kind,
        loader_version,
    )
}
