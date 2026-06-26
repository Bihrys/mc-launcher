use crate::InstanceError;
use super::Profile;

pub struct ProfileRepository;
impl ProfileRepository {
    pub fn default_profile() -> Result<Profile, InstanceError> {
        let payload = crate::instances_json()?;
        let value: serde_json::Value = serde_json::from_str(&payload)?;
        let root = value.get("minecraftRoot").and_then(|v| v.as_str()).unwrap_or_default();
        Ok(Profile { id: "default".into(), name: "默认".into(), game_dir: root.into() })
    }
}
