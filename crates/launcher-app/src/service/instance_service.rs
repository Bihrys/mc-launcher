use std::path::PathBuf;

pub struct InstanceService;

impl InstanceService {
    pub fn list_json() -> Result<String, launcher_core::InstanceError> { launcher_core::instances_json() }
    pub fn detail_json(version_id: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::instance_detail_json(version_id) }
    pub fn select(version_id: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::select_instance(version_id) }
    pub fn rename(version_id: &str, new_name: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::rename_instance(version_id, new_name) }
    pub fn duplicate(version_id: &str, new_name: &str, copy_saves: bool) -> Result<String, launcher_core::InstanceError> { launcher_core::duplicate_instance(version_id, new_name, copy_saves) }
    pub fn delete(version_id: &str) -> Result<(), launcher_core::InstanceError> { launcher_core::delete_instance(version_id) }
    pub fn open_folder(version_id: &str, sub_dir: Option<&str>) -> Result<PathBuf, launcher_core::InstanceError> {
        launcher_core::open_instance_folder(version_id, sub_dir.unwrap_or(""))
    }
    pub fn clean(version_id: &str) -> Result<usize, launcher_core::InstanceError> {
        launcher_core::clean_instance(version_id).map(|count| count as usize)
    }
    pub fn clear_assets() -> Result<(), launcher_core::InstanceError> { launcher_core::clear_assets() }
    pub fn clear_libraries() -> Result<(), launcher_core::InstanceError> { launcher_core::clear_libraries() }
    pub fn save_settings_json(version_id: &str, settings_json: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::save_instance_settings_json(version_id, settings_json) }
}
