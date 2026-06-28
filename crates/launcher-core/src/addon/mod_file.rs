use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};

pub type ModError = Box<dyn std::error::Error + Send + Sync + 'static>;

const DISABLED_SUFFIX: &str = ".disabled";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModFileInfo {
    /// File name on disk, including the `.disabled` suffix when disabled.
    pub file_name: String,
    pub path: PathBuf,
    pub enabled: bool,
    pub file_size: u64,
    /// Display name parsed from metadata, falling back to the file stem.
    pub name: String,
    pub version: String,
    pub authors: String,
    pub description: String,
    /// fabric / forge / neoforge / quilt / unknown
    pub loader: String,
}

/// Lists the mods in a directory. Recognizes both enabled (`*.jar`) and
/// disabled (`*.jar.disabled`) files and parses metadata from inside each jar.
pub fn list_mods(mods_dir: &Path) -> Result<Vec<ModFileInfo>, ModError> {
    let mut mods = Vec::new();

    if !mods_dir.exists() || !mods_dir.is_dir() {
        return Ok(mods);
    }

    for entry in fs::read_dir(mods_dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }

        let file_name = match path.file_name().and_then(|name| name.to_str()) {
            Some(name) => name.to_string(),
            None => continue,
        };

        let enabled = file_name.ends_with(".jar");
        let disabled = file_name.ends_with(".jar.disabled");
        if !enabled && !disabled {
            continue;
        }

        let file_size = entry.metadata().map(|meta| meta.len()).unwrap_or(0);
        let mut info = parse_mod_jar(&path).unwrap_or_else(|_| ModMetadata::default());

        if info.name.trim().is_empty() {
            info.name = display_stem(&file_name);
        }

        mods.push(ModFileInfo {
            file_name,
            path,
            enabled,
            file_size,
            name: info.name,
            version: info.version,
            authors: info.authors,
            description: info.description,
            loader: info.loader,
        });
    }

    mods.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    Ok(mods)
}

/// Toggles a mod between enabled and disabled by renaming on disk.
/// Returns the new file name.
pub fn set_mod_enabled(mods_dir: &Path, file_name: &str, enabled: bool) -> Result<String, ModError> {
    let current = mods_dir.join(file_name);
    if !current.exists() {
        return Err(format!("Mod 文件不存在：{file_name}").into());
    }

    let is_disabled = file_name.ends_with(DISABLED_SUFFIX);
    let target_name = if enabled {
        if is_disabled {
            file_name.trim_end_matches(DISABLED_SUFFIX).to_string()
        } else {
            file_name.to_string()
        }
    } else if is_disabled {
        file_name.to_string()
    } else {
        format!("{file_name}{DISABLED_SUFFIX}")
    };

    if target_name == file_name {
        return Ok(target_name);
    }

    let target = mods_dir.join(&target_name);
    fs::rename(&current, &target)?;
    Ok(target_name)
}

/// Deletes a mod file from disk.
pub fn delete_mod(mods_dir: &Path, file_name: &str) -> Result<(), ModError> {
    let path = mods_dir.join(file_name);
    if !path.exists() {
        return Err(format!("Mod 文件不存在：{file_name}").into());
    }
    fs::remove_file(&path)?;
    Ok(())
}

#[derive(Default)]
struct ModMetadata {
    name: String,
    version: String,
    authors: String,
    description: String,
    loader: String,
}

fn parse_mod_jar(path: &Path) -> Result<ModMetadata, ModError> {
    let file = fs::File::open(path)?;
    let mut archive = zip::ZipArchive::new(file)?;

    // Fabric / Quilt: fabric.mod.json or quilt.mod.json.
    if let Some(meta) = read_zip_entry(&mut archive, "fabric.mod.json")
        .and_then(|raw| parse_fabric_mod_json(&raw, "fabric"))
    {
        return Ok(meta);
    }
    if let Some(meta) = read_zip_entry(&mut archive, "quilt.mod.json")
        .and_then(|raw| parse_quilt_mod_json(&raw))
    {
        return Ok(meta);
    }

    // Forge / NeoForge: META-INF/mods.toml or META-INF/neoforge.mods.toml.
    for toml_path in ["META-INF/neoforge.mods.toml", "META-INF/mods.toml"] {
        if let Some(raw) = read_zip_entry(&mut archive, toml_path) {
            let loader = if toml_path.contains("neoforge") {
                "neoforge"
            } else {
                "forge"
            };
            if let Some(meta) = parse_mods_toml(&raw, loader) {
                return Ok(meta);
            }
        }
    }

    // Legacy Forge: mcmod.info.
    if let Some(meta) = read_zip_entry(&mut archive, "mcmod.info")
        .and_then(|raw| parse_mcmod_info(&raw))
    {
        return Ok(meta);
    }

    Ok(ModMetadata::default())
}

fn read_zip_entry(archive: &mut zip::ZipArchive<fs::File>, name: &str) -> Option<String> {
    let mut entry = archive.by_name(name).ok()?;
    let mut contents = String::new();
    entry.read_to_string(&mut contents).ok()?;
    Some(contents)
}

fn parse_fabric_mod_json(raw: &str, loader: &str) -> Option<ModMetadata> {
    let value: Value = serde_json::from_str(raw).ok()?;
    let name = value
        .get("name")
        .and_then(Value::as_str)
        .or_else(|| value.get("id").and_then(Value::as_str))
        .unwrap_or_default()
        .to_string();
    let version = value
        .get("version")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let description = value
        .get("description")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let authors = value
        .get("authors")
        .map(json_authors)
        .unwrap_or_default();

    Some(ModMetadata {
        name,
        version,
        authors,
        description,
        loader: loader.to_string(),
    })
}

fn parse_quilt_mod_json(raw: &str) -> Option<ModMetadata> {
    let value: Value = serde_json::from_str(raw).ok()?;
    let quilt_loader = value.get("quilt_loader")?;
    let metadata = quilt_loader.get("metadata");
    let name = metadata
        .and_then(|m| m.get("name"))
        .and_then(Value::as_str)
        .or_else(|| quilt_loader.get("id").and_then(Value::as_str))
        .unwrap_or_default()
        .to_string();
    let version = quilt_loader
        .get("version")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let description = metadata
        .and_then(|m| m.get("description"))
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let authors = metadata
        .and_then(|m| m.get("contributors"))
        .map(json_authors)
        .unwrap_or_default();

    Some(ModMetadata {
        name,
        version,
        authors,
        description,
        loader: "quilt".to_string(),
    })
}

fn parse_mods_toml(raw: &str, loader: &str) -> Option<ModMetadata> {
    // Minimal TOML reader for the [[mods]] table. Avoids pulling a TOML crate.
    let mut name = String::new();
    let mut version = String::new();
    let mut authors = String::new();
    let mut description = String::new();
    let mut in_mods = false;
    let mut captured = false;

    let mut lines = raw.lines().peekable();
    while let Some(line) = lines.next() {
        let trimmed = line.trim();
        if trimmed.starts_with("[[mods]]") {
            if captured {
                break;
            }
            in_mods = true;
            continue;
        }
        if trimmed.starts_with('[') {
            // Top-level authors key may live outside [[mods]].
            if let Some(value) = toml_value(trimmed, "authors") {
                if authors.is_empty() {
                    authors = value;
                }
            }
            if in_mods {
                in_mods = false;
            }
            continue;
        }

        if let Some(value) = toml_value(trimmed, "authors") {
            if authors.is_empty() {
                authors = value;
            }
        }

        if !in_mods {
            continue;
        }

        if let Some(value) = toml_value(trimmed, "displayName") {
            name = value;
            captured = true;
        } else if let Some(value) = toml_value(trimmed, "version") {
            version = value;
        } else if let Some(value) = toml_value(trimmed, "description") {
            description = value;
        }
    }

    if name.is_empty() && version.is_empty() && description.is_empty() {
        return None;
    }

    Some(ModMetadata {
        name,
        version,
        authors,
        description,
        loader: loader.to_string(),
    })
}

fn parse_mcmod_info(raw: &str) -> Option<ModMetadata> {
    let value: Value = serde_json::from_str(raw).ok()?;
    let entry = match &value {
        Value::Array(items) => items.first()?,
        Value::Object(map) => map
            .get("modList")
            .and_then(Value::as_array)
            .and_then(|items| items.first())?,
        _ => return None,
    };

    let name = entry
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let version = entry
        .get("version")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let description = entry
        .get("description")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let authors = entry
        .get("authorList")
        .or_else(|| entry.get("authors"))
        .map(json_authors)
        .unwrap_or_default();

    Some(ModMetadata {
        name,
        version,
        authors,
        description,
        loader: "forge".to_string(),
    })
}

fn json_authors(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        Value::Array(items) => items
            .iter()
            .filter_map(|item| match item {
                Value::String(s) => Some(s.clone()),
                Value::Object(_) => item
                    .get("name")
                    .and_then(Value::as_str)
                    .map(|s| s.to_string()),
                _ => None,
            })
            .collect::<Vec<_>>()
            .join(", "),
        _ => String::new(),
    }
}

fn toml_value(line: &str, key: &str) -> Option<String> {
    let trimmed = line.trim();
    let rest = trimmed.strip_prefix(key)?;
    let rest = rest.trim_start();
    let rest = rest.strip_prefix('=')?;
    let rest = rest.trim();
    let unquoted = rest
        .trim_matches('"')
        .trim_matches('\'')
        .replace("\\n", " ")
        .trim()
        .to_string();
    if unquoted.starts_with("${") {
        return Some(String::new());
    }
    Some(unquoted)
}

fn display_stem(file_name: &str) -> String {
    file_name
        .trim_end_matches(DISABLED_SUFFIX)
        .trim_end_matches(".jar")
        .to_string()
}
