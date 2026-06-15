#[derive(Debug, Clone)]
pub enum TaskEventKind {
    Started,
    Progress,
    Speed,
    Finished,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone)]
pub struct TaskEvent {
    pub kind: TaskEventKind,
    pub message: String,
}

impl TaskEvent {
    pub fn new(kind: TaskEventKind, message: impl Into<String>) -> Self {
        Self {
            kind,
            message: message.into(),
        }
    }
}
