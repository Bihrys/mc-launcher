use crate::task::{TaskEvent, TaskLifecycleState, TaskSnapshot};

pub trait TaskListener: Send + Sync + 'static {
    fn on_start(&self, _snapshot: &TaskSnapshot) {}
    fn on_ready(&self, _task_name: &str) {}
    fn on_running(&self, _task_name: &str) {}
    fn on_properties_update(&self, _task_name: &str) {}
    fn on_finished(&self, _task_name: &str) {}
    fn on_failed(&self, _task_name: &str, _error: &str) {}
    fn on_event(&self, _event: &TaskEvent) {}
    fn on_stop(&self, _success: bool, _state: TaskLifecycleState) {}
}
