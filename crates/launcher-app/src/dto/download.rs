use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DownloadVersionItem {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub item_type: String,
}
