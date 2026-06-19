use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::io;
use std::path::PathBuf;

pub type VersionError = Box<dyn std::error::Error + Send + Sync + 'static>;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstalledVersion {
    pub id: String,
    pub version_type: String,
    pub inherits_from: Option<String>,
    pub main_class: Option<String>,
    pub java_major: Option<u32>,
    pub has_client_jar: bool,
    pub has_version_json: bool,
    pub selected: bool,
    pub icon_name: String,
    pub path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct LauncherSettings {
    selected_version: Option<String>,
}

pub fn installed_versions_json() -> Result<String, VersionError> {
    let selected = selected_version().ok();
    let versions = installed_versions()?
        .into_iter()
        .map(|mut version| {
            version.selected = selected.as_deref() == Some(version.id.as_str());
            version
        })
        .collect::<Vec<_>>();

    Ok(serde_json::json!({
        "selectedVersion": selected.unwrap_or_default(),
        "versions": versions,
        "minecraftRoot": minecraft_root()?,
    })
    .to_string())
}

pub fn installed_versions() -> Result<Vec<InstalledVersion>, VersionError> {
    let root = minecraft_root()?;
    let versions_dir = root.join("versions");

    if !versions_dir.exists() {
        return Ok(Vec::new());
    }

    let mut out = Vec::new();

    for entry in fs::read_dir(&versions_dir)? {
        let entry = entry?;
        let path = entry.path();

        if !path.is_dir() {
            continue;
        }

        let Some(id) = path.file_name().and_then(|value| value.to_str()) else {
            continue;
        };

        let json_path = path.join(format!("{id}.json"));
        let jar_path = path.join(format!("{id}.jar"));

        if !json_path.exists() {
            continue;
        }

        let json = fs::read_to_string(&json_path)
            .ok()
            .and_then(|text| serde_json::from_str::<Value>(&text).ok())
            .unwrap_or(Value::Null);

        let icon_name = detect_version_icon(id, &json);

        out.push(InstalledVersion {
            id: id.to_string(),
            version_type: json
                .get("type")
                .and_then(Value::as_str)
                .unwrap_or("unknown")
                .to_string(),
            inherits_from: json
                .get("inheritsFrom")
                .and_then(Value::as_str)
                .map(ToString::to_string),
            main_class: json
                .get("mainClass")
                .and_then(Value::as_str)
                .map(ToString::to_string),
            java_major: json
                .get("javaVersion")
                .and_then(|value| value.get("majorVersion"))
                .and_then(Value::as_u64)
                .map(|value| value as u32),
            has_client_jar: jar_path.exists(),
            has_version_json: true,
            selected: false,
            icon_name,
            path,
        });
    }

    out.sort_by(|a, b| b.id.cmp(&a.id));

    Ok(out)
}

pub fn selected_version() -> Result<String, VersionError> {
    let settings = load_settings()?;

    if let Some(version) = settings.selected_version {
        if !version.trim().is_empty() {
            return Ok(version);
        }
    }

    let versions = installed_versions()?;

    versions
        .first()
        .map(|version| version.id.clone())
        .ok_or_else(|| simple_error("还没有已安装版本。请先到下载页安装游戏版本。"))
}

pub fn select_version(version_id: &str) -> Result<String, VersionError> {
    let version_id = version_id.trim();

    if version_id.is_empty() {
        return Err(simple_error("版本 ID 不能为空。"));
    }

    let root = minecraft_root()?;
    let json_path = root
        .join("versions")
        .join(version_id)
        .join(format!("{version_id}.json"));

    if !json_path.exists() {
        return Err(simple_error(format!(
            "版本不存在或未安装：{}",
            json_path.display()
        )));
    }

    let mut settings = load_settings().unwrap_or_default();
    settings.selected_version = Some(version_id.to_string());
    save_settings(&settings)?;

    Ok(version_id.to_string())
}

pub fn delete_version(version_id: &str) -> Result<(), VersionError> {
    let version_id = version_id.trim();

    if version_id.is_empty() {
        return Err(simple_error("版本 ID 不能为空。"));
    }

    let root = minecraft_root()?;
    let version_dir = root.join("versions").join(version_id);

    if !version_dir.exists() {
        return Err(simple_error(format!("版本目录不存在：{}", version_dir.display())));
    }

    fs::remove_dir_all(&version_dir)?;

    let mut settings = load_settings().unwrap_or_default();

    if settings.selected_version.as_deref() == Some(version_id) {
        settings.selected_version = installed_versions()?.first().map(|version| version.id.clone());
        save_settings(&settings)?;
    }

    Ok(())
}

fn detect_version_icon(id: &str, json: &Value) -> String {
    let mut haystack = String::new();
    haystack.push_str(&id.to_ascii_lowercase());
    haystack.push(' ');

    for key in ["inheritsFrom", "mainClass", "minecraftArguments"] {
        if let Some(value) = json.get(key).and_then(Value::as_str) {
            haystack.push_str(&value.to_ascii_lowercase());
            haystack.push(' ');
        }
    }

    if let Some(arguments) = json.get("arguments") {
        haystack.push_str(&arguments.to_string().to_ascii_lowercase());
        haystack.push(' ');
    }

    if let Some(libraries) = json.get("libraries").and_then(Value::as_array) {
        for library in libraries {
            if let Some(name) = library.get("name").and_then(Value::as_str) {
                haystack.push_str(&name.to_ascii_lowercase());
                haystack.push(' ');
            }
        }
    }

    if is_april_fools_version(id) {
        return "april_fools".to_string();
    }

    for (needle, icon) in [
        ("cleanroom", "cleanroom"),
        ("legacyfabric", "legacyfabric"),
        ("legacy-fabric", "legacyfabric"),
        ("neoforged", "neoforge"),
        ("neoforge", "neoforge"),
        ("quilt-loader", "quilt"),
        ("org.quiltmc", "quilt"),
        ("quilt", "quilt"),
        ("fabric-loader", "fabric"),
        ("net.fabricmc", "fabric"),
        ("fabric", "fabric"),
        ("optifine", "optifine"),
        ("net.minecraftforge:forge", "forge"),
        ("minecraftforge", "forge"),
        ("forge", "forge"),
        ("liteloader", "chicken"),
        ("lite_loader", "chicken"),
    ] {
        if haystack.contains(needle) {
            return icon.to_string();
        }
    }

    "grass".to_string()
}

fn is_april_fools_version(id: &str) -> bool {
    let lower = id.to_ascii_lowercase();

    matches!(id, "2.0" | "15w14a" | "1.RV-Pre1")
        || lower.contains("infinite")
        || lower.contains("oneblockatatime")
        || lower.contains("_or_b")
        || lower.contains("potato")
        || lower.contains("craftmine")
        || lower.contains("shareware")
        || lower.contains("3d shareware")
}

fn load_settings() -> Result<LauncherSettings, VersionError> {
    let path = settings_path()?;

    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(LauncherSettings::default()),
        Err(err) => return Err(Box::new(err)),
    };

    if text.trim().is_empty() {
        return Ok(LauncherSettings::default());
    }

    Ok(serde_json::from_str(&text)?)
}

fn save_settings(settings: &LauncherSettings) -> Result<(), VersionError> {
    let path = settings_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string_pretty(settings)?)?;

    Ok(())
}

fn settings_path() -> Result<PathBuf, VersionError> {
    Ok(config_root()?.join("settings.json"))
}

fn minecraft_root() -> Result<PathBuf, VersionError> {
    Ok(data_root()?.join("minecraft"))
}

fn config_root() -> Result<PathBuf, VersionError> {
    if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".config").join("mc-launcher"))
}

fn data_root() -> Result<PathBuf, VersionError> {
    if let Some(value) = std::env::var_os("XDG_DATA_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".local").join("share").join("mc-launcher"))
}

fn home_dir() -> Result<PathBuf, VersionError> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
}

fn simple_error(message: impl Into<String>) -> VersionError {
    Box::new(io::Error::other(message.into()))
}
