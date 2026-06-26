use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Profile { pub id: String, pub name: String, pub game_dir: PathBuf }
