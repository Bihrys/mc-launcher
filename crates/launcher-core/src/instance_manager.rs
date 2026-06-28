use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

pub type InstanceError = Box<dyn std::error::Error + Send + Sync + 'static>;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameInstanceSummary {
    pub id: String,
    pub title: String,
    pub tag: String,
    pub subtitle: String,
    pub icon_name: String,
    pub selected: bool,
    pub version_type: String,
    pub game_version: String,
    pub loader_summary: String,
    pub java_major: Option<u32>,
    pub is_modpack: bool,
    pub is_isolated: bool,
    pub path: PathBuf,
    pub run_directory: PathBuf,
    pub last_modified: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameInstanceDetail {
    pub summary: GameInstanceSummary,
    pub minecraft_root: PathBuf,
    pub version_json: PathBuf,
    pub client_jar: PathBuf,
    pub has_client_jar: bool,
    pub has_version_json: bool,
    pub main_class: String,
    pub inherits_from: String,
    pub folders: Vec<InstanceFolder>,
    pub loaders: Vec<InstanceLoader>,
    pub settings: InstanceSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstanceFolder {
    pub key: String,
    pub title: String,
    pub path: PathBuf,
    pub exists: bool,
    pub item_count: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstanceLoader {
    pub kind: String,
    pub version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstanceSettings {
    pub parent: String,
    pub isolated: bool,
    pub run_directory: String,
    pub java_path: String,
    pub min_memory_mb: u32,
    pub max_memory_mb: u32,
    pub jvm_args: String,
    pub game_args: String,
    pub fullscreen: bool,
    pub width: u32,
    pub height: u32,
    pub server: String,
}

impl Default for InstanceSettings {
    fn default() -> Self {
        Self {
            parent: "global".to_string(),
            isolated: false,
            run_directory: String::new(),
            java_path: String::new(),
            min_memory_mb: 512,
            max_memory_mb: 2048,
            jvm_args: String::new(),
            game_args: String::new(),
            fullscreen: false,
            width: 854,
            height: 480,
            server: String::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct LauncherSettings {
    selected_version: Option<String>,
}

pub fn instances_json() -> Result<String, InstanceError> {
    let selected = selected_version().ok();
    let instances = instances()?
        .into_iter()
        .map(|mut instance| {
            instance.selected = selected.as_deref() == Some(instance.id.as_str());
            instance
        })
        .collect::<Vec<_>>();

    Ok(serde_json::json!({
        "selectedInstance": selected.unwrap_or_default(),
        "minecraftRoot": minecraft_root()?,
        "profileRoot": profile_root()?,
        "instances": instances,
        "profiles": [{
            "id": "default",
            "name": "默认游戏目录",
            "path": minecraft_root()?
        }]
    })
    .to_string())
}

pub fn instances() -> Result<Vec<GameInstanceSummary>, InstanceError> {
    let root = minecraft_root()?;
    let versions_dir = root.join("versions");

    if !versions_dir.exists() {
        return Ok(Vec::new());
    }

    let selected = load_launcher_settings()
        .ok()
        .and_then(|settings| settings.selected_version)
        .filter(|value| !value.trim().is_empty());
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
        if !json_path.exists() {
            continue;
        }

        let json = read_json_or_null(&json_path);
        let settings = load_instance_settings(id).unwrap_or_default();
        let run_directory = run_directory_for(id, &settings)?;
        let loaders = detect_loaders(id, &json);
        let game_version = detect_game_version(id, &json);
        let loader_summary = loaders_to_text(&loaders);
        let subtitle = if loader_summary.is_empty() {
            game_version.clone()
        } else {
            format!("{game_version}, {loader_summary}")
        };
        let tag = read_modpack_version(&path).unwrap_or_default();
        let last_modified = entry
            .metadata()
            .and_then(|metadata| metadata.modified())
            .ok()
            .and_then(system_time_secs)
            .unwrap_or(0);

        out.push(GameInstanceSummary {
            id: id.to_string(),
            title: id.to_string(),
            tag,
            subtitle,
            icon_name: detect_version_icon(id, &json),
            selected: selected.as_deref() == Some(id),
            version_type: json
                .get("type")
                .and_then(Value::as_str)
                .unwrap_or("unknown")
                .to_string(),
            game_version,
            loader_summary,
            java_major: json
                .get("javaVersion")
                .and_then(|value| value.get("majorVersion"))
                .and_then(Value::as_u64)
                .map(|value| value as u32),
            is_modpack: is_modpack_dir(&path),
            is_isolated: is_isolated(id, &settings),
            path,
            run_directory,
            last_modified,
        });
    }

    out.sort_by(|a, b| {
        b.selected
            .cmp(&a.selected)
            .then_with(|| b.last_modified.cmp(&a.last_modified))
            .then_with(|| a.id.cmp(&b.id))
    });

    Ok(out)
}

pub fn instance_detail_json(id: &str) -> Result<String, InstanceError> {
    Ok(serde_json::to_string(&instance_detail(id)?)?)
}

pub fn instance_detail(id: &str) -> Result<GameInstanceDetail, InstanceError> {
    let id = normalize_id(id)?;
    let root = minecraft_root()?;
    let version_dir = root.join("versions").join(&id);
    let version_json = version_dir.join(format!("{id}.json"));
    let client_jar = version_dir.join(format!("{id}.jar"));

    if !version_json.exists() {
        return Err(simple_error(format!("实例不存在：{id}")));
    }

    let json = read_json_or_null(&version_json);
    let settings = load_instance_settings(&id).unwrap_or_default();
    let summary = instances()?
        .into_iter()
        .find(|instance| instance.id == id)
        .ok_or_else(|| simple_error(format!("实例不存在：{id}")))?;
    let run_directory = summary.run_directory.clone();

    Ok(GameInstanceDetail {
        summary,
        minecraft_root: root,
        version_json,
        client_jar: client_jar.clone(),
        has_client_jar: client_jar.exists(),
        has_version_json: true,
        main_class: json
            .get("mainClass")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string(),
        inherits_from: json
            .get("inheritsFrom")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string(),
        folders: folder_list(&run_directory),
        loaders: detect_loaders(&id, &json),
        settings,
    })
}

pub fn select_instance(id: &str) -> Result<String, InstanceError> {
    let id = normalize_id(id)?;
    let root = minecraft_root()?;
    let json_path = root.join("versions").join(&id).join(format!("{id}.json"));

    if !json_path.exists() {
        return Err(simple_error(format!("实例不存在：{}", json_path.display())));
    }

    let mut settings = load_launcher_settings().unwrap_or_default();
    settings.selected_version = Some(id.clone());
    save_launcher_settings(&settings)?;

    Ok(id)
}

pub fn rename_instance(old_id: &str, new_id: &str) -> Result<String, InstanceError> {
    let old_id = normalize_id(old_id)?;
    let new_id = normalize_id(new_id)?;

    if old_id == new_id {
        return Ok(new_id);
    }

    let root = minecraft_root()?;
    let versions_dir = root.join("versions");
    let old_dir = versions_dir.join(&old_id);
    let new_dir = versions_dir.join(&new_id);

    if !old_dir.exists() {
        return Err(simple_error(format!("实例不存在：{old_id}")));
    }

    if new_dir.exists() {
        return Err(simple_error(format!("实例已经存在：{new_id}")));
    }

    fs::rename(&old_dir, &new_dir)?;

    let old_json = new_dir.join(format!("{old_id}.json"));
    let new_json = new_dir.join(format!("{new_id}.json"));
    if old_json.exists() {
        rewrite_version_json_id(&old_json, &new_json, &new_id)?;
    }

    let old_jar = new_dir.join(format!("{old_id}.jar"));
    let new_jar = new_dir.join(format!("{new_id}.jar"));
    if old_jar.exists() && !new_jar.exists() {
        fs::rename(old_jar, new_jar)?;
    }

    let old_settings_dir = instance_config_dir(&old_id)?;
    let new_settings_dir = instance_config_dir(&new_id)?;
    if old_settings_dir.exists() {
        if let Some(parent) = new_settings_dir.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::rename(old_settings_dir, new_settings_dir)?;
    }

    let mut settings = load_launcher_settings().unwrap_or_default();
    if settings.selected_version.as_deref() == Some(old_id.as_str()) {
        settings.selected_version = Some(new_id.clone());
        save_launcher_settings(&settings)?;
    }

    Ok(new_id)
}

pub fn duplicate_instance(source_id: &str, new_id: &str, copy_saves: bool) -> Result<String, InstanceError> {
    let source_id = normalize_id(source_id)?;
    let new_id = normalize_id(new_id)?;

    if source_id == new_id {
        return Err(simple_error("复制后的实例名称不能和原实例相同。"));
    }

    let root = minecraft_root()?;
    let versions_dir = root.join("versions");
    let source_dir = versions_dir.join(&source_id);
    let new_dir = versions_dir.join(&new_id);

    if !source_dir.exists() {
        return Err(simple_error(format!("实例不存在：{source_id}")));
    }

    if new_dir.exists() {
        return Err(simple_error(format!("实例已经存在：{new_id}")));
    }

    copy_dir_recursive(&source_dir, &new_dir)?;

    let source_json = new_dir.join(format!("{source_id}.json"));
    let new_json = new_dir.join(format!("{new_id}.json"));
    if source_json.exists() {
        rewrite_version_json_id(&source_json, &new_json, &new_id)?;
    }

    let source_jar = new_dir.join(format!("{source_id}.jar"));
    let new_jar = new_dir.join(format!("{new_id}.jar"));
    if source_jar.exists() && !new_jar.exists() {
        fs::rename(source_jar, new_jar)?;
    }

    if !copy_saves {
        delete_quietly(new_dir.join("saves"));
    }

    let source_settings = load_instance_settings(&source_id).unwrap_or_default();
    save_instance_settings(&new_id, &source_settings)?;

    Ok(new_id)
}

pub fn delete_instance(id: &str) -> Result<(), InstanceError> {
    let id = normalize_id(id)?;
    let root = minecraft_root()?;
    let version_dir = root.join("versions").join(&id);

    if !version_dir.exists() {
        return Err(simple_error(format!("实例目录不存在：{}", version_dir.display())));
    }

    fs::remove_dir_all(&version_dir)?;
    delete_quietly(instance_config_dir(&id)?);

    let mut settings = load_launcher_settings().unwrap_or_default();

    if settings.selected_version.as_deref() == Some(id.as_str()) {
        settings.selected_version = instances()?.first().map(|instance| instance.id.clone());
        save_launcher_settings(&settings)?;
    }

    Ok(())
}

pub fn open_instance_folder(id: &str, sub: &str) -> Result<PathBuf, InstanceError> {
    let detail = instance_detail(id)?;
    let sub = sub.trim().trim_matches('/');
    let path = if sub.is_empty() {
        detail.summary.run_directory
    } else {
        detail.summary.run_directory.join(sub)
    };

    fs::create_dir_all(&path)?;
    open_folder_path(&path)?;
    Ok(path)
}

pub fn instance_mods(id: &str) -> Result<Vec<crate::addon::mod_file::ModFileInfo>, InstanceError> {
    let detail = instance_detail(id)?;
    let mods_dir = detail.summary.run_directory.join("mods");
    crate::addon::mod_file::list_mods(&mods_dir).map_err(|err| simple_error(err.to_string()))
}

pub fn instance_mods_json(id: &str) -> Result<String, InstanceError> {
    let mods = instance_mods(id)?;
    Ok(serde_json::to_string(&serde_json::json!({ "mods": mods }))?)
}

pub fn set_instance_mod_enabled(
    id: &str,
    file_name: &str,
    enabled: bool,
) -> Result<String, InstanceError> {
    let detail = instance_detail(id)?;
    let mods_dir = detail.summary.run_directory.join("mods");
    crate::addon::mod_file::set_mod_enabled(&mods_dir, file_name, enabled)
        .map_err(|err| simple_error(err.to_string()))
}

pub fn delete_instance_mod(id: &str, file_name: &str) -> Result<(), InstanceError> {
    let detail = instance_detail(id)?;
    let mods_dir = detail.summary.run_directory.join("mods");
    crate::addon::mod_file::delete_mod(&mods_dir, file_name)
        .map_err(|err| simple_error(err.to_string()))
}

pub fn clean_instance(id: &str) -> Result<u64, InstanceError> {
    let detail = instance_detail(id)?;
    let mut removed = 0;

    for name in ["logs", "crash-reports", "shaderpacks/cache", ".fabric", ".mixin.out"] {
        let path = detail.summary.run_directory.join(name);
        if path.exists() {
            delete_path(&path)?;
            removed += 1;
        }
    }

    for file in ["hs_err_pid.log", "replay_pid.log"] {
        let path = detail.summary.run_directory.join(file);
        if path.exists() {
            delete_path(&path)?;
            removed += 1;
        }
    }

    Ok(removed)
}

pub fn clear_assets() -> Result<(), InstanceError> {
    let root = minecraft_root()?;
    delete_quietly(root.join("assets"));
    Ok(())
}

pub fn clear_libraries() -> Result<(), InstanceError> {
    let root = minecraft_root()?;
    delete_quietly(root.join("libraries"));
    Ok(())
}

pub fn save_instance_settings_json(id: &str, json: &str) -> Result<String, InstanceError> {
    let id = normalize_id(id)?;
    let mut settings = load_instance_settings(&id).unwrap_or_default();
    let value: Value = serde_json::from_str(json)?;

    if let Some(value) = value.get("parent").and_then(Value::as_str) {
        settings.parent = value.to_string();
    }
    if let Some(value) = value.get("isolated").and_then(Value::as_bool) {
        settings.isolated = value;
    }
    if let Some(value) = value.get("runDirectory").and_then(Value::as_str) {
        settings.run_directory = value.to_string();
    }
    if let Some(value) = value.get("javaPath").and_then(Value::as_str) {
        settings.java_path = value.to_string();
    }
    if let Some(value) = value.get("minMemoryMb").and_then(Value::as_u64) {
        settings.min_memory_mb = value as u32;
    }
    if let Some(value) = value.get("maxMemoryMb").and_then(Value::as_u64) {
        settings.max_memory_mb = value as u32;
    }
    if let Some(value) = value.get("jvmArgs").and_then(Value::as_str) {
        settings.jvm_args = value.to_string();
    }
    if let Some(value) = value.get("gameArgs").and_then(Value::as_str) {
        settings.game_args = value.to_string();
    }
    if let Some(value) = value.get("fullscreen").and_then(Value::as_bool) {
        settings.fullscreen = value;
    }
    if let Some(value) = value.get("width").and_then(Value::as_u64) {
        settings.width = value as u32;
    }
    if let Some(value) = value.get("height").and_then(Value::as_u64) {
        settings.height = value as u32;
    }
    if let Some(value) = value.get("server").and_then(Value::as_str) {
        settings.server = value.to_string();
    }

    save_instance_settings(&id, &settings)?;
    instance_detail_json(&id)
}

fn folder_list(run_directory: &Path) -> Vec<InstanceFolder> {
    [
        ("game", "游戏文件夹", ""),
        ("mods", "Mod", "mods"),
        ("resourcepacks", "资源包", "resourcepacks"),
        ("saves", "存档", "saves"),
        ("shaderpacks", "光影包", "shaderpacks"),
        ("screenshots", "截图", "screenshots"),
        ("config", "配置", "config"),
        ("logs", "日志", "logs"),
        ("crash-reports", "崩溃报告", "crash-reports"),
    ]
    .into_iter()
    .map(|(key, title, sub)| {
        let path = if sub.is_empty() {
            run_directory.to_path_buf()
        } else {
            run_directory.join(sub)
        };
        let exists = path.exists();
        let item_count = count_children(&path).unwrap_or(0);

        InstanceFolder {
            key: key.to_string(),
            title: title.to_string(),
            path,
            exists,
            item_count,
        }
    })
    .collect()
}

fn detect_loaders(id: &str, json: &Value) -> Vec<InstanceLoader> {
    let mut loaders = Vec::new();
    let mut seen = HashSet::new();
    let mut haystack = id.to_ascii_lowercase();

    if let Some(main_class) = json.get("mainClass").and_then(Value::as_str) {
        haystack.push(' ');
        haystack.push_str(&main_class.to_ascii_lowercase());
    }

    if let Some(libraries) = json.get("libraries").and_then(Value::as_array) {
        for library in libraries {
            if let Some(name) = library.get("name").and_then(Value::as_str) {
                let lower = name.to_ascii_lowercase();
                haystack.push(' ');
                haystack.push_str(&lower);

                let parsed = if lower.contains("net.fabricmc:fabric-loader") {
                    Some(("Fabric", library_version(name)))
                } else if lower.contains("org.quiltmc:quilt-loader") {
                    Some(("Quilt", library_version(name)))
                } else if lower.contains("net.neoforged:neoforge") {
                    Some(("NeoForge", library_version(name)))
                } else if lower.contains("net.minecraftforge:forge") || lower.contains("minecraftforge") {
                    Some(("Forge", library_version(name)))
                } else if lower.contains("optifine") {
                    Some(("OptiFine", library_version(name)))
                } else {
                    None
                };

                if let Some((kind, version)) = parsed {
                    let key = format!("{kind}:{version}");
                    if seen.insert(key) {
                        loaders.push(InstanceLoader {
                            kind: kind.to_string(),
                            version,
                        });
                    }
                }
            }
        }
    }

    for (needle, kind) in [
        ("fabric", "Fabric"),
        ("quilt", "Quilt"),
        ("neoforge", "NeoForge"),
        ("forge", "Forge"),
        ("optifine", "OptiFine"),
    ] {
        if haystack.contains(needle) && !loaders.iter().any(|loader| loader.kind == kind) {
            loaders.push(InstanceLoader {
                kind: kind.to_string(),
                version: String::new(),
            });
        }
    }

    loaders
}

fn loaders_to_text(loaders: &[InstanceLoader]) -> String {
    loaders
        .iter()
        .map(|loader| {
            if loader.version.is_empty() {
                loader.kind.clone()
            } else {
                format!("{}: {}", loader.kind, loader.version)
            }
        })
        .collect::<Vec<_>>()
        .join(", ")
}

fn library_version(name: &str) -> String {
    name.rsplit(':').next().unwrap_or_default().to_string()
}

fn detect_game_version(id: &str, json: &Value) -> String {
    if let Some(value) = json.get("inheritsFrom").and_then(Value::as_str) {
        return value.to_string();
    }

    if let Some(value) = json.get("id").and_then(Value::as_str) {
        return value.to_string();
    }

    id.to_string()
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

    let version_type = json
        .get("type")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_ascii_lowercase();

    if version_type == "snapshot" || is_snapshot_like_version(id) {
        return "command".to_string();
    }

    if version_type.starts_with("old_") || is_old_like_version(id) {
        return "craft_table".to_string();
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


fn is_snapshot_like_version(id: &str) -> bool {
    let lower = id.to_ascii_lowercase();
    let bytes = lower.as_bytes();

    if bytes.len() >= 6
        && bytes[0].is_ascii_digit()
        && bytes[1].is_ascii_digit()
        && bytes[2] == b'w'
        && bytes[3].is_ascii_digit()
        && bytes[4].is_ascii_digit()
        && bytes[5].is_ascii_lowercase()
    {
        return true;
    }

    lower.contains("snapshot") || lower.contains("pre") || lower.contains("rc")
}

fn is_old_like_version(id: &str) -> bool {
    let lower = id.to_ascii_lowercase();

    lower.starts_with("old_")
        || lower.starts_with("rd-")
        || lower.starts_with("c0.")
        || lower.starts_with("a1.")
        || lower.starts_with("b1.")
        || lower.starts_with("inf-")
        || lower.contains("classic")
        || lower.contains("indev")
        || lower.contains("infdev")
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

fn is_modpack_dir(path: &Path) -> bool {
    ["modpack.json", "minecraftinstance.json", "instance.cfg"]
        .iter()
        .any(|name| path.join(name).exists())
}

fn read_modpack_version(path: &Path) -> Option<String> {
    for name in ["modpack.json", "minecraftinstance.json"] {
        let file = path.join(name);
        if !file.exists() {
            continue;
        }
        let value = read_json_or_null(&file);
        if let Some(version) = value.get("version").and_then(Value::as_str) {
            return Some(version.to_string());
        }
        if let Some(version) = value.get("modpackVersion").and_then(Value::as_str) {
            return Some(version.to_string());
        }
    }

    None
}

fn is_isolated(id: &str, settings: &InstanceSettings) -> bool {
    if settings.isolated {
        return true;
    }

    let Ok(root) = minecraft_root() else {
        return false;
    };

    run_directory_for(id, settings)
        .map(|path| path == root.join("versions").join(id))
        .unwrap_or(false)
}

fn run_directory_for(id: &str, settings: &InstanceSettings) -> Result<PathBuf, InstanceError> {
    if !settings.run_directory.trim().is_empty() {
        return Ok(PathBuf::from(settings.run_directory.trim()));
    }

    let root = minecraft_root()?;

    if settings.isolated {
        Ok(root.join("versions").join(id))
    } else {
        Ok(root)
    }
}

fn rewrite_version_json_id(source_json: &Path, target_json: &Path, new_id: &str) -> Result<(), InstanceError> {
    let mut json = read_json_or_null(source_json);

    if let Some(object) = json.as_object_mut() {
        object.insert("id".to_string(), Value::String(new_id.to_string()));
        if object.get("jar").and_then(Value::as_str).is_some() {
            object.insert("jar".to_string(), Value::String(new_id.to_string()));
        }
    }

    fs::write(target_json, serde_json::to_string_pretty(&json)?)?;
    if source_json != target_json {
        let _ = fs::remove_file(source_json);
    }

    Ok(())
}

fn copy_dir_recursive(from: &Path, to: &Path) -> Result<(), InstanceError> {
    fs::create_dir_all(to)?;

    for entry in fs::read_dir(from)? {
        let entry = entry?;
        let source = entry.path();
        let target = to.join(entry.file_name());

        if source.is_dir() {
            copy_dir_recursive(&source, &target)?;
        } else {
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)?;
            }
            fs::copy(source, target)?;
        }
    }

    Ok(())
}

fn count_children(path: &Path) -> Result<u64, InstanceError> {
    if !path.exists() || !path.is_dir() {
        return Ok(0);
    }

    Ok(fs::read_dir(path)?.count() as u64)
}

fn read_json_or_null(path: &Path) -> Value {
    fs::read_to_string(path)
        .ok()
        .and_then(|text| serde_json::from_str::<Value>(&text).ok())
        .unwrap_or(Value::Null)
}

fn normalize_id(id: &str) -> Result<String, InstanceError> {
    let id = id.trim();

    if id.is_empty() {
        return Err(simple_error("实例名称不能为空。"));
    }

    if id.contains('/') || id.contains('\\') || id == "." || id == ".." || id.contains('\0') {
        return Err(simple_error("实例名称不能包含路径分隔符。"));
    }

    Ok(id.to_string())
}

fn system_time_secs(time: SystemTime) -> Option<u64> {
    time.duration_since(UNIX_EPOCH).ok().map(|value| value.as_secs())
}

fn open_folder_path(path: &Path) -> Result<(), InstanceError> {
    let mut command = match std::env::consts::OS {
        "linux" => {
            let mut command = Command::new("xdg-open");
            command.arg(path);
            command
        }
        "macos" => {
            let mut command = Command::new("open");
            command.arg(path);
            command
        }
        "windows" => {
            let mut command = Command::new("cmd");
            let target = path.display().to_string();
            command.args(["/C", "start", "", &target]);
            command
        }
        other => return Err(simple_error(format!("暂不支持打开文件夹的系统：{other}"))),
    };

    command.spawn()?;
    Ok(())
}

fn delete_quietly(path: PathBuf) {
    let _ = delete_path(&path);
}

fn delete_path(path: &Path) -> Result<(), InstanceError> {
    if !path.exists() {
        return Ok(());
    }

    if path.is_dir() {
        fs::remove_dir_all(path)?;
    } else {
        fs::remove_file(path)?;
    }

    Ok(())
}

fn load_instance_settings(id: &str) -> Result<InstanceSettings, InstanceError> {
    let path = instance_settings_path(id)?;

    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(InstanceSettings::default()),
        Err(err) => return Err(Box::new(err)),
    };

    if text.trim().is_empty() {
        return Ok(InstanceSettings::default());
    }

    Ok(serde_json::from_str(&text)?)
}

fn save_instance_settings(id: &str, settings: &InstanceSettings) -> Result<(), InstanceError> {
    let path = instance_settings_path(id)?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string_pretty(settings)?)?;
    Ok(())
}

fn instance_settings_path(id: &str) -> Result<PathBuf, InstanceError> {
    Ok(instance_config_dir(id)?.join("settings.json"))
}

fn instance_config_dir(id: &str) -> Result<PathBuf, InstanceError> {
    Ok(profile_root()?.join("instances").join(id))
}

fn load_launcher_settings() -> Result<LauncherSettings, InstanceError> {
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

fn save_launcher_settings(settings: &LauncherSettings) -> Result<(), InstanceError> {
    let path = settings_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string_pretty(settings)?)?;
    Ok(())
}

fn selected_version() -> Result<String, InstanceError> {
    let settings = load_launcher_settings()?;

    if let Some(version) = settings.selected_version {
        if !version.trim().is_empty() {
            return Ok(version);
        }
    }

    instances()?
        .first()
        .map(|instance| instance.id.clone())
        .ok_or_else(|| simple_error("还没有已安装实例。请先到下载页安装。"))
}

fn settings_path() -> Result<PathBuf, InstanceError> {
    Ok(config_root()?.join("settings.json"))
}

fn profile_root() -> Result<PathBuf, InstanceError> {
    Ok(config_root()?.join("profiles").join("default"))
}

fn minecraft_root() -> Result<PathBuf, InstanceError> {
    Ok(data_root()?.join("minecraft"))
}

fn config_root() -> Result<PathBuf, InstanceError> {
    if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".config").join("mc-launcher"))
}

fn data_root() -> Result<PathBuf, InstanceError> {
    if let Some(value) = std::env::var_os("XDG_DATA_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".local").join("share").join("mc-launcher"))
}

fn home_dir() -> Result<PathBuf, InstanceError> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
}

fn simple_error(message: impl Into<String>) -> InstanceError {
    Box::new(io::Error::other(message.into()))
}
