#[derive(Debug, Default, Clone)]
pub struct TaskVm {
    center: launcher_app::TaskCenter,
}

impl TaskVm {
    pub fn new(center: launcher_app::TaskCenter) -> Self { Self { center } }
    pub fn tasks_json(&self) -> String { self.center.json() }
    pub fn cancel(&self, id: &str) -> bool { self.center.cancel(id) }
}
