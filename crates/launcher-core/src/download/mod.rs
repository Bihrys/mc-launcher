pub mod file;
pub mod manager;
pub mod progress;
pub mod task;
pub mod verify;

pub use file::DownloadFile;
pub use manager::DownloadManager;
pub use task::DownloadTask;

pub type DownloadError = Box<dyn std::error::Error + Send + Sync + 'static>;
