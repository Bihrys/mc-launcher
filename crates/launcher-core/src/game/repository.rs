use crate::{GameInstanceDetail, GameInstanceSummary};

pub struct GameRepository;

impl GameRepository {
    pub fn list() -> Result<Vec<GameInstanceSummary>, crate::InstanceError> { crate::instances() }
    pub fn detail(id: &str) -> Result<GameInstanceDetail, crate::InstanceError> { crate::instance_detail(id) }
    pub fn selected() -> Result<String, crate::InstanceError> { crate::selected_version() }
}
