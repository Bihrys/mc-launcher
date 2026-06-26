use crate::instance::{
    folder::InstanceFolderService,
    model::{GameInstanceDetail, GameInstanceSummary, InstanceError},
    operation::InstanceOperationService,
    scanner::InstanceScanner,
    settings::InstanceSettingsService,
};
use std::path::PathBuf;

pub struct InstanceService;

impl InstanceService {
    pub fn list() -> Result<Vec<GameInstanceSummary>, InstanceError> { InstanceScanner::scan() }
    pub fn detail(id: &str) -> Result<GameInstanceDetail, InstanceError> { crate::instance_manager::instance_detail(id) }
    pub fn select(id: &str) -> Result<String, InstanceError> { InstanceOperationService::select(id) }
    pub fn rename(id: &str, new_name: &str) -> Result<String, InstanceError> { InstanceOperationService::rename(id, new_name) }
    pub fn duplicate(id: &str, new_name: &str, copy_saves: bool) -> Result<String, InstanceError> { InstanceOperationService::duplicate(id, new_name, copy_saves) }
    pub fn delete(id: &str) -> Result<(), InstanceError> { InstanceOperationService::delete(id) }
    pub fn open_folder(id: &str, sub: &str) -> Result<PathBuf, InstanceError> { InstanceFolderService::open(id, sub) }
    pub fn clean(id: &str) -> Result<u64, InstanceError> { InstanceOperationService::clean(id) }
    pub fn clear_assets() -> Result<(), InstanceError> { InstanceOperationService::clear_assets() }
    pub fn clear_libraries() -> Result<(), InstanceError> { InstanceOperationService::clear_libraries() }
    pub fn save_settings_json(id: &str, settings_json: &str) -> Result<String, InstanceError> { InstanceSettingsService::save_json(id, settings_json) }

    // Compatibility API kept while QML is migrated off JSON string properties.
    pub fn list_json() -> Result<String, InstanceError> { crate::instance_manager::instances_json() }
    pub fn detail_json(id: &str) -> Result<String, InstanceError> { crate::instance_manager::instance_detail_json(id) }
}
