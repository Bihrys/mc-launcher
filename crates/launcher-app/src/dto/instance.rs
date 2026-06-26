use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct InstanceListItem {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub tag: String,
    pub icon_name: String,
    pub selected: bool,
    pub can_update: bool,
    pub game_version: String,
    pub loader_summary: String,
    pub path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ProfileListItem {
    pub id: String,
    pub name: String,
    pub path: PathBuf,
    pub selected: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct InstanceListDto {
    pub selected_instance: String,
    pub minecraft_root: PathBuf,
    pub profile_root: PathBuf,
    pub profiles: Vec<ProfileListItem>,
    pub instances: Vec<InstanceListItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct InstanceFolderDto {
    pub folder_key: String,
    pub title: String,
    pub path: PathBuf,
    pub exists: bool,
    pub item_count: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct InstanceLoaderDto {
    pub kind: String,
    pub version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct InstanceDetailDto {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub icon_name: String,
    pub game_version: String,
    pub loader_summary: String,
    pub folders: Vec<InstanceFolderDto>,
    pub loaders: Vec<InstanceLoaderDto>,
    pub has_client_jar: bool,
    pub has_version_json: bool,
    pub main_class: String,
    pub inherits_from: String,
}
