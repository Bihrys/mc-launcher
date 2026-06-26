use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TaskLifecycleState {
    Ready,
    Running,
    Executed,
    Succeeded,
    Failed,
    Cancelled,
}

impl TaskLifecycleState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Ready => "ready",
            Self::Running => "running",
            Self::Executed => "executed",
            Self::Succeeded => "succeeded",
            Self::Failed => "failed",
            Self::Cancelled => "cancelled",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TaskEventPhase {
    Start,
    Ready,
    Running,
    Properties,
    Finished,
    Failed,
    Stop,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TaskStageHint {
    pub stage: String,
    pub weight: u32,
}

impl TaskStageHint {
    pub fn new(stage: impl Into<String>, weight: u32) -> Self {
        Self { stage: stage.into(), weight }
    }
}
