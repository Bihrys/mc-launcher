use crate::instance::model::InstanceError;

pub struct InstanceOperationService;

impl InstanceOperationService {
    pub fn select(id: &str) -> Result<String, InstanceError> { crate::instance_manager::select_instance(id) }
    pub fn rename(id: &str, new_name: &str) -> Result<String, InstanceError> { crate::instance_manager::rename_instance(id, new_name) }
    pub fn duplicate(id: &str, new_name: &str, copy_saves: bool) -> Result<String, InstanceError> { crate::instance_manager::duplicate_instance(id, new_name, copy_saves) }
    pub fn delete(id: &str) -> Result<(), InstanceError> { crate::instance_manager::delete_instance(id) }
    pub fn clean(id: &str) -> Result<u64, InstanceError> { crate::instance_manager::clean_instance(id) }
    pub fn clear_assets() -> Result<(), InstanceError> { crate::instance_manager::clear_assets() }
    pub fn clear_libraries() -> Result<(), InstanceError> { crate::instance_manager::clear_libraries() }
}
