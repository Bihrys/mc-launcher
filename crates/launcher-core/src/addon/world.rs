use flate2::read::GzDecoder;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};

pub type WorldError = Box<dyn std::error::Error + Send + Sync + 'static>;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WorldInfo {
    /// Directory name on disk.
    pub file_name: String,
    pub path: PathBuf,
    /// LevelName from level.dat, falls back to the directory name.
    pub name: String,
    /// Game version recorded in level.dat (Data.Version.Name), empty when unknown.
    pub game_version: String,
    /// LastPlayed epoch milliseconds from level.dat, 0 when unknown.
    pub last_played: i64,
    /// Whether an icon.png exists in the world folder.
    pub has_icon: bool,
}

/// Lists the worlds (save directories) under a saves directory. Each immediate
/// subdirectory containing level.dat (or special_level.dat) is treated as a world.
pub fn list_worlds(saves_dir: &Path) -> Result<Vec<WorldInfo>, WorldError> {
    let mut worlds = Vec::new();

    if !saves_dir.exists() || !saves_dir.is_dir() {
        return Ok(worlds);
    }

    for entry in fs::read_dir(saves_dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        let file_name = match path.file_name().and_then(|name| name.to_str()) {
            Some(name) => name.to_string(),
            None => continue,
        };

        let mut level_dat = path.join("level.dat");
        if !level_dat.exists() {
            level_dat = path.join("special_level.dat");
        }
        if !level_dat.exists() {
            continue;
        }

        let meta = read_level_data(&level_dat).unwrap_or_default();
        let name = if meta.level_name.is_empty() {
            file_name.clone()
        } else {
            meta.level_name
        };

        worlds.push(WorldInfo {
            file_name: file_name.clone(),
            path: path.clone(),
            name,
            game_version: meta.game_version,
            last_played: meta.last_played,
            has_icon: path.join("icon.png").is_file(),
        });
    }

    worlds.sort_by(|a, b| b.last_played.cmp(&a.last_played));
    Ok(worlds)
}

/// Deletes a world directory from disk.
pub fn delete_world(saves_dir: &Path, file_name: &str) -> Result<(), WorldError> {
    let path = saves_dir.join(file_name);
    if !path.exists() {
        return Err(format!("世界不存在：{file_name}").into());
    }
    if !path.is_dir() {
        return Err(format!("不是有效的世界目录：{file_name}").into());
    }
    fs::remove_dir_all(&path)?;
    Ok(())
}

#[derive(Default)]
struct LevelData {
    level_name: String,
    game_version: String,
    last_played: i64,
}

fn read_level_data(level_dat: &Path) -> Option<LevelData> {
    let file = fs::File::open(level_dat).ok()?;
    let mut decoder = GzDecoder::new(file);
    let mut bytes = Vec::new();
    decoder.read_to_end(&mut bytes).ok()?;

    let root = parse_nbt(&bytes)?;
    let data = root.compound()?.get("Data")?.compound()?;

    let level_name = data
        .get("LevelName")
        .and_then(NbtTag::string)
        .unwrap_or_default()
        .to_string();

    let last_played = data.get("LastPlayed").and_then(NbtTag::long).unwrap_or(0);

    let game_version = data
        .get("Version")
        .and_then(NbtTag::compound)
        .and_then(|version| version.get("Name"))
        .and_then(NbtTag::string)
        .unwrap_or_default()
        .to_string();

    Some(LevelData {
        level_name,
        game_version,
        last_played,
    })
}

// --- Minimal big-endian NBT reader (read-only, enough to navigate level.dat) ---

enum NbtTag {
    Byte(i8),
    Short(i16),
    Int(i32),
    Long(i64),
    Float(f32),
    Double(f64),
    ByteArray(Vec<i8>),
    String(String),
    List(Vec<NbtTag>),
    Compound(HashMap<String, NbtTag>),
    IntArray(Vec<i32>),
    LongArray(Vec<i64>),
}

impl NbtTag {
    fn compound(&self) -> Option<&HashMap<String, NbtTag>> {
        match self {
            NbtTag::Compound(map) => Some(map),
            _ => None,
        }
    }

    fn string(&self) -> Option<&str> {
        match self {
            NbtTag::String(value) => Some(value),
            _ => None,
        }
    }

    fn long(&self) -> Option<i64> {
        match self {
            NbtTag::Long(value) => Some(*value),
            _ => None,
        }
    }
}

struct NbtReader<'a> {
    bytes: &'a [u8],
    pos: usize,
}

impl<'a> NbtReader<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        NbtReader { bytes, pos: 0 }
    }

    fn read_bytes(&mut self, len: usize) -> Option<&'a [u8]> {
        let end = self.pos.checked_add(len)?;
        if end > self.bytes.len() {
            return None;
        }
        let slice = &self.bytes[self.pos..end];
        self.pos = end;
        Some(slice)
    }

    fn u8(&mut self) -> Option<u8> {
        self.read_bytes(1).map(|b| b[0])
    }

    fn i8(&mut self) -> Option<i8> {
        self.u8().map(|b| b as i8)
    }

    fn i16(&mut self) -> Option<i16> {
        let b = self.read_bytes(2)?;
        Some(i16::from_be_bytes([b[0], b[1]]))
    }

    fn u16(&mut self) -> Option<u16> {
        let b = self.read_bytes(2)?;
        Some(u16::from_be_bytes([b[0], b[1]]))
    }

    fn i32(&mut self) -> Option<i32> {
        let b = self.read_bytes(4)?;
        Some(i32::from_be_bytes([b[0], b[1], b[2], b[3]]))
    }

    fn i64(&mut self) -> Option<i64> {
        let b = self.read_bytes(8)?;
        Some(i64::from_be_bytes([
            b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
        ]))
    }

    fn f32(&mut self) -> Option<f32> {
        self.i32().map(|v| f32::from_bits(v as u32))
    }

    fn f64(&mut self) -> Option<f64> {
        self.i64().map(|v| f64::from_bits(v as u64))
    }

    fn string(&mut self) -> Option<String> {
        let len = self.u16()? as usize;
        let bytes = self.read_bytes(len)?;
        Some(String::from_utf8_lossy(bytes).into_owned())
    }

    fn payload(&mut self, tag_type: u8) -> Option<NbtTag> {
        match tag_type {
            1 => Some(NbtTag::Byte(self.i8()?)),
            2 => Some(NbtTag::Short(self.i16()?)),
            3 => Some(NbtTag::Int(self.i32()?)),
            4 => Some(NbtTag::Long(self.i64()?)),
            5 => Some(NbtTag::Float(self.f32()?)),
            6 => Some(NbtTag::Double(self.f64()?)),
            7 => {
                let len = self.i32()? as usize;
                let mut values = Vec::with_capacity(len.min(1024));
                for _ in 0..len {
                    values.push(self.i8()?);
                }
                Some(NbtTag::ByteArray(values))
            }
            8 => Some(NbtTag::String(self.string()?)),
            9 => {
                let element_type = self.u8()?;
                let len = self.i32()?;
                let mut items = Vec::new();
                if len > 0 {
                    items.reserve((len as usize).min(1024));
                    for _ in 0..len {
                        items.push(self.payload(element_type)?);
                    }
                }
                Some(NbtTag::List(items))
            }
            10 => {
                let mut map = HashMap::new();
                loop {
                    let child_type = self.u8()?;
                    if child_type == 0 {
                        break;
                    }
                    let name = self.string()?;
                    let value = self.payload(child_type)?;
                    map.insert(name, value);
                }
                Some(NbtTag::Compound(map))
            }
            11 => {
                let len = self.i32()? as usize;
                let mut values = Vec::with_capacity(len.min(1024));
                for _ in 0..len {
                    values.push(self.i32()?);
                }
                Some(NbtTag::IntArray(values))
            }
            12 => {
                let len = self.i32()? as usize;
                let mut values = Vec::with_capacity(len.min(1024));
                for _ in 0..len {
                    values.push(self.i64()?);
                }
                Some(NbtTag::LongArray(values))
            }
            _ => None,
        }
    }
}

/// Parses the root NBT tag (a named compound). Returns the root compound tag.
fn parse_nbt(bytes: &[u8]) -> Option<NbtTag> {
    let mut reader = NbtReader::new(bytes);
    let root_type = reader.u8()?;
    if root_type != 10 {
        return None;
    }
    let _root_name = reader.string()?;
    reader.payload(10)
}
