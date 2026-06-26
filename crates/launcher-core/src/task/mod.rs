pub mod async_executor;
pub mod context;
pub mod event;
pub mod executor;
pub mod lifecycle;
pub mod listener;
pub mod node;
pub mod scheduler;
pub mod significance;
pub mod state;

pub use async_executor::{AsyncTaskExecutor, TaskHandle};
pub use context::TaskContext;
pub use event::{TaskEvent, TaskEventKind};
pub use executor::TaskExecutor;
pub use lifecycle::{TaskEventPhase, TaskLifecycleState, TaskStageHint};
pub use listener::TaskListener;
pub use node::{ClosureTask, Task};
pub use scheduler::{SchedulerKind, Schedulers};
pub use significance::TaskSignificance;
pub use state::{TaskSnapshot, TaskStatus};

pub type TaskError = Box<dyn std::error::Error + Send + Sync + 'static>;
