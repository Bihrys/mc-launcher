use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TaskItem {
    pub id: String,
    pub title: String,
    pub message: String,
    pub percent: f64,
    pub active: bool,
}
