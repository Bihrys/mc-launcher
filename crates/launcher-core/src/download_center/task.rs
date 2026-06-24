use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DownloadCenterTaskKind {
    RefreshCatalog,
    InstallGame,
    InstallLoader,
    DownloadContent,
}

impl DownloadCenterTaskKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::RefreshCatalog => "download.refreshCatalog",
            Self::InstallGame => "download.installGame",
            Self::InstallLoader => "download.installLoader",
            Self::DownloadContent => "download.content",
        }
    }
}
