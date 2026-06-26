use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GameInstance {
    pub id: String,
    pub version_json_path: PathBuf,
    pub run_directory: PathBuf,
    pub version_type: Option<String>,
    pub inherits_from: Option<String>,
    pub loaders: Vec<String>,
    pub created_at: Option<String>,
    pub modified_at: Option<String>,
}
