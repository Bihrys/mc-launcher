use serde::{Deserialize, Serialize};
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct InstallPlan { pub game_version: String, pub loader_kind: String, pub loader_version: String }
