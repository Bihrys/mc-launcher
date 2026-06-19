use crate::task::{TaskError, TaskSnapshot, TaskStatus};
use std::fs;
use std::io;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

#[derive(Clone)]
pub struct TaskExecutor {
    snapshot: Arc<Mutex<TaskSnapshot>>,
    status_path: PathBuf,
    cancel_flag: Arc<AtomicBool>,
    downloaded_bytes: Arc<AtomicU64>,
    speed_window_bytes: Arc<AtomicU64>,
    last_flush_at: Arc<Mutex<Instant>>,
    last_speed_at: Arc<Mutex<Instant>>,
}

impl TaskExecutor {
    pub fn new(
        title: impl Into<String>,
        status_path: impl Into<PathBuf>,
        cancel_flag: Arc<AtomicBool>,
    ) -> Result<Self, TaskError> {
        let executor = Self {
            snapshot: Arc::new(Mutex::new(TaskSnapshot::new(
                uuid::Uuid::new_v4().to_string(),
                title,
            ))),
            status_path: status_path.into(),
            cancel_flag,
            downloaded_bytes: Arc::new(AtomicU64::new(0)),
            speed_window_bytes: Arc::new(AtomicU64::new(0)),
            last_flush_at: Arc::new(Mutex::new(Instant::now())),
            last_speed_at: Arc::new(Mutex::new(Instant::now())),
        };

        executor.flush_now()?;

        Ok(executor)
    }

    pub fn cancel_flag(&self) -> Arc<AtomicBool> {
        self.cancel_flag.clone()
    }

    pub fn downloaded_bytes(&self) -> u64 {
        self.downloaded_bytes.load(Ordering::Relaxed)
    }

    pub fn add_plan(
        &self,
        files: usize,
        bytes: u64,
        message: impl Into<String>,
    ) -> Result<(), TaskError> {
        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.total_files += files;
            snapshot.total_bytes = snapshot.total_bytes.saturating_add(bytes);
            snapshot.message = message.into();
            snapshot.recompute_percent();
        }

        self.flush_now()
    }

    pub fn add_total_bytes(&self, bytes: u64) -> Result<(), TaskError> {
        if bytes == 0 {
            return Ok(());
        }

        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.total_bytes = snapshot.total_bytes.saturating_add(bytes);
            snapshot.recompute_percent();
        }

        self.flush_throttled()
    }

    pub fn set_message(&self, message: impl Into<String>) -> Result<(), TaskError> {
        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.message = message.into();
        }

        self.flush_now()
    }

    pub fn set_current_file(&self, current_file: impl Into<String>) -> Result<(), TaskError> {
        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.current_file = current_file.into();
            snapshot.downloaded_bytes = self.downloaded_bytes();
            snapshot.recompute_percent();
        }

        self.flush_throttled()
    }

    pub fn add_bytes(&self, bytes: u64) -> Result<(), TaskError> {
        self.downloaded_bytes.fetch_add(bytes, Ordering::Relaxed);
        self.speed_window_bytes.fetch_add(bytes, Ordering::Relaxed);

        self.flush_throttled()
    }

    pub fn finish_file(
        &self,
        message: impl Into<String>,
        skipped_size: u64,
    ) -> Result<(), TaskError> {
        if skipped_size > 0 {
            self.downloaded_bytes
                .fetch_add(skipped_size, Ordering::Relaxed);
            self.speed_window_bytes
                .fetch_add(skipped_size, Ordering::Relaxed);
        }

        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.finished_files += 1;
            snapshot.downloaded_bytes = self.downloaded_bytes();
            snapshot.message = message.into();
            snapshot.recompute_percent();
        }

        self.flush_now()
    }

    pub fn fail_file(
        &self,
        file: impl Into<String>,
        error: impl Into<String>,
    ) -> Result<(), TaskError> {
        {
            let mut snapshot = self.lock_snapshot()?;
            let file = file.into();
            snapshot.failed_files.push(file.clone());
            snapshot.message = format!("文件下载失败：{}\n{}", file, error.into());
            snapshot.status = TaskStatus::Failed.as_str().to_string();
            snapshot.downloaded_bytes = self.downloaded_bytes();
            snapshot.recompute_percent();
        }

        self.flush_now()
    }

    pub fn mark_cancelling(&self) -> Result<(), TaskError> {
        self.cancel_flag.store(true, Ordering::Relaxed);

        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.active = true;
            snapshot.cancelled = true;
            snapshot.status = TaskStatus::Cancelling.as_str().to_string();
            snapshot.title = "正在取消下载".to_string();
            snapshot.message = "正在停止下载线程并清理本次任务写入的文件。".to_string();
            snapshot.speed = 0;
            snapshot.downloaded_bytes = self.downloaded_bytes();
            snapshot.recompute_percent();
        }

        self.flush_now()
    }

    pub fn check_cancelled(&self) -> Result<(), TaskError> {
        if self.cancel_flag.load(Ordering::Relaxed) {
            self.mark_cancelling()?;
            return Err(simple_error("下载已取消。"));
        }

        Ok(())
    }

    pub fn finish(&self, message: impl Into<String>) -> Result<(), TaskError> {
        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.active = false;
            snapshot.cancelled = false;
            snapshot.status = TaskStatus::Finished.as_str().to_string();
            snapshot.percent = 100;
            snapshot.current_file.clear();
            snapshot.speed = 0;
            snapshot.message = message.into();
            snapshot.downloaded_bytes = self.downloaded_bytes();
            snapshot.recompute_percent();
        }

        self.write_current_task()
    }

    pub fn fail(&self, message: impl Into<String>) -> Result<(), TaskError> {
        if self.cancel_flag.load(Ordering::Relaxed) {
            return self.cancelled("下载已取消，本次任务写入的临时文件和已完成文件已清理。");
        }

        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.active = false;
            snapshot.status = TaskStatus::Failed.as_str().to_string();
            snapshot.current_file.clear();
            snapshot.speed = 0;
            snapshot.message = message.into();
            snapshot.downloaded_bytes = self.downloaded_bytes();
            snapshot.recompute_percent();
        }

        self.write_current_task()
    }

    pub fn cancelled(&self, message: impl Into<String>) -> Result<(), TaskError> {
        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.active = false;
            snapshot.cancelled = true;
            snapshot.status = TaskStatus::Cancelled.as_str().to_string();
            snapshot.title = "下载已取消".to_string();
            snapshot.current_file.clear();
            snapshot.speed = 0;
            snapshot.message = message.into();
            snapshot.downloaded_bytes = self.downloaded_bytes();
            snapshot.recompute_percent();
        }

        self.write_current_task()
    }

    pub fn flush_throttled(&self) -> Result<(), TaskError> {
        let now = Instant::now();

        let should_flush = {
            let mut last_flush_at = self
                .last_flush_at
                .lock()
                .map_err(|_| simple_error("下载状态刷新锁已损坏。"))?;

            if now.duration_since(*last_flush_at) >= Duration::from_millis(250) {
                *last_flush_at = now;
                true
            } else {
                false
            }
        };

        if should_flush {
            self.sync_progress_and_write(now)?;
        }

        Ok(())
    }

    pub fn flush_now(&self) -> Result<(), TaskError> {
        let now = Instant::now();

        {
            let mut last_flush_at = self
                .last_flush_at
                .lock()
                .map_err(|_| simple_error("下载状态刷新锁已损坏。"))?;

            *last_flush_at = now;
        }

        self.sync_progress_and_write(now)
    }

    fn sync_progress_and_write(&self, now: Instant) -> Result<(), TaskError> {
        let maybe_speed = {
            let mut last_speed_at = self
                .last_speed_at
                .lock()
                .map_err(|_| simple_error("下载速度统计锁已损坏。"))?;

            let elapsed = now.duration_since(*last_speed_at);

            if elapsed >= Duration::from_secs(1) {
                *last_speed_at = now;

                let bytes = self.speed_window_bytes.swap(0, Ordering::Relaxed);
                Some(bytes / elapsed.as_secs().max(1))
            } else {
                None
            }
        };

        {
            let mut snapshot = self.lock_snapshot()?;
            snapshot.downloaded_bytes = self.downloaded_bytes();

            if let Some(speed) = maybe_speed {
                snapshot.speed = speed;
            }

            snapshot.recompute_percent();
        }

        self.write_current_task()
    }

    fn write_current_task(&self) -> Result<(), TaskError> {
        let snapshot = self.lock_snapshot()?.clone();

        if let Some(parent) = self.status_path.parent() {
            fs::create_dir_all(parent)?;
        }

        fs::write(&self.status_path, serde_json::to_string(&snapshot)?)?;

        Ok(())
    }

    fn lock_snapshot(&self) -> Result<std::sync::MutexGuard<'_, TaskSnapshot>, TaskError> {
        self.snapshot
            .lock()
            .map_err(|_| simple_error("下载任务锁已损坏。"))
    }
}

fn simple_error(message: impl Into<String>) -> TaskError {
    Box::new(io::Error::other(message.into()))
}
