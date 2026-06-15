use crate::download::file::DownloadFile;
use crate::download::verify::is_valid_file;
use crate::download::DownloadError;
use crate::task::TaskExecutor;
use reqwest::blocking::Client;
use reqwest::header::{CONTENT_LENGTH, RANGE};
use reqwest::StatusCode;
use std::collections::VecDeque;
use std::fs::{self, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

#[derive(Clone)]
pub struct DownloadManager {
    client: Client,
    executor: TaskExecutor,
    workers: usize,
    part_files: Arc<Mutex<Vec<PathBuf>>>,
    created_files: Arc<Mutex<Vec<PathBuf>>>,
}

impl DownloadManager {
    pub fn new(
        title: impl Into<String>,
        status_path: impl Into<PathBuf>,
        cancel_flag: Arc<AtomicBool>,
    ) -> Result<Self, DownloadError> {
        let workers = configured_worker_count();

        let manager = Self {
            client: Client::builder()
                .user_agent("mc-launcher/0.1 hmcl-style-fetch")
                .connect_timeout(Duration::from_secs(10))
                .pool_max_idle_per_host(workers)
                .tcp_nodelay(true)
                .build()?,
            executor: TaskExecutor::new(title, status_path, cancel_flag)?,
            workers,
            part_files: Arc::new(Mutex::new(Vec::new())),
            created_files: Arc::new(Mutex::new(Vec::new())),
        };

        Ok(manager)
    }

    pub fn silent(title: impl Into<String>) -> Result<Self, DownloadError> {
        Self::new(
            title,
            std::env::temp_dir().join("mc-launcher-download-task.json"),
            Arc::new(AtomicBool::new(false)),
        )
    }

    pub fn cancel_flag(&self) -> Arc<AtomicBool> {
        self.executor.cancel_flag()
    }

    pub fn track_created_file(&self, path: impl Into<PathBuf>) -> Result<(), DownloadError> {
        let path = path.into();

        let mut files = self
            .created_files
            .lock()
            .map_err(|_| simple_error("已创建文件列表锁已损坏。"))?;

        if !files.iter().any(|item| item == &path) {
            files.push(path);
        }

        Ok(())
    }

    pub fn set_message(&self, message: impl Into<String>) -> Result<(), DownloadError> {
        self.executor.set_message(message)
    }

    pub fn mark_cancelling(&self) -> Result<(), DownloadError> {
        self.executor.mark_cancelling()
    }

    pub fn finish(&self, message: impl Into<String>) -> Result<(), DownloadError> {
        self.executor.finish(message)
    }

    pub fn fail(&self, message: impl Into<String>) -> Result<(), DownloadError> {
        if self.cancel_flag().load(Ordering::Relaxed) {
            self.cleanup_partial_and_downloaded();
            self.executor
                .cancelled("下载已取消，本次任务写入的 .part 和已完成文件已清理。")
        } else {
            self.executor.fail(message)
        }
    }

    pub fn check_cancelled(&self) -> Result<(), DownloadError> {
        self.executor.check_cancelled()
    }

    pub fn download_files(&self, files: Vec<DownloadFile>) -> Result<usize, DownloadError> {
        if files.is_empty() {
            return Ok(0);
        }

        self.check_cancelled()?;

        let total_bytes = files.iter().filter_map(|file| file.size).sum::<u64>();

        self.executor.add_plan(
            files.len(),
            total_bytes,
            format!("准备下载 {} 个文件。并发数：{}", files.len(), self.workers),
        )?;

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

                    match manager.download_file_task(&file) {
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

        let mut first_error: Option<DownloadError> = None;

        for handle in handles {
            match handle.join() {
                Ok(Ok(())) => {}
                Ok(Err(err)) => {
                    if first_error.is_none() {
                        first_error = Some(err);
                    }
                }
                Err(_) => {
                    if first_error.is_none() {
                        first_error = Some(simple_error("下载线程异常退出。"));
                    }
                }
            }
        }

        if self.cancel_flag().load(Ordering::Relaxed) {
            self.cleanup_partial_and_downloaded();
            return Err(simple_error("下载已取消。"));
        }

        if let Some(err) = first_error {
            return Err(err);
        }

        let count = *downloaded_count
            .lock()
            .map_err(|_| simple_error("下载计数锁已损坏。"))?;

        self.executor.flush_now()?;

        Ok(count)
    }

    fn download_file_task(&self, file: &DownloadFile) -> Result<bool, DownloadError> {
        self.check_cancelled()?;

        if is_valid_file(&file.path, file.size, file.sha1.as_deref())? {
            self.executor.finish_file(
                format!("跳过已存在文件：{}", file.display_name()),
                file.size.unwrap_or(0),
            )?;
            return Ok(false);
        }

        self.executor.set_current_file(file.display_name())?;
        ensure_parent(&file.path)?;

        let part_path = part_path_for(&file.path);
        self.track_part_file(part_path.clone())?;

        let mut last_error: Option<DownloadError> = None;

        for attempt in 1..=3 {
            self.check_cancelled()?;

            for url in file.candidates() {
                self.check_cancelled()?;

                match self.download_candidate(file, &url, &part_path) {
                    Ok(()) => {
                        self.untrack_part_file(&part_path);
                        self.track_created_file(file.path.clone())?;

                        if !is_valid_file(&file.path, file.size, file.sha1.as_deref())? {
                            let _ = fs::remove_file(&file.path);
                            last_error = Some(simple_error(format!(
                                "文件校验失败：{}",
                                file.display_name()
                            )));
                            continue;
                        }

                        self.executor.finish_file(
                            format!("已完成：{}", file.display_name()),
                            0,
                        )?;

                        return Ok(true);
                    }
                    Err(err) if self.cancel_flag().load(Ordering::Relaxed) => {
                        let _ = fs::remove_file(&part_path);
                        self.untrack_part_file(&part_path);
                        return Err(err);
                    }
                    Err(err) => {
                        last_error = Some(err);
                    }
                }
            }

            if attempt < 3 {
                self.executor.set_message(format!(
                    "下载失败，准备重试 {attempt}/3：{}",
                    file.display_name()
                ))?;

                thread::sleep(Duration::from_millis(250));
            }
        }

        let _ = fs::remove_file(&part_path);
        self.untrack_part_file(&part_path);

        Err(last_error.unwrap_or_else(|| {
            simple_error(format!("文件下载失败：{}", file.display_name()))
        }))
    }

    fn download_candidate(
        &self,
        file: &DownloadFile,
        url: &str,
        part_path: &Path,
    ) -> Result<(), DownloadError> {
        let mut resume_from = existing_part_len(part_path);

        if let Some(expected_size) = file.size {
            if resume_from >= expected_size {
                let _ = fs::remove_file(part_path);
                resume_from = 0;
            }
        }

        let mut request = self.client.get(url);

        if resume_from > 0 {
            request = request.header(RANGE, format!("bytes={resume_from}-"));
        }

        let mut response = request.send()?;
        let status = response.status();

        if resume_from > 0 && status != StatusCode::PARTIAL_CONTENT {
            let _ = fs::remove_file(part_path);
            resume_from = 0;
            response = self.client.get(url).send()?;
        }

        let response = response.error_for_status()?;

        if file.size.is_none() && resume_from == 0 {
            if let Some(length) = response
                .headers()
                .get(CONTENT_LENGTH)
                .and_then(|value| value.to_str().ok())
                .and_then(|value| value.parse::<u64>().ok())
            {
                self.executor.add_total_bytes(length)?;
            }
        }

        let mut response = response;

        let mut output = OpenOptions::new()
            .create(true)
            .append(resume_from > 0)
            .write(true)
            .truncate(resume_from == 0)
            .open(part_path)?;

        let mut buffer = [0_u8; 128 * 1024];

        loop {
            self.check_cancelled()?;

            let read = match response.read(&mut buffer) {
                Ok(read) => read,
                Err(err) if self.cancel_flag().load(Ordering::Relaxed) => {
                    return Err(simple_error(format!("下载已取消：{err}")));
                }
                Err(err) => return Err(Box::new(err)),
            };

            if read == 0 {
                break;
            }

            self.check_cancelled()?;
            output.write_all(&buffer[..read])?;
            self.executor.add_bytes(read as u64)?;
        }

        self.check_cancelled()?;

        output.flush()?;
        drop(output);

        fs::rename(part_path, &file.path)?;

        Ok(())
    }

    fn mark_failed(&self, file: &DownloadFile, error: &str) -> Result<(), DownloadError> {
        if self.cancel_flag().load(Ordering::Relaxed) {
            return Ok(());
        }

        self.executor.fail_file(file.display_name(), error)
    }

    fn track_part_file(&self, path: PathBuf) -> Result<(), DownloadError> {
        let mut part_files = self
            .part_files
            .lock()
            .map_err(|_| simple_error("临时文件列表锁已损坏。"))?;

        if !part_files.iter().any(|item| item == &path) {
            part_files.push(path);
        }

        Ok(())
    }

    fn untrack_part_file(&self, path: &Path) {
        if let Ok(mut part_files) = self.part_files.lock() {
            part_files.retain(|item| item != path);
        }
    }

    fn cleanup_partial_and_downloaded(&self) {
        let part_files = self
            .part_files
            .lock()
            .map(|value| value.clone())
            .unwrap_or_default();

        let created_files = self
            .created_files
            .lock()
            .map(|value| value.clone())
            .unwrap_or_default();

        for path in part_files.iter().chain(created_files.iter()) {
            let _ = fs::remove_file(path);
        }
    }
}

fn configured_worker_count() -> usize {
    if let Ok(value) = std::env::var("MC_LAUNCHER_DOWNLOAD_WORKERS") {
        if let Ok(workers) = value.trim().parse::<usize>() {
            return workers.clamp(1, 64);
        }
    }

    std::thread::available_parallelism()
        .map(|value| value.get().saturating_mul(4))
        .unwrap_or(16)
        .clamp(8, 64)
}

fn existing_part_len(path: &Path) -> u64 {
    path.metadata().map(|metadata| metadata.len()).unwrap_or(0)
}

fn part_path_for(path: &Path) -> PathBuf {
    let ext = path
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or("download");

    path.with_extension(format!("{ext}.part"))
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
