use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct TaskItem {
    pub id: String,
    pub title: String,
    pub message: String,
    pub percent: f64,
    pub active: bool,
    pub status: String,
    pub cancelled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct TaskCenterDto {
    pub active_count: usize,
    pub tasks: Vec<TaskItem>,
}
