use crate::instance::model::InstanceError;

pub struct InstanceSettingsService;

impl InstanceSettingsService {
    pub fn save_json(id: &str, settings_json: &str) -> Result<String, InstanceError> {
        crate::instance_manager::save_instance_settings_json(id, settings_json)
    }
}
