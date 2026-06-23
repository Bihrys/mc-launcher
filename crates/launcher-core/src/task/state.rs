use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum TaskStatus {
    Idle,
    Running,
    Cancelling,
    Cancelled,
    Finished,
    Failed,
}

impl TaskStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            TaskStatus::Idle => "idle",
            TaskStatus::Running => "running",
            TaskStatus::Cancelling => "cancelling",
            TaskStatus::Cancelled => "cancelled",
            TaskStatus::Finished => "finished",
            TaskStatus::Failed => "failed",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TaskSnapshot {
    pub id: String,
    pub title: String,
    pub active: bool,
    pub cancelled: bool,
    pub percent: u32,
    pub total_files: usize,
    pub finished_files: usize,
    pub failed_files: Vec<String>,
    pub total_bytes: u64,
    pub downloaded_bytes: u64,
    pub current_file: String,
    pub speed: u64,
    pub message: String,
    pub status: String,
}

impl TaskSnapshot {
    pub fn new(id: impl Into<String>, title: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            title: title.into(),
            active: true,
            cancelled: false,
            percent: 0,
            total_files: 0,
            finished_files: 0,
            failed_files: Vec::new(),
            total_bytes: 0,
            downloaded_bytes: 0,
            current_file: String::new(),
            speed: 0,
            message: "准备下载...".to_string(),
            status: TaskStatus::Running.as_str().to_string(),
        }
    }

    pub fn recompute_percent(&mut self) {
        if self.total_bytes > 0 {
            self.percent =
                ((self.downloaded_bytes.saturating_mul(100)) / self.total_bytes).min(100) as u32;
        } else if self.total_files > 0 {
            self.percent =
                ((self.finished_files.saturating_mul(100)) / self.total_files).min(100) as u32;
        } else {
            self.percent = 0;
        }
    }
}
