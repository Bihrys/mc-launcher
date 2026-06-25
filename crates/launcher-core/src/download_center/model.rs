use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

pub type DownloadCenterError = crate::download::DownloadError;

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum DownloadSourceKind {
    Official,
    Bmcl,
    Balanced,
    Mirror,
}

impl DownloadSourceKind {
    pub fn from_raw(value: &str) -> Self {
        match value.trim().to_ascii_lowercase().as_str() {
            "official" | "mojang" => Self::Official,
            "bmcl" | "bmclapi" => Self::Bmcl,
            "mirror" => Self::Mirror,
            _ => Self::Balanced,
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
        match value.trim().to_ascii_lowercase().as_str() {
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

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InstallResult {
    pub kind: String,
    pub game_version: String,
    pub loader_kind: String,
    pub loader_version: String,
    pub version_id: String,
    pub install_dir: PathBuf,
    pub downloaded_files: usize,
    pub message: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadCatalog {
    pub source: String,
    pub latest_release: String,
    pub latest_snapshot: String,
    pub game_versions: Vec<GameEntry>,
    pub fabric_loaders: Vec<LoaderEntry>,
    pub quilt_loaders: Vec<LoaderEntry>,
    pub forge_installers: Vec<InstallerEntry>,
    pub neoforge_installers: Vec<InstallerEntry>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GameEntry {
    pub id: String,
    pub version_type: String,
    pub release_time: String,
    pub url: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LoaderEntry {
    pub version: String,
    pub stable: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InstallerEntry {
    pub game_version: String,
    pub loader_version: String,
    pub url: String,
    pub release_time: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MojangManifest {
    pub latest: MojangLatest,
    pub versions: Vec<MojangVersion>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct MojangLatest {
    pub release: String,
    pub snapshot: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MojangVersion {
    pub id: String,
    #[serde(rename = "type")]
    pub version_type: String,
    pub url: String,
    pub release_time: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct MetaLoaderVersion {
    pub version: String,
    pub stable: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ForgeRoot {
    pub artifact: Option<String>,
    pub webpath: Option<String>,
    pub mcversion: Option<HashMap<String, Vec<u32>>>,
    pub number: Option<HashMap<String, ForgeVersion>>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ForgeVersion {
    pub branch: Option<String>,
    pub mcversion: Option<String>,
    pub version: Option<String>,
    pub modified: Option<i64>,
    pub files: Option<Vec<Vec<String>>>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct NeoForgeApiResult {
    pub versions: Vec<String>,
}
