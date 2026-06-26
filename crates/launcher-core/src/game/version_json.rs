use serde_json::Value;
use std::{fs, path::Path};

pub fn read_version_json(path: &Path) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
    Ok(serde_json::from_str(&fs::read_to_string(path)?)?)
}
