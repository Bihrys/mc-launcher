use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadFile {
    pub url: String,
    pub path: PathBuf,
    pub name: String,
    pub size: Option<u64>,
    pub sha1: Option<String>,
}

impl DownloadFile {
    pub fn new(url: impl Into<String>, path: impl Into<PathBuf>) -> Self {
        let path = path.into();
        let name = path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("download.bin")
            .to_string();

        Self {
            url: url.into(),
            path,
            name,
            size: None,
            sha1: None,
        }
    }

    pub fn with_metadata(
        url: impl Into<String>,
        path: impl Into<PathBuf>,
        size: Option<u64>,
        sha1: Option<String>,
    ) -> Self {
        let mut file = Self::new(url, path);
        file.size = size;
        file.sha1 = sha1;
        file
    }

    pub fn display_name(&self) -> String {
        let raw = self.path.to_string_lossy().to_string();

        if let Ok(home) = std::env::var("HOME") {
            if !home.is_empty() {
                return raw.replace(&home, "~");
            }
        }

        raw
    }
}
