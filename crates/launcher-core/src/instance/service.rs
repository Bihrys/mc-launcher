use crate::{GameInstanceDetail, GameInstanceSummary, InstanceError};

pub struct InstanceService;
impl InstanceService {
    pub fn list() -> Result<Vec<GameInstanceSummary>, InstanceError> { crate::instances() }
    pub fn list_json() -> Result<String, InstanceError> { crate::instances_json() }
    pub fn detail(id: &str) -> Result<GameInstanceDetail, InstanceError> { crate::instance_detail(id) }
    pub fn detail_json(id: &str) -> Result<String, InstanceError> { crate::instance_detail_json(id) }
    pub fn select(id: &str) -> Result<String, InstanceError> { crate::select_instance(id) }
}
