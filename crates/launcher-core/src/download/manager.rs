use crate::download::file::DownloadFile;
use crate::download::progress::write_task;
use crate::download::task::DownloadTask;
use crate::download::verify::is_valid_file;
use crate::download::DownloadError;
use reqwest::blocking::Client;
use std::collections::VecDeque;
use std::fs::{self, File};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

#[derive(Clone)]
pub struct DownloadManager {
    client: Client,
    task: Arc<Mutex<DownloadTask>>,
    status_path: PathBuf,
    cancel_flag: Arc<AtomicBool>,
    started_at: Arc<Instant>,
    workers: usize,
}

impl DownloadManager {
    pub fn new(
        title: impl Into<String>,
        status_path: impl Into<PathBuf>,
        cancel_flag: Arc<AtomicBool>,
    ) -> Result<Self, DownloadError> {
        let manager = Self {
            client: Client::builder()
                .user_agent("mc-launcher/0.1 download-manager")
                .connect_timeout(Duration::from_secs(10))
                .timeout(Duration::from_secs(60))
                .build()?,
            task: Arc::new(Mutex::new(DownloadTask::new(
                uuid::Uuid::new_v4().to_string(),
                title,
            ))),
            status_path: status_path.into(),
            cancel_flag,
            started_at: Arc::new(Instant::now()),
            workers: 8,
        };

        manager.flush()?;

        Ok(manager)
    }

    pub fn silent(title: impl Into<String>) -> Result<Self, DownloadError> {
        Self::new(
            title,
            std::env::temp_dir().join("mc-launcher-download-task.json"),
            Arc::new(AtomicBool::new(false)),
        )
    }

    pub fn set_message(&self, message: impl Into<String>) -> Result<(), DownloadError> {
        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.message = message.into();
        }

        self.flush()
    }

    pub fn finish(&self, message: impl Into<String>) -> Result<(), DownloadError> {
        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.active = false;
            task.status = "finished".to_string();
            task.percent = 100;
            task.current_file.clear();
            task.message = message.into();
            task.speed = 0;
        }

        self.flush()
    }

    pub fn fail(&self, message: impl Into<String>) -> Result<(), DownloadError> {
        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.active = false;
            task.status = if task.cancelled {
                "cancelled"
            } else {
                "failed"
            }
            .to_string();
            task.current_file.clear();
            task.message = message.into();
            task.speed = 0;
        }

        self.flush()
    }

    pub fn check_cancelled(&self) -> Result<(), DownloadError> {
        if self.cancel_flag.load(Ordering::Relaxed) {
            {
                let mut task = self
                    .task
                    .lock()
                    .map_err(|_| simple_error("下载任务锁已损坏。"))?;

                task.active = false;
                task.cancelled = true;
                task.status = "cancelled".to_string();
                task.message = "下载已取消。".to_string();
            }

            self.flush()?;

            return Err(simple_error("下载已取消。"));
        }

        Ok(())
    }

    pub fn download_files(&self, files: Vec<DownloadFile>) -> Result<usize, DownloadError> {
        if files.is_empty() {
            return Ok(0);
        }

        self.check_cancelled()?;

        let total_bytes = files.iter().filter_map(|file| file.size).sum::<u64>();

        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.total_files += files.len();
            task.total_bytes = task.total_bytes.saturating_add(total_bytes);
            task.message = format!("准备下载 {} 个文件。", files.len());
            task.recompute_percent();
        }

        self.flush()?;

        let queue = Arc::new(Mutex::new(VecDeque::from(files)));
        let downloaded_count = Arc::new(Mutex::new(0_usize));
        let worker_count = self
            .workers
            .min(queue.lock().map(|queue| queue.len()).unwrap_or(1))
            .max(1);

        let mut handles = Vec::new();

        for _ in 0..worker_count {
            let manager = self.clone();
            let queue = queue.clone();
            let downloaded_count = downloaded_count.clone();

            handles.push(thread::spawn(move || -> Result<(), DownloadError> {
                loop {
                    manager.check_cancelled()?;

                    let file = {
                        let mut queue = queue
                            .lock()
                            .map_err(|_| simple_error("下载队列锁已损坏。"))?;

                        queue.pop_front()
                    };

                    let Some(file) = file else {
                        break;
                    };

                    match manager.download_one_with_retry(&file) {
                        Ok(downloaded) => {
                            if downloaded {
                                let mut count = downloaded_count
                                    .lock()
                                    .map_err(|_| simple_error("下载计数锁已损坏。"))?;

                                *count += 1;
                            }
                        }
                        Err(err) => {
                            manager.mark_failed(&file, &err.to_string())?;
                            return Err(err);
                        }
                    }
                }

                Ok(())
            }));
        }

        for handle in handles {
            match handle.join() {
                Ok(result) => result?,
                Err(_) => return Err(simple_error("下载线程异常退出。")),
            }
        }

        let count = *downloaded_count
            .lock()
            .map_err(|_| simple_error("下载计数锁已损坏。"))?;

        Ok(count)
    }

    fn download_one_with_retry(&self, file: &DownloadFile) -> Result<bool, DownloadError> {
        for attempt in 1..=3 {
            self.check_cancelled()?;

            match self.download_one(file) {
                Ok(value) => return Ok(value),
                Err(err) if attempt < 3 => {
                    self.set_message(format!(
                        "下载失败，准备重试 {attempt}/3：{}\n{}",
                        file.display_name(),
                        err
                    ))?;

                    thread::sleep(Duration::from_millis(600));
                }
                Err(err) => return Err(err),
            }
        }

        Ok(false)
    }

    fn download_one(&self, file: &DownloadFile) -> Result<bool, DownloadError> {
        self.check_cancelled()?;

        if is_valid_file(&file.path, file.size, file.sha1.as_deref())? {
            self.mark_done(file, false)?;
            return Ok(false);
        }

        self.set_current_file(file)?;
        ensure_parent(&file.path)?;

        let part_path = file.path.with_extension(format!(
            "{}.part",
            file.path
                .extension()
                .and_then(|value| value.to_str())
                .unwrap_or("download")
        ));

        let mut response = self.client.get(&file.url).send()?.error_for_status()?;
        let mut output = File::create(&part_path)?;
        let mut buffer = [0_u8; 64 * 1024];

        loop {
            self.check_cancelled()?;

            let read = response.read(&mut buffer)?;

            if read == 0 {
                break;
            }

            output.write_all(&buffer[..read])?;
            self.add_bytes(read as u64)?;
        }

        output.flush()?;
        drop(output);

        fs::rename(&part_path, &file.path)?;

        if !is_valid_file(&file.path, file.size, file.sha1.as_deref())? {
            return Err(simple_error(format!("文件校验失败：{}", file.display_name())));
        }

        self.mark_done(file, true)?;

        Ok(true)
    }

    fn set_current_file(&self, file: &DownloadFile) -> Result<(), DownloadError> {
        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.current_file = file.display_name();
            task.message = format!(
                "正在下载：{}\n已完成 {}/{} 个文件",
                task.current_file,
                task.finished_files,
                task.total_files
            );
            task.recompute_percent();
        }

        self.flush()
    }

    fn add_bytes(&self, bytes: u64) -> Result<(), DownloadError> {
        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.downloaded_bytes = task.downloaded_bytes.saturating_add(bytes);

            let elapsed = self.started_at.elapsed().as_secs().max(1);
            task.speed = task.downloaded_bytes / elapsed;
            task.recompute_percent();
        }

        self.flush()
    }

    fn mark_done(&self, file: &DownloadFile, downloaded: bool) -> Result<(), DownloadError> {
        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.finished_files += 1;

            if !downloaded {
                task.downloaded_bytes = task
                    .downloaded_bytes
                    .saturating_add(file.size.unwrap_or(0));
            }

            task.message = format!(
                "已完成 {}/{} 个文件\n当前：{}",
                task.finished_files,
                task.total_files,
                file.display_name()
            );
            task.recompute_percent();
        }

        self.flush()
    }

    fn mark_failed(&self, file: &DownloadFile, error: &str) -> Result<(), DownloadError> {
        {
            let mut task = self
                .task
                .lock()
                .map_err(|_| simple_error("下载任务锁已损坏。"))?;

            task.failed_files.push(file.display_name());
            task.message = format!("文件下载失败：{}\n{}", file.display_name(), error);
            task.status = "failed".to_string();
        }

        self.flush()
    }

    fn flush(&self) -> Result<(), DownloadError> {
        let task = self
            .task
            .lock()
            .map_err(|_| simple_error("下载任务锁已损坏。"))?
            .clone();

        write_task(&self.status_path, &task)
    }
}

fn ensure_parent(path: &Path) -> Result<(), DownloadError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    Ok(())
}

fn simple_error(message: impl Into<String>) -> DownloadError {
    Box::new(io::Error::other(message.into()))
}
