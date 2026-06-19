use crate::auth::AuthAccount;
use base64::engine::general_purpose::{STANDARD, URL_SAFE, URL_SAFE_NO_PAD};
use base64::Engine as _;
use image::imageops::{crop_imm, overlay, resize, FilterType};
use image::RgbaImage;
use reqwest::blocking::Client;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::Duration;
use uuid::Uuid;

pub type AvatarError = Box<dyn std::error::Error + Send + Sync + 'static>;

const DEFAULT_SKINS: [&str; 9] = [
    "alex",
    "ari",
    "efe",
    "kai",
    "makena",
    "noor",
    "steve",
    "sunny",
    "zuri",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum DefaultSkinModel {
    Slim,
    Wide,
}

pub fn account_avatar_url(account: &AuthAccount, size: u32) -> Result<Option<String>, AvatarError> {
    let size = size.clamp(16, 256);

    if account.kind == "offline" {
        let avatar_path = make_offline_default_avatar(&account.uuid, size)?;
        return Ok(Some(path_to_qml_url(&avatar_path)));
    }

    let skin_url = match account.kind.as_str() {
        "yggdrasil" => {
            let Some(server_url) = account.server_url.as_deref() else {
                return Ok(None);
            };

            yggdrasil_skin_url(server_url, &account.uuid)?
        }
        "microsoft" => mojang_skin_url(&account.uuid)?,
        _ => None,
    };

    let Some(skin_url) = skin_url else {
        return Ok(None);
    };

    let avatar_path = make_avatar_from_skin_url(&skin_url, size)?;

    Ok(Some(path_to_qml_url(&avatar_path)))
}

pub fn yggdrasil_profile_avatar_url(
    server_url: &str,
    uuid: &str,
    size: u32,
) -> Result<Option<String>, AvatarError> {
    let Some(skin_url) = yggdrasil_skin_url(server_url, uuid)? else {
        return Ok(None);
    };

    let avatar_path = make_avatar_from_skin_url(&skin_url, size.clamp(16, 256))?;

    Ok(Some(path_to_qml_url(&avatar_path)))
}

fn make_offline_default_avatar(uuid_text: &str, size: u32) -> Result<PathBuf, AvatarError> {
    let uuid = parse_uuid_relaxed(uuid_text)?;
    let index = java_uuid_hash_code(uuid).rem_euclid((DEFAULT_SKINS.len() * 2) as i32) as usize;

    let (model, skin_name) = if index < DEFAULT_SKINS.len() {
        (DefaultSkinModel::Slim, DEFAULT_SKINS[index])
    } else {
        (DefaultSkinModel::Wide, DEFAULT_SKINS[index - DEFAULT_SKINS.len()])
    };

    let model_dir = match model {
        DefaultSkinModel::Slim => "slim",
        DefaultSkinModel::Wide => "wide",
    };

    let cache_dir = avatar_cache_dir()?;
    fs::create_dir_all(&cache_dir)?;

    let avatar_path = cache_dir.join(format!(
        "offline-default-{model_dir}-{skin_name}-{size}.png"
    ));

    if avatar_path.is_file() {
        return Ok(avatar_path);
    }

    let skin = image::load_from_memory(default_skin_bytes(model, skin_name))?.to_rgba8();
    crop_avatar_from_skin_image(&skin, &avatar_path, size)?;

    Ok(avatar_path)
}

fn default_skin_bytes(model: DefaultSkinModel, name: &str) -> &'static [u8] {
    match (model, name) {
        (DefaultSkinModel::Slim, "alex") => &include_bytes!("../assets/img/skin/slim/alex.png")[..],
        (DefaultSkinModel::Slim, "ari") => &include_bytes!("../assets/img/skin/slim/ari.png")[..],
        (DefaultSkinModel::Slim, "efe") => &include_bytes!("../assets/img/skin/slim/efe.png")[..],
        (DefaultSkinModel::Slim, "kai") => &include_bytes!("../assets/img/skin/slim/kai.png")[..],
        (DefaultSkinModel::Slim, "makena") => &include_bytes!("../assets/img/skin/slim/makena.png")[..],
        (DefaultSkinModel::Slim, "noor") => &include_bytes!("../assets/img/skin/slim/noor.png")[..],
        (DefaultSkinModel::Slim, "steve") => &include_bytes!("../assets/img/skin/slim/steve.png")[..],
        (DefaultSkinModel::Slim, "sunny") => &include_bytes!("../assets/img/skin/slim/sunny.png")[..],
        (DefaultSkinModel::Slim, "zuri") => &include_bytes!("../assets/img/skin/slim/zuri.png")[..],

        (DefaultSkinModel::Wide, "alex") => &include_bytes!("../assets/img/skin/wide/alex.png")[..],
        (DefaultSkinModel::Wide, "ari") => &include_bytes!("../assets/img/skin/wide/ari.png")[..],
        (DefaultSkinModel::Wide, "efe") => &include_bytes!("../assets/img/skin/wide/efe.png")[..],
        (DefaultSkinModel::Wide, "kai") => &include_bytes!("../assets/img/skin/wide/kai.png")[..],
        (DefaultSkinModel::Wide, "makena") => &include_bytes!("../assets/img/skin/wide/makena.png")[..],
        (DefaultSkinModel::Wide, "noor") => &include_bytes!("../assets/img/skin/wide/noor.png")[..],
        (DefaultSkinModel::Wide, "steve") => &include_bytes!("../assets/img/skin/wide/steve.png")[..],
        (DefaultSkinModel::Wide, "sunny") => &include_bytes!("../assets/img/skin/wide/sunny.png")[..],
        (DefaultSkinModel::Wide, "zuri") => &include_bytes!("../assets/img/skin/wide/zuri.png")[..],

        _ => unreachable!("unknown HMCL default skin: {name}"),
    }
}

fn parse_uuid_relaxed(uuid_text: &str) -> Result<Uuid, AvatarError> {
    let trimmed = uuid_text.trim();

    if trimmed.is_empty() {
        return Err(simple_error("UUID 为空"));
    }

    Ok(Uuid::parse_str(trimmed)?)
}

fn java_uuid_hash_code(uuid: Uuid) -> i32 {
    let value = uuid.as_u128();
    let most = (value >> 64) as u64;
    let least = value as u64;

    ((most >> 32) ^ most ^ (least >> 32) ^ least) as i32
}

fn yggdrasil_skin_url(server_url: &str, uuid: &str) -> Result<Option<String>, AvatarError> {
    let compact_uuid = compact_uuid(uuid)?;

    let profile_url = format!(
        "{}/sessionserver/session/minecraft/profile/{}",
        server_url.trim_end_matches('/'),
        compact_uuid
    );

    skin_url_from_profile_url(&profile_url)
}

fn mojang_skin_url(uuid: &str) -> Result<Option<String>, AvatarError> {
    let compact_uuid = compact_uuid(uuid)?;

    let profile_url = format!(
        "https://sessionserver.mojang.com/session/minecraft/profile/{}",
        compact_uuid
    );

    skin_url_from_profile_url(&profile_url)
}

fn skin_url_from_profile_url(profile_url: &str) -> Result<Option<String>, AvatarError> {
    let client = http_client()?;

    let response = match client.get(profile_url).send() {
        Ok(response) => response,
        Err(_) => return Ok(None),
    };

    if !response.status().is_success() {
        return Ok(None);
    }

    let value: Value = match response.json() {
        Ok(value) => value,
        Err(_) => return Ok(None),
    };

    let Some(encoded_textures) = extract_textures_property(&value) else {
        return Ok(None);
    };

    let decoded = decode_base64_relaxed(&encoded_textures)?;
    let textures_payload: Value = serde_json::from_slice(&decoded)?;

    Ok(textures_payload
        .get("textures")
        .and_then(|value| value.get("SKIN"))
        .and_then(|value| value.get("url"))
        .and_then(Value::as_str)
        .filter(|url| !url.trim().is_empty())
        .map(ToString::to_string))
}

fn extract_textures_property(profile: &Value) -> Option<String> {
    let properties = profile.get("properties")?;

    if let Some(array) = properties.as_array() {
        for property in array {
            let name = property.get("name").and_then(Value::as_str);
            let value = property.get("value").and_then(Value::as_str);

            if name == Some("textures") {
                return value.map(ToString::to_string);
            }
        }
    }

    if let Some(object) = properties.as_object() {
        if let Some(value) = object.get("textures") {
            if let Some(value) = value.as_str() {
                return Some(value.to_string());
            }

            if let Some(value) = value.get("value").and_then(Value::as_str) {
                return Some(value.to_string());
            }
        }
    }

    None
}

fn make_avatar_from_skin_url(skin_url: &str, size: u32) -> Result<PathBuf, AvatarError> {
    let cache_dir = avatar_cache_dir()?;
    fs::create_dir_all(&cache_dir)?;

    let hash = hex_sha256(skin_url.as_bytes());
    let avatar_path = cache_dir.join(format!("{hash}-{size}.png"));

    if avatar_path.is_file() {
        return Ok(avatar_path);
    }

    let skin_path = cache_dir.join(format!("{hash}-skin.png"));

    if !skin_path.is_file() {
        let client = http_client()?;
        let bytes = client.get(skin_url).send()?.error_for_status()?.bytes()?;
        fs::write(&skin_path, &bytes)?;
    }

    crop_avatar_from_skin(&skin_path, &avatar_path, size)?;

    Ok(avatar_path)
}

fn crop_avatar_from_skin(skin_path: &Path, avatar_path: &Path, size: u32) -> Result<(), AvatarError> {
    let skin = image::open(skin_path)?.to_rgba8();
    crop_avatar_from_skin_image(&skin, avatar_path, size)
}

fn crop_avatar_from_skin_image(
    skin: &RgbaImage,
    avatar_path: &Path,
    size: u32,
) -> Result<(), AvatarError> {
    let width = skin.width();
    let height = skin.height();

    if width < 64 || height < 32 {
        return Err(simple_error(format!(
            "皮肤图片尺寸不合法：{}x{}",
            width, height
        )));
    }

    let scale = (width / 64).max(1);
    let unit = 8 * scale;

    let base_x = 8 * scale;
    let base_y = 8 * scale;
    let hat_x = 40 * scale;
    let hat_y = 8 * scale;

    let face = crop_imm(skin, base_x, base_y, unit, unit).to_image();
    let hat = if hat_x + unit <= width && hat_y + unit <= height {
        Some(crop_imm(skin, hat_x, hat_y, unit, unit).to_image())
    } else {
        None
    };

    let mut canvas = RgbaImage::new(size, size);
    let face_offset = ((size as f32) / 18.0).round() as u32;
    let inner_size = size.saturating_sub(face_offset * 2).max(1);

    let resized_face = resize(&face, inner_size, inner_size, FilterType::Nearest);
    overlay(&mut canvas, &resized_face, face_offset.into(), face_offset.into());

    if let Some(hat) = hat {
        let resized_hat = resize(&hat, size, size, FilterType::Nearest);
        overlay(&mut canvas, &resized_hat, 0, 0);
    }

    canvas.save(avatar_path)?;

    Ok(())
}

fn avatar_cache_dir() -> Result<PathBuf, AvatarError> {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher").join("avatars"));
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return Ok(PathBuf::from(home)
            .join(".cache")
            .join("mc-launcher")
            .join("avatars"));
    }

    Ok(std::env::temp_dir().join("mc-launcher").join("avatars"))
}

fn compact_uuid(uuid: &str) -> Result<String, AvatarError> {
    let value = uuid
        .chars()
        .filter(|ch| *ch != '-')
        .collect::<String>();

    if value.len() != 32 {
        return Err(simple_error(format!("UUID 不合法：{uuid}")));
    }

    Ok(value)
}

fn http_client() -> Result<Client, AvatarError> {
    Ok(Client::builder()
        .user_agent("mc-launcher/0.1 avatar-loader")
        .connect_timeout(Duration::from_secs(8))
        .timeout(Duration::from_secs(20))
        .build()?)
}

fn decode_base64_relaxed(value: &str) -> Result<Vec<u8>, AvatarError> {
    STANDARD
        .decode(value)
        .or_else(|_| URL_SAFE_NO_PAD.decode(value))
        .or_else(|_| URL_SAFE.decode(value))
        .map_err(|err| Box::new(err) as AvatarError)
}

fn hex_sha256(bytes: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    format!("{:x}", hasher.finalize())
}

fn path_to_qml_url(path: &Path) -> String {
    format!("file://{}", path.to_string_lossy())
}

fn simple_error(message: impl Into<String>) -> AvatarError {
    Box::new(io::Error::new(io::ErrorKind::Other, message.into()))
}
