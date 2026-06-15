use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadTask {
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

impl DownloadTask {
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
            status: "running".to_string(),
        }
    }

    pub fn recompute_percent(&mut self) {
        if self.total_bytes > 0 {
            self.percent = ((self.downloaded_bytes.saturating_mul(100)) / self.total_bytes)
                .min(100) as u32;
        } else if self.total_files > 0 {
            self.percent = ((self.finished_files.saturating_mul(100)) / self.total_files)
                .min(100) as u32;
        } else {
            self.percent = 0;
        }
    }
}
