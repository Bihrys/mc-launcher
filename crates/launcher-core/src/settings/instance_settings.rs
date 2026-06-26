pub struct InstanceSettingsRepository;
impl InstanceSettingsRepository {
    pub fn save_json(version_id: &str, settings_json: &str) -> Result<String, crate::InstanceError> {
        crate::save_instance_settings_json(version_id, settings_json)
    }
}
