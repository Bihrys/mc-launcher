use super::model::{DownloadCenterError, DownloadSourceKind, LoaderKind};
use crate::download::DownloadManager;
use crate::game_download::InstallResult;

pub struct GameInstallerService;

impl GameInstallerService {
    pub fn install(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        game_version: &str,
        loader_kind: LoaderKind,
        loader_version: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        crate::game_download::install_game_version_with_manager(
            manager,
            source.as_raw(),
            game_version,
            loader_kind.as_raw(),
            loader_version,
        )
    }
}
