#[derive(Debug, Default)]
pub struct InstanceListVm {
    search_text: String,
}

impl InstanceListVm {
    pub fn new() -> Self { Self::default() }
    pub fn search_text(&self) -> &str { &self.search_text }
    pub fn set_search_text(&mut self, value: impl Into<String>) { self.search_text = value.into(); }
    pub fn refresh_json(&self) -> Result<String, launcher_core::InstanceError> { launcher_app::InstanceService::list_json() }
    pub fn select(&self, id: &str) -> Result<String, launcher_core::InstanceError> { launcher_app::InstanceService::select(id) }
}
