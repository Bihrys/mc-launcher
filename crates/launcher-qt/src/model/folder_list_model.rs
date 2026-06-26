use serde::{Deserialize, Serialize};

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct FolderListModelItem {
    pub id: String,
    pub title: String,
    pub subtitle: String,
}

#[derive(Debug, Default, Clone)]
pub struct FolderListModel(pub Vec<FolderListModelItem>);
