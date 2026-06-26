use crate::task::{TaskContext, TaskError, TaskSignificance, TaskStageHint};

pub trait Task: Send + 'static {
    fn name(&self) -> &str;
    fn stage(&self) -> Option<&str> { None }
    fn significance(&self) -> TaskSignificance { TaskSignificance::Major }
    fn stage_hints(&self) -> Vec<TaskStageHint> { Vec::new() }
    fn rely_on_dependents(&self) -> bool { true }
    fn rely_on_dependencies(&self) -> bool { true }
    fn dependents(&mut self) -> Vec<Box<dyn Task>> { Vec::new() }
    fn dependencies(&mut self) -> Vec<Box<dyn Task>> { Vec::new() }
    fn pre_execute(&mut self, _ctx: &TaskContext) -> Result<(), TaskError> { Ok(()) }
    fn execute(&mut self, ctx: &TaskContext) -> Result<(), TaskError>;
    fn post_execute(&mut self, _ctx: &TaskContext) -> Result<(), TaskError> { Ok(()) }
}

pub struct ClosureTask<F>
where
    F: FnMut(&TaskContext) -> Result<(), TaskError> + Send + 'static,
{
    name: String,
    stage: Option<String>,
    significance: TaskSignificance,
    action: F,
    dependents: Vec<Box<dyn Task>>,
    dependencies: Vec<Box<dyn Task>>,
}

impl<F> ClosureTask<F>
where
    F: FnMut(&TaskContext) -> Result<(), TaskError> + Send + 'static,
{
    pub fn new(name: impl Into<String>, action: F) -> Self {
        Self {
            name: name.into(),
            stage: None,
            significance: TaskSignificance::Major,
            action,
            dependents: Vec::new(),
            dependencies: Vec::new(),
        }
    }

    pub fn stage(mut self, stage: impl Into<String>) -> Self {
        self.stage = Some(stage.into());
        self
    }

    pub fn significance(mut self, significance: TaskSignificance) -> Self {
        self.significance = significance;
        self
    }

    pub fn dependent(mut self, task: Box<dyn Task>) -> Self {
        self.dependents.push(task);
        self
    }

    pub fn dependency(mut self, task: Box<dyn Task>) -> Self {
        self.dependencies.push(task);
        self
    }
}

impl<F> Task for ClosureTask<F>
where
    F: FnMut(&TaskContext) -> Result<(), TaskError> + Send + 'static,
{
    fn name(&self) -> &str { &self.name }
    fn stage(&self) -> Option<&str> { self.stage.as_deref() }
    fn significance(&self) -> TaskSignificance { self.significance }
    fn dependents(&mut self) -> Vec<Box<dyn Task>> { std::mem::take(&mut self.dependents) }
    fn dependencies(&mut self) -> Vec<Box<dyn Task>> { std::mem::take(&mut self.dependencies) }
    fn execute(&mut self, ctx: &TaskContext) -> Result<(), TaskError> { (self.action)(ctx) }
}
