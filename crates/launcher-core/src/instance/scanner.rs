use crate::instance::model::{GameInstanceSummary, InstanceError};

pub struct InstanceScanner;

impl InstanceScanner {
    pub fn scan() -> Result<Vec<GameInstanceSummary>, InstanceError> {
        crate::instance_manager::instances()
    }
}
