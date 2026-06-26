use crate::{profile_manager::ProfileManager, task_center::TaskCenter};

#[derive(Debug, Default)]
pub struct AppContext {
    pub profile_manager: ProfileManager,
    pub task_center: TaskCenter,
}

impl AppContext {
    pub fn new() -> Self {
        Self::default()
    }
}
