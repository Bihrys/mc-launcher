use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};

pub type ResourcePackError = Box<dyn std::error::Error + Send + Sync + 'static>;

const DISABLED_SUFFIX: &str = ".disabled";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResourcePackInfo {
    /// File or directory name on disk, including the `.disabled` suffix when disabled.
    pub file_name: String,
    pub path: PathBuf,
    pub enabled: bool,
    /// Whether the pack is a folder rather than a zip archive.
    pub is_directory: bool,
    pub file_size: u64,
    /// Display name (file stem).
    pub name: String,
    pub description: String,
    /// pack_format value from pack.mcmeta, 0 when unknown.
    pub pack_format: i64,
}

/// Lists the resource packs in a directory. Recognizes both enabled (`*.zip` and
/// folders) and disabled (`*.zip.disabled` / `*.disabled` folders) packs and reads
/// metadata from pack.mcmeta inside each.
pub fn list_resourcepacks(packs_dir: &Path) -> Result<Vec<ResourcePackInfo>, ResourcePackError> {
    let mut packs = Vec::new();

    if !packs_dir.exists() || !packs_dir.is_dir() {
        return Ok(packs);
    }

    for entry in fs::read_dir(packs_dir)? {
        let entry = entry?;
        let path = entry.path();

        let file_name = match path.file_name().and_then(|name| name.to_str()) {
            Some(name) => name.to_string(),
            None => continue,
        };

        let is_directory = path.is_dir();
        let is_zip = file_name.ends_with(".zip") || file_name.ends_with(".zip.disabled");

        // Skip files that are neither zips nor directories.
        if !is_directory && !is_zip {
            continue;
        }

        let enabled = !file_name.ends_with(DISABLED_SUFFIX);
        let file_size = if is_directory {
            0
        } else {
            entry.metadata().map(|meta| meta.len()).unwrap_or(0)
        };

        let meta = if is_directory {
            read_pack_mcmeta_dir(&path)
        } else {
            read_pack_mcmeta_zip(&path)
        }
        .unwrap_or_default();

        packs.push(ResourcePackInfo {
            file_name: file_name.clone(),
            path,
            enabled,
            is_directory,
            file_size,
            name: display_stem(&file_name, is_directory),
            description: meta.description,
            pack_format: meta.pack_format,
        });
    }

    packs.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    Ok(packs)
}

/// Toggles a resource pack between enabled and disabled by renaming on disk.
/// Returns the new file name.
pub fn set_resourcepack_enabled(
    packs_dir: &Path,
    file_name: &str,
    enabled: bool,
) -> Result<String, ResourcePackError> {
    let current = packs_dir.join(file_name);
    if !current.exists() {
        return Err(format!("资源包不存在：{file_name}").into());
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

    let target = packs_dir.join(&target_name);
    fs::rename(&current, &target)?;
    Ok(target_name)
}

/// Deletes a resource pack from disk (file or directory).
pub fn delete_resourcepack(packs_dir: &Path, file_name: &str) -> Result<(), ResourcePackError> {
    let path = packs_dir.join(file_name);
    if !path.exists() {
        return Err(format!("资源包不存在：{file_name}").into());
    }
    if path.is_dir() {
        fs::remove_dir_all(&path)?;
    } else {
        fs::remove_file(&path)?;
    }
    Ok(())
}

#[derive(Default)]
struct PackMeta {
    description: String,
    pack_format: i64,
}

fn read_pack_mcmeta_zip(path: &Path) -> Option<PackMeta> {
    let file = fs::File::open(path).ok()?;
    let mut archive = zip::ZipArchive::new(file).ok()?;
    let mut entry = archive.by_name("pack.mcmeta").ok()?;
    let mut contents = String::new();
    entry.read_to_string(&mut contents).ok()?;
    parse_pack_mcmeta(&contents)
}

fn read_pack_mcmeta_dir(path: &Path) -> Option<PackMeta> {
    let contents = fs::read_to_string(path.join("pack.mcmeta")).ok()?;
    parse_pack_mcmeta(&contents)
}

fn parse_pack_mcmeta(raw: &str) -> Option<PackMeta> {
    let value: Value = serde_json::from_str(raw).ok()?;
    let pack = value.get("pack")?;

    let description = match pack.get("description") {
        Some(Value::String(s)) => s.clone(),
        Some(other) => json_description(other),
        None => String::new(),
    };

    let pack_format = pack
        .get("pack_format")
        .and_then(Value::as_i64)
        .unwrap_or(0);

    Some(PackMeta {
        description,
        pack_format,
    })
}

/// Minecraft text components can be objects/arrays with a "text" field.
fn json_description(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        Value::Array(items) => items
            .iter()
            .map(json_description)
            .collect::<Vec<_>>()
            .join(""),
        Value::Object(_) => value
            .get("text")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string(),
        _ => String::new(),
    }
}

fn display_stem(file_name: &str, is_directory: bool) -> String {
    let trimmed = file_name.trim_end_matches(DISABLED_SUFFIX);
    if is_directory {
        trimmed.to_string()
    } else {
        trimmed.trim_end_matches(".zip").to_string()
    }
}
