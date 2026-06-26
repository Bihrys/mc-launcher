#[derive(Debug, Clone)]
pub enum CoreEvent { TaskChanged(String), InstanceChanged(String), AccountChanged }
