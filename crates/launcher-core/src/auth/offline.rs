use super::{is_valid_minecraft_name, simple_error, AuthAccount, AuthError};
use uuid::Uuid;

pub fn offline_player_uuid(username: &str) -> Uuid {
    // HMCL / Minecraft Java 版离线 UUID：
    // UUID.nameUUIDFromBytes(("OfflinePlayer:" + username).getBytes(UTF_8))
    let mut bytes = md5::compute(format!("OfflinePlayer:{username}").as_bytes()).0;

    bytes[6] &= 0x0f;
    bytes[6] |= 0x30;

    bytes[8] &= 0x3f;
    bytes[8] |= 0x80;

    Uuid::from_bytes(bytes)
}

pub fn login_offline(username: &str) -> Result<AuthAccount, AuthError> {
    let username = username.trim();

    if username.is_empty() {
        return Err(simple_error("离线用户名不能为空。"));
    }

    if !is_valid_minecraft_name(username) {
        return Err(simple_error(
            "离线用户名只能包含 3-16 位字母、数字或下划线。",
        ));
    }

    let uuid = offline_player_uuid(username);

    Ok(AuthAccount {
        kind: "offline".to_string(),
        username: username.to_string(),
        uuid: uuid.to_string(),
        access_token: "0".to_string(),
        refresh_token: None,
        client_token: None,
        user_properties_json: None,
        server_url: None,
        client_id: None,
        skin_path: None,
        skin_model: None,
        storage_scope: Some("global".to_string()),
        note: Some("离线账户，不进行正版验证。".to_string()),
    })
}
