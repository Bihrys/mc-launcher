use super::model::DownloadCenterError;
use std::fs;
use std::path::{Path, PathBuf};

pub struct DownloadRepository;

impl DownloadRepository {
    pub fn minecraft_root() -> Result<PathBuf, DownloadCenterError> {
        Ok(Self::data_root()?.join("minecraft"))
    }

    pub fn cache_root() -> Result<PathBuf, DownloadCenterError> {
        if let Some(value) = std::env::var_os("MC_LAUNCHER_COMMON_DIRECTORY") {
            if !value.is_empty() {
                return Ok(PathBuf::from(value));
            }
        }

        if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
            if !value.is_empty() {
                return Ok(PathBuf::from(value).join("mc-launcher"));
            }
        }

        Ok(Self::home_dir()?.join(".cache").join("mc-launcher"))
    }

    pub fn data_root() -> Result<PathBuf, DownloadCenterError> {
        if let Some(value) = std::env::var_os("XDG_DATA_HOME") {
            if !value.is_empty() {
                return Ok(PathBuf::from(value).join("mc-launcher"));
            }
        }

        Ok(Self::home_dir()?.join(".local").join("share").join("mc-launcher"))
    }

    pub fn ensure_parent(path: &Path) -> Result<(), DownloadCenterError> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }

        Ok(())
    }

    pub fn home_dir() -> Result<PathBuf, DownloadCenterError> {
        std::env::var_os("HOME")
            .map(PathBuf::from)
            .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
    }
}

pub(crate) fn simple_error(message: impl Into<String>) -> DownloadCenterError {
    Box::new(std::io::Error::other(message.into()))
}
