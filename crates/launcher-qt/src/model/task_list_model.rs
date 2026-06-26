use serde::{Deserialize, Serialize};

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct TaskListModelItem {
    pub id: String,
    pub title: String,
    pub subtitle: String,
}

#[derive(Debug, Default, Clone)]
pub struct TaskListModel(pub Vec<TaskListModelItem>);
