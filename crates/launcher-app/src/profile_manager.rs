#[derive(Debug, Clone)]
pub struct ProfileManager {
    active_profile: String,
}

impl Default for ProfileManager {
    fn default() -> Self {
        Self { active_profile: "default".to_string() }
    }
}

impl ProfileManager {
    pub fn active_profile(&self) -> &str { &self.active_profile }
    pub fn set_active_profile(&mut self, value: impl Into<String>) { self.active_profile = value.into(); }
}
