use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct InstanceListItem {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub tag: String,
    #[serde(rename = "iconName")]
    pub icon_name: String,
    pub selected: bool,
    #[serde(rename = "canUpdate")]
    pub can_update: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct InstanceDetailDto {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub icon_name: String,
}
