use crate::download::{DownloadError, DownloadTask};
use std::fs;
use std::path::Path;

pub fn write_task(path: &Path, task: &DownloadTask) -> Result<(), DownloadError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string(task)?)?;
    Ok(())
}
