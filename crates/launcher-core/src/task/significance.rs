#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskSignificance {
    Major,
    Minor,
    Invisible,
}

impl TaskSignificance {
    pub fn should_log(self) -> bool {
        !matches!(self, TaskSignificance::Invisible)
    }
}

impl Default for TaskSignificance {
    fn default() -> Self {
        Self::Major
    }
}
