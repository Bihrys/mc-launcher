use serde::{Deserialize, Serialize};

pub type DownloadCenterError = crate::download::DownloadError;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DownloadSourceKind {
    Official,
    Bmcl,
    Balanced,
    Mirror,
}

impl DownloadSourceKind {
    pub fn from_raw(value: &str) -> Self {
        match value {
            "official" => Self::Official,
            "balanced" => Self::Balanced,
            "mirror" => Self::Mirror,
            _ => Self::Bmcl,
        }
    }

    pub fn as_raw(self) -> &'static str {
        match self {
            Self::Official => "official",
            Self::Bmcl => "bmcl",
            Self::Balanced => "balanced",
            Self::Mirror => "mirror",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LoaderKind {
    Vanilla,
    Fabric,
    Quilt,
    Forge,
    NeoForge,
}

impl LoaderKind {
    pub fn from_raw(value: &str) -> Self {
        match value {
            "fabric" => Self::Fabric,
            "quilt" => Self::Quilt,
            "forge" => Self::Forge,
            "neoforge" => Self::NeoForge,
            _ => Self::Vanilla,
        }
    }

    pub fn as_raw(self) -> &'static str {
        match self {
            Self::Vanilla => "vanilla",
            Self::Fabric => "fabric",
            Self::Quilt => "quilt",
            Self::Forge => "forge",
            Self::NeoForge => "neoforge",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DownloadTab {
    Game,
    Modpack,
    Mod,
    ResourcePack,
    Shader,
    World,
}
