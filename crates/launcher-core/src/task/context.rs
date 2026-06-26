use crate::task::{TaskError, TaskEvent, TaskEventKind};
use std::collections::BTreeMap;
use std::io;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, mpsc};

#[derive(Debug, Clone)]
pub struct TaskContext {
    task_id: String,
    task_name: String,
    inherited_stage: Option<String>,
    cancel_flag: Arc<AtomicBool>,
    progress: Arc<AtomicU64>,
    total: Arc<AtomicU64>,
    properties: Arc<Mutex<BTreeMap<String, String>>>,
    event_sender: Option<mpsc::Sender<TaskEvent>>,
}

impl TaskContext {
    pub fn new(
        task_id: impl Into<String>,
        task_name: impl Into<String>,
        inherited_stage: Option<String>,
        cancel_flag: Arc<AtomicBool>,
        event_sender: Option<mpsc::Sender<TaskEvent>>,
    ) -> Self {
        Self {
            task_id: task_id.into(),
            task_name: task_name.into(),
            inherited_stage,
            cancel_flag,
            progress: Arc::new(AtomicU64::new(0)),
            total: Arc::new(AtomicU64::new(0)),
            properties: Arc::new(Mutex::new(BTreeMap::new())),
            event_sender,
        }
    }

    pub fn task_id(&self) -> &str { &self.task_id }
    pub fn task_name(&self) -> &str { &self.task_name }
    pub fn inherited_stage(&self) -> Option<&str> { self.inherited_stage.as_deref() }
    pub fn is_cancelled(&self) -> bool { self.cancel_flag.load(Ordering::Relaxed) }

    pub fn cancel_flag(&self) -> Arc<AtomicBool> { self.cancel_flag.clone() }

    pub fn check_cancelled(&self) -> Result<(), TaskError> {
        if self.is_cancelled() {
            Err(Box::new(io::Error::new(io::ErrorKind::Interrupted, "任务已取消。")))
        } else {
            Ok(())
        }
    }

    pub fn set_total(&self, total: u64) {
        self.total.store(total, Ordering::Relaxed);
        self.emit(TaskEvent::new(TaskEventKind::Progress, self.percent_message("")));
    }

    pub fn set_progress(&self, progress: u64) {
        self.progress.store(progress, Ordering::Relaxed);
        self.emit(TaskEvent::new(TaskEventKind::Progress, self.percent_message("")));
    }

    pub fn add_progress(&self, delta: u64) {
        self.progress.fetch_add(delta, Ordering::Relaxed);
        self.emit(TaskEvent::new(TaskEventKind::Progress, self.percent_message("")));
    }

    pub fn progress(&self) -> u64 { self.progress.load(Ordering::Relaxed) }
    pub fn total(&self) -> u64 { self.total.load(Ordering::Relaxed) }

    pub fn percent(&self) -> u32 {
        let total = self.total();
        if total == 0 { 0 } else { ((self.progress().saturating_mul(100)) / total).min(100) as u32 }
    }

    pub fn set_property(&self, key: impl Into<String>, value: impl Into<String>) {
        if let Ok(mut map) = self.properties.lock() {
            map.insert(key.into(), value.into());
        }
        self.emit(TaskEvent::new(TaskEventKind::Progress, "properties"));
    }

    pub fn properties(&self) -> BTreeMap<String, String> {
        self.properties.lock().map(|map| map.clone()).unwrap_or_default()
    }

    pub fn message(&self, message: impl Into<String>) {
        self.emit(TaskEvent::new(TaskEventKind::Progress, message));
    }

    pub fn emit(&self, event: TaskEvent) {
        if let Some(sender) = &self.event_sender {
            let _ = sender.send(event);
        }
    }

    fn percent_message(&self, suffix: &str) -> String {
        if suffix.is_empty() {
            format!("{}%", self.percent())
        } else {
            format!("{}% {suffix}", self.percent())
        }
    }
}
