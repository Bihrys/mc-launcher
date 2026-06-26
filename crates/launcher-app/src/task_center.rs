use crate::dto::{TaskCenterDto, TaskItem};
use launcher_core::task::{AsyncTaskExecutor, ClosureTask, Task, TaskError, TaskHandle, TaskSnapshot};
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

#[derive(Clone, Default)]
pub struct TaskCenter {
    handles: Arc<Mutex<BTreeMap<String, TaskHandle>>>,
}

impl TaskCenter {
    pub fn new() -> Self { Self::default() }

    pub fn spawn(&self, task: Box<dyn Task>) -> String {
        let handle = AsyncTaskExecutor::new(task).start();
        let id = handle.id().to_string();
        if let Ok(mut handles) = self.handles.lock() {
            handles.insert(id.clone(), handle);
        }
        id
    }

    pub fn spawn_closure<F>(&self, name: impl Into<String>, action: F) -> String
    where
        F: FnMut(&launcher_core::task::TaskContext) -> Result<(), TaskError> + Send + 'static,
    {
        self.spawn(Box::new(ClosureTask::new(name, action)))
    }

    pub fn cancel(&self, id: &str) -> bool {
        let Ok(handles) = self.handles.lock() else { return false; };
        if let Some(handle) = handles.get(id) {
            handle.cancel();
            true
        } else {
            false
        }
    }

    pub fn snapshot(&self, id: &str) -> Option<TaskSnapshot> {
        self.handles.lock().ok().and_then(|handles| handles.get(id).map(TaskHandle::snapshot))
    }

    pub fn snapshots(&self) -> Vec<TaskSnapshot> {
        self.handles
            .lock()
            .map(|handles| handles.values().map(TaskHandle::snapshot).collect())
            .unwrap_or_default()
    }

    pub fn prune_finished(&self) {
        if let Ok(mut handles) = self.handles.lock() {
            handles.retain(|_, handle| handle.snapshot().active);
        }
    }

    pub fn dto(&self) -> TaskCenterDto {
        let tasks = self.snapshots().into_iter().map(snapshot_to_item).collect::<Vec<_>>();
        let active_count = tasks.iter().filter(|task| task.active).count();
        TaskCenterDto { active_count, tasks }
    }

    pub fn json(&self) -> String {
        serde_json::to_string(&self.dto()).unwrap_or_else(|_| "{\"activeCount\":0,\"tasks\":[]}".to_string())
    }
}

fn snapshot_to_item(snapshot: TaskSnapshot) -> TaskItem {
    TaskItem {
        id: snapshot.id,
        title: snapshot.title,
        message: snapshot.message,
        percent: snapshot.percent as f64,
        active: snapshot.active,
        status: snapshot.status,
        cancelled: snapshot.cancelled,
    }
}

impl std::fmt::Debug for TaskCenter {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TaskCenter").field("task_count", &self.snapshots().len()).finish()
    }
}
