use crate::task::{Task, TaskContext, TaskError, TaskEvent, TaskEventKind, TaskLifecycleState, TaskListener, TaskSnapshot, TaskStatus};
use std::io;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, mpsc};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone)]
pub struct TaskHandle {
    id: String,
    cancel_flag: Arc<AtomicBool>,
    snapshot: Arc<Mutex<TaskSnapshot>>,
    join_handle: Arc<Mutex<Option<thread::JoinHandle<bool>>>>,
}

impl TaskHandle {
    pub fn id(&self) -> &str { &self.id }
    pub fn cancel(&self) { self.cancel_flag.store(true, Ordering::Relaxed); }
    pub fn is_cancelled(&self) -> bool { self.cancel_flag.load(Ordering::Relaxed) }
    pub fn snapshot(&self) -> TaskSnapshot {
        self.snapshot.lock().map(|snapshot| snapshot.clone()).unwrap_or_else(|_| TaskSnapshot::new(self.id.clone(), "任务状态不可用"))
    }
    pub fn join(&self) -> bool {
        let handle = self.join_handle.lock().ok().and_then(|mut handle| handle.take());
        if let Some(handle) = handle { handle.join().unwrap_or(false) } else { false }
    }
}

pub struct AsyncTaskExecutor {
    first_task: Option<Box<dyn Task>>,
    listeners: Vec<Arc<dyn TaskListener>>,
    cancel_flag: Arc<AtomicBool>,
    event_sender: Option<mpsc::Sender<TaskEvent>>,
}

impl AsyncTaskExecutor {
    pub fn new(task: Box<dyn Task>) -> Self {
        Self {
            first_task: Some(task),
            listeners: Vec::new(),
            cancel_flag: Arc::new(AtomicBool::new(false)),
            event_sender: None,
        }
    }

    pub fn add_listener(mut self, listener: Arc<dyn TaskListener>) -> Self {
        self.listeners.push(listener);
        self
    }

    pub fn with_event_sender(mut self, sender: mpsc::Sender<TaskEvent>) -> Self {
        self.event_sender = Some(sender);
        self
    }

    pub fn start(mut self) -> TaskHandle {
        let id = new_task_id();
        let task_name = self.first_task.as_ref().map(|task| task.name().to_string()).unwrap_or_else(|| "Task".to_string());
        let mut snapshot = TaskSnapshot::new(id.clone(), task_name.clone());
        snapshot.message = "准备执行任务...".to_string();
        snapshot.status = TaskStatus::Running.as_str().to_string();
        let snapshot = Arc::new(Mutex::new(snapshot));
        let snapshot_for_thread = snapshot.clone();
        let cancel_flag = self.cancel_flag.clone();
        let cancel_for_thread = cancel_flag.clone();
        let listeners = self.listeners;
        let event_sender = self.event_sender;
        let task = self.first_task.take();
        let id_for_thread = id.clone();
        let join_handle = thread::Builder::new()
            .name(format!("hmcl-task-{task_name}"))
            .spawn(move || {
                let Some(mut task) = task else { return false; };
                let success = run_task_chain(
                    task.as_mut(),
                    None,
                    &id_for_thread,
                    &snapshot_for_thread,
                    cancel_for_thread,
                    event_sender,
                    &listeners,
                ).is_ok();
                if let Ok(mut snapshot) = snapshot_for_thread.lock() {
                    snapshot.active = false;
                    snapshot.speed = 0;
                    snapshot.current_file.clear();
                    if success {
                        snapshot.status = TaskStatus::Finished.as_str().to_string();
                        snapshot.percent = 100;
                        snapshot.message = "任务完成。".to_string();
                    } else if snapshot.cancelled {
                        snapshot.status = TaskStatus::Cancelled.as_str().to_string();
                    } else {
                        snapshot.status = TaskStatus::Failed.as_str().to_string();
                    }
                }
                for listener in &listeners {
                    listener.on_stop(success, if success { TaskLifecycleState::Succeeded } else { TaskLifecycleState::Failed });
                }
                success
            })
            .unwrap_or_else(|_| thread::spawn(|| false));

        TaskHandle {
            id,
            cancel_flag,
            snapshot,
            join_handle: Arc::new(Mutex::new(Some(join_handle))),
        }
    }

    pub fn test(self) -> bool {
        self.start().join()
    }
}

fn run_task_chain(
    task: &mut dyn Task,
    inherited_stage: Option<String>,
    id: &str,
    snapshot: &Arc<Mutex<TaskSnapshot>>,
    cancel_flag: Arc<AtomicBool>,
    event_sender: Option<mpsc::Sender<TaskEvent>>,
    listeners: &[Arc<dyn TaskListener>],
) -> Result<(), TaskError> {
    if cancel_flag.load(Ordering::Relaxed) {
        mark_cancelled(snapshot, "任务已取消。");
        return Err(Box::new(io::Error::new(io::ErrorKind::Interrupted, "任务已取消。")));
    }

    let task_name = task.name().to_string();
    let stage = task.stage().map(ToString::to_string).or(inherited_stage);
    let ctx = TaskContext::new(id, task_name.clone(), stage.clone(), cancel_flag.clone(), event_sender.clone());

    update_snapshot(snapshot, &task_name, "准备执行任务...", TaskLifecycleState::Ready, 0);
    for listener in listeners { listener.on_ready(&task_name); }

    task.pre_execute(&ctx)?;

    let mut dependent_failed = None;
    for mut dependent in task.dependents() {
        if let Err(err) = run_task_chain(dependent.as_mut(), stage.clone(), id, snapshot, cancel_flag.clone(), event_sender.clone(), listeners) {
            dependent_failed = Some(err);
            break;
        }
    }
    if let Some(err) = dependent_failed {
        if task.rely_on_dependents() {
            mark_failed(snapshot, &task_name, &err.to_string());
            return Err(err);
        }
    }

    ctx.check_cancelled()?;
    update_snapshot(snapshot, &task_name, "正在执行任务...", TaskLifecycleState::Running, 0);
    for listener in listeners { listener.on_running(&task_name); }
    if let Some(sender) = &event_sender {
        let _ = sender.send(TaskEvent::new(TaskEventKind::Started, task_name.clone()));
    }

    match task.execute(&ctx) {
        Ok(()) => {
            update_snapshot(snapshot, &task_name, "任务主体已执行。", TaskLifecycleState::Executed, ctx.percent());
            task.post_execute(&ctx)?;
        }
        Err(err) => {
            if cancel_flag.load(Ordering::Relaxed) {
                mark_cancelled(snapshot, "任务已取消。");
            } else {
                mark_failed(snapshot, &task_name, &err.to_string());
            }
            for listener in listeners { listener.on_failed(&task_name, &err.to_string()); }
            return Err(err);
        }
    }

    for mut dependency in task.dependencies() {
        if let Err(err) = run_task_chain(dependency.as_mut(), stage.clone(), id, snapshot, cancel_flag.clone(), event_sender.clone(), listeners) {
            if task.rely_on_dependencies() {
                mark_failed(snapshot, &task_name, &err.to_string());
                return Err(err);
            }
        }
    }

    ctx.check_cancelled()?;
    update_snapshot(snapshot, &task_name, "任务完成。", TaskLifecycleState::Succeeded, 100);
    for listener in listeners { listener.on_finished(&task_name); }
    if let Some(sender) = &event_sender {
        let _ = sender.send(TaskEvent::new(TaskEventKind::Finished, task_name));
    }
    Ok(())
}

fn update_snapshot(snapshot: &Arc<Mutex<TaskSnapshot>>, title: &str, message: &str, state: TaskLifecycleState, percent: u32) {
    if let Ok(mut snapshot) = snapshot.lock() {
        snapshot.title = title.to_string();
        snapshot.message = message.to_string();
        snapshot.status = state.as_str().to_string();
        snapshot.percent = snapshot.percent.max(percent);
        snapshot.active = !matches!(state, TaskLifecycleState::Succeeded | TaskLifecycleState::Failed | TaskLifecycleState::Cancelled);
    }
}

fn mark_failed(snapshot: &Arc<Mutex<TaskSnapshot>>, title: &str, message: &str) {
    if let Ok(mut snapshot) = snapshot.lock() {
        snapshot.title = title.to_string();
        snapshot.active = false;
        snapshot.status = TaskStatus::Failed.as_str().to_string();
        snapshot.message = message.to_string();
    }
}

fn mark_cancelled(snapshot: &Arc<Mutex<TaskSnapshot>>, message: &str) {
    if let Ok(mut snapshot) = snapshot.lock() {
        snapshot.active = false;
        snapshot.cancelled = true;
        snapshot.status = TaskStatus::Cancelled.as_str().to_string();
        snapshot.message = message.to_string();
    }
}

fn new_task_id() -> String {
    let millis = SystemTime::now().duration_since(UNIX_EPOCH).map(|duration| duration.as_millis()).unwrap_or(0);
    format!("task-{millis}-{}", uuid::Uuid::new_v4().simple())
}
