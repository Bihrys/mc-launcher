use std::fs;
use std::path::Path;

pub(crate) fn read_status_text(path: &Path, default_json: &str) -> String {
    fs::read_to_string(path).unwrap_or_else(|_| default_json.to_string())
}

pub(crate) fn task_status_is_active(path: &Path) -> bool {
    let Ok(text) = fs::read_to_string(path) else {
        return false;
    };

    serde_json::from_str::<serde_json::Value>(&text)
        .ok()
        .and_then(|value| value.get("active").and_then(|value| value.as_bool()))
        .unwrap_or(false)
}
