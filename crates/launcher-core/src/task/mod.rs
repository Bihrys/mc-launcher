pub mod event;
pub mod executor;
pub mod state;

pub use event::{TaskEvent, TaskEventKind};
pub use executor::TaskExecutor;
pub use state::{TaskSnapshot, TaskStatus};

pub type TaskError = Box<dyn std::error::Error + Send + Sync + 'static>;
