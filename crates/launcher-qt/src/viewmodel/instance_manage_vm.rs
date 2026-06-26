#[derive(Debug, Default)]
pub struct InstanceManageVm {
    current_instance_id: String,
    current_tab: String,
}

impl InstanceManageVm {
    pub fn new() -> Self { Self { current_tab: "settings".to_string(), ..Self::default() } }
    pub fn current_instance_id(&self) -> &str { &self.current_instance_id }
    pub fn set_current_instance_id(&mut self, id: impl Into<String>) { self.current_instance_id = id.into(); }
    pub fn current_tab(&self) -> &str { &self.current_tab }
    pub fn set_current_tab(&mut self, tab: impl Into<String>) { self.current_tab = tab.into(); }
    pub fn detail_json(&self) -> Result<String, launcher_core::InstanceError> { launcher_app::InstanceService::detail_json(&self.current_instance_id) }
}
