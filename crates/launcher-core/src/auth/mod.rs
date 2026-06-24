use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use std::fs;
use std::io;
use std::path::PathBuf;

pub mod microsoft;
pub mod offline;
pub mod oauth;
pub mod yggdrasil;

pub use microsoft::login_microsoft_browser;
pub use offline::{login_offline, offline_player_uuid};
pub use yggdrasil::{
    complete_yggdrasil_login, login_yggdrasil, login_yggdrasil_start, YggdrasilLoginResult,
    YggdrasilPendingLogin, YggdrasilProfileChoice,
};

use self::microsoft::refresh_microsoft_account;
use self::yggdrasil::refresh_yggdrasil_account;

pub type AuthError = Box<dyn std::error::Error + Send + Sync + 'static>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthAccount {
    pub kind: String,
    pub username: String,
    pub uuid: String,
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub client_token: Option<String>,
    pub user_properties_json: Option<String>,
    pub server_url: Option<String>,
    pub note: Option<String>,

    // Microsoft refresh token 刷新需要保留 public client id。
    pub client_id: Option<String>,

    // 离线账户本地皮肤。HMCL OfflineAccountSkinPane 会保存离线皮肤设置；
    // 这里先保存本地 skin path/model，前端头像和后续启动注入都可以读取。
    pub skin_path: Option<String>,
    pub skin_model: Option<String>,

    // 对应 HMCL 的全局/本地账户迁移状态。
    pub storage_scope: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthServer {
    pub name: String,
    pub url: String,
    pub host: String,
}

pub fn load_auth_servers() -> Result<Vec<AuthServer>, AuthError> {
    let path = auth_servers_path()?;

    let mut servers = match fs::read_to_string(&path) {
        Ok(text) if !text.trim().is_empty() => serde_json::from_str::<Vec<AuthServer>>(&text)?,
        Ok(_) => Vec::new(),
        Err(err) if err.kind() == io::ErrorKind::NotFound => Vec::new(),
        Err(err) => return Err(Box::new(err)),
    };

    if servers.is_empty() {
        servers = default_auth_servers();
        save_auth_servers(&servers)?;
    }

    Ok(servers)
}

pub fn save_auth_servers(servers: &[AuthServer]) -> Result<(), AuthError> {
    let path = auth_servers_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string_pretty(servers)?)?;
    Ok(())
}

pub fn add_auth_server(name: &str, url: &str) -> Result<Vec<AuthServer>, AuthError> {
    let url = normalize_server_url(url)?;
    let host = auth_server_host(&url);
    let name = name.trim();
    let name = if name.is_empty() { host.as_str() } else { name };

    let mut servers = load_auth_servers()?;
    servers.retain(|server| server.url != url);
    servers.push(AuthServer {
        name: name.to_string(),
        url,
        host,
    });
    save_auth_servers(&servers)?;
    Ok(servers)
}

pub fn delete_auth_server(index: usize) -> Result<Vec<AuthServer>, AuthError> {
    let mut servers = load_auth_servers()?;

    if index >= servers.len() {
        return Err(simple_error("认证服务器索引不存在。"));
    }

    servers.remove(index);

    if servers.is_empty() {
        servers = default_auth_servers();
    }

    save_auth_servers(&servers)?;
    Ok(servers)
}

fn default_auth_servers() -> Vec<AuthServer> {
    vec![AuthServer {
        name: "LittleSkin".to_string(),
        url: "https://littleskin.cn/api/yggdrasil".to_string(),
        host: "littleskin.cn".to_string(),
    }]
}

fn auth_server_host(url: &str) -> String {
    let rest = url
        .trim()
        .trim_start_matches("https://")
        .trim_start_matches("http://");

    rest.split('/').next().unwrap_or(rest).to_string()
}

fn auth_servers_path() -> Result<PathBuf, AuthError> {
    let config_home = if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            PathBuf::from(value)
        } else {
            home_dir()?.join(".config")
        }
    } else {
        home_dir()?.join(".config")
    };

    Ok(config_home.join("mc-launcher").join("auth-servers.json"))
}

pub fn save_account(account: &AuthAccount) -> Result<PathBuf, AuthError> {
    let path = accounts_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    let mut accounts: Vec<AuthAccount> = fs::read_to_string(&path)
        .ok()
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default();

    accounts.retain(|existing| {
        !(existing.kind == account.kind
            && existing.uuid == account.uuid
            && existing.server_url == account.server_url)
    });

    accounts.push(account.clone());

    fs::write(&path, serde_json::to_string_pretty(&accounts)?)?;
    select_account(account)?;

    Ok(path)
}

pub fn load_accounts() -> Result<Vec<AuthAccount>, AuthError> {
    let path = accounts_path()?;

    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(err) => return Err(Box::new(err)),
    };

    if text.trim().is_empty() {
        return Ok(Vec::new());
    }

    Ok(serde_json::from_str(&text)?)
}

pub fn delete_account(
    kind: &str,
    uuid: &str,
    server_url: Option<&str>,
) -> Result<Vec<AuthAccount>, AuthError> {
    let path = accounts_path()?;
    let mut accounts = load_accounts()?;

    let before = accounts.len();

    accounts.retain(|account| {
        let same_server = account.server_url.as_deref().unwrap_or("") == server_url.unwrap_or("");

        !(account.kind == kind && account.uuid == uuid && same_server)
    });

    if accounts.len() == before {
        return Err(simple_error("没有找到要删除的账户。"));
    }

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(&path, serde_json::to_string_pretty(&accounts)?)?;

    let removed_identifier = format!("{}|{}|{}", kind, server_url.unwrap_or(""), uuid);

    if read_selected_account_identifier()?.as_deref() == Some(removed_identifier.as_str()) {
        if let Some(account) = accounts.first() {
            select_account(account)?;
        } else {
            clear_selected_account()?;
        }
    }

    Ok(accounts)
}

pub fn select_account(account: &AuthAccount) -> Result<(), AuthError> {
    write_selected_account_identifier(&account_identifier(account))
}

pub fn select_account_identifier(identifier: &str) -> Result<(), AuthError> {
    write_selected_account_identifier(identifier)
}

pub fn selected_account() -> Result<Option<AuthAccount>, AuthError> {
    let accounts = load_accounts()?;

    if accounts.is_empty() {
        clear_selected_account()?;
        return Ok(None);
    }

    let selected = read_selected_account_identifier()?;

    if let Some(selected) = selected {
        if let Some(account) = accounts
            .iter()
            .find(|account| account_identifier(account) == selected)
        {
            return Ok(Some(account.clone()));
        }
    }

    let account = accounts[0].clone();
    select_account(&account)?;
    Ok(Some(account))
}

pub fn account_identifier(account: &AuthAccount) -> String {
    format!(
        "{}|{}|{}",
        account.kind,
        account.server_url.as_deref().unwrap_or(""),
        account.uuid
    )
}

fn write_selected_account_identifier(identifier: &str) -> Result<(), AuthError> {
    let path = selected_account_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, identifier)?;
    Ok(())
}

fn read_selected_account_identifier() -> Result<Option<String>, AuthError> {
    let path = selected_account_path()?;

    match fs::read_to_string(path) {
        Ok(text) => {
            let value = text.trim().to_string();

            if value.is_empty() {
                Ok(None)
            } else {
                Ok(Some(value))
            }
        }
        Err(err) if err.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(err) => Err(Box::new(err)),
    }
}

fn clear_selected_account() -> Result<(), AuthError> {
    let path = selected_account_path();
    if let Ok(path) = path {
        let _ = fs::remove_file(path);
    }
    Ok(())
}

fn selected_account_path() -> Result<PathBuf, AuthError> {
    let config_home = if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            PathBuf::from(value)
        } else {
            home_dir()?.join(".config")
        }
    } else {
        home_dir()?.join(".config")
    };

    Ok(config_home.join("mc-launcher").join("selected-account.txt"))
}

pub fn refresh_account(account: &AuthAccount) -> Result<AuthAccount, AuthError> {
    match account.kind.as_str() {
        "offline" => Ok(account.clone()),
        "microsoft" => refresh_microsoft_account(account),
        "yggdrasil" => refresh_yggdrasil_account(account),
        other => Err(simple_error(format!("暂不支持刷新账户类型：{other}"))),
    }
}

pub fn upload_account_skin(
    account: &AuthAccount,
    skin_file: &std::path::Path,
    slim: bool,
) -> Result<AuthAccount, AuthError> {
    validate_skin_file(skin_file)?;

    match account.kind.as_str() {
        "offline" => {
            let mut updated = account.clone();
            let path = save_offline_skin_file(account, skin_file)?;
            updated.skin_path = Some(path.to_string_lossy().to_string());
            updated.skin_model = Some(if slim { "slim" } else { "classic" }.to_string());
            save_account(&updated)?;
            Ok(updated)
        }
        "microsoft" => {
            let refreshed = refresh_microsoft_account(account)?;

            http_client()?
                .post("https://api.minecraftservices.com/minecraft/profile/skins")
                .bearer_auth(&refreshed.access_token)
                .multipart(
                    reqwest::blocking::multipart::Form::new()
                        .text("variant", if slim { "slim" } else { "classic" }.to_string())
                        .file("file", skin_file)?,
                )
                .send()?
                .error_for_status()?;

            let updated = refresh_microsoft_account(&refreshed)?;
            save_account(&updated)?;
            Ok(updated)
        }
        "yggdrasil" => {
            let refreshed = refresh_yggdrasil_account(account)?;
            let server_url = refreshed
                .server_url
                .as_deref()
                .ok_or_else(|| simple_error("第三方账户缺少服务器地址。"))?;

            let compact_uuid = refreshed
                .uuid
                .chars()
                .filter(|ch| *ch != '-')
                .collect::<String>();
            let upload_url = format!(
                "{}/api/user/profile/{}/skin",
                server_url.trim_end_matches('/'),
                compact_uuid
            );

            http_client()?
                .put(&upload_url)
                .bearer_auth(&refreshed.access_token)
                .multipart(
                    reqwest::blocking::multipart::Form::new()
                        .text("model", if slim { "slim" } else { "" }.to_string())
                        .file("file", skin_file)?,
                )
                .send()?
                .error_for_status()?;

            let updated = refresh_yggdrasil_account(&refreshed)?;
            save_account(&updated)?;
            Ok(updated)
        }
        other => Err(simple_error(format!("暂不支持上传皮肤到账户类型：{other}"))),
    }
}

pub fn migrate_account_storage(
    account: &AuthAccount,
    target_scope: &str,
) -> Result<AuthAccount, AuthError> {
    let target_scope = match target_scope {
        "global" => "global",
        "portable" => "portable",
        "toggle" => {
            if account.storage_scope.as_deref() == Some("portable") {
                "global"
            } else {
                "portable"
            }
        }
        other => return Err(simple_error(format!("未知账户存储位置：{other}"))),
    };

    let mut updated = account.clone();
    updated.storage_scope = Some(target_scope.to_string());

    save_account(&updated)?;
    Ok(updated)
}

pub fn cleanup_avatar_cache(max_age_days: u64) -> Result<usize, AuthError> {
    let cache_dir = avatar_cache_dir_for_cleanup()?;

    let Ok(entries) = fs::read_dir(&cache_dir) else {
        return Ok(0);
    };

    let max_age = std::time::Duration::from_secs(max_age_days.saturating_mul(24 * 60 * 60));
    let now = std::time::SystemTime::now();
    let mut removed = 0usize;

    for entry in entries.flatten() {
        let path = entry.path();

        if !path.is_file() {
            continue;
        }

        let Ok(meta) = entry.metadata() else {
            continue;
        };

        let Ok(modified) = meta.modified() else {
            continue;
        };

        if now.duration_since(modified).unwrap_or_default() > max_age {
            if fs::remove_file(&path).is_ok() {
                removed += 1;
            }
        }
    }

    Ok(removed)
}

fn validate_skin_file(path: &std::path::Path) -> Result<(), AuthError> {
    let image = image::open(path)?;
    let width = image.width();
    let height = image.height();

    if width != 64 || (height != 32 && height != 64) {
        return Err(simple_error(format!(
            "皮肤图片尺寸必须是 64x32 或 64x64，当前是 {width}x{height}。"
        )));
    }

    Ok(())
}

fn save_offline_skin_file(
    account: &AuthAccount,
    skin_file: &std::path::Path,
) -> Result<PathBuf, AuthError> {
    let dir = offline_skins_dir()?;
    fs::create_dir_all(&dir)?;

    let file_name = format!("{}-{}.png", account.kind, account.uuid.replace('-', ""));
    let target = dir.join(file_name);
    fs::copy(skin_file, &target)?;
    Ok(target)
}

fn offline_skins_dir() -> Result<PathBuf, AuthError> {
    let config_home = if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            PathBuf::from(value)
        } else {
            home_dir()?.join(".config")
        }
    } else {
        home_dir()?.join(".config")
    };

    Ok(config_home.join("mc-launcher").join("offline-skins"))
}

fn avatar_cache_dir_for_cleanup() -> Result<PathBuf, AuthError> {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher").join("avatars"));
        }
    }

    Ok(home_dir()?
        .join(".cache")
        .join("mc-launcher")
        .join("avatars"))
}

pub(crate) fn normalize_server_url(server_url: &str) -> Result<String, AuthError> {
    let mut server_url = server_url.trim().trim_end_matches('/').to_string();

    if server_url.is_empty() {
        return Err(simple_error(
            "第三方服务器地址不能为空。可以直接填 littleskin.cn，或点击 LittleSkin 快捷按钮。",
        ));
    }

    if server_url.contains("example.com") {
        return Err(simple_error(
            "第三方服务器地址仍然包含 example.com。请清空后重新填写，例如：https://littleskin.cn/api/yggdrasil",
        ));
    }

    if !server_url.starts_with("http://") && !server_url.starts_with("https://") {
        server_url = format!("https://{server_url}");
    }

    server_url = server_url.replace("https//", "https://");
    server_url = server_url.replace("http//", "http://");

    if server_url.ends_with("/authserver/authenticate") {
        server_url = server_url
            .trim_end_matches("/authserver/authenticate")
            .trim_end_matches('/')
            .to_string();
    } else if server_url.ends_with("/authserver") {
        server_url = server_url
            .trim_end_matches("/authserver")
            .trim_end_matches('/')
            .to_string();
    }

    if !server_url.ends_with("/api/yggdrasil") {
        if server_url.contains("littleskin.cn") {
            server_url = format!("{}/api/yggdrasil", server_url.trim_end_matches('/'));
        }
    }

    if !server_url.starts_with("http://") && !server_url.starts_with("https://") {
        return Err(simple_error(
            "第三方服务器地址必须以 http:// 或 https:// 开头。",
        ));
    }

    Ok(server_url)
}

pub(crate) fn is_valid_minecraft_name(value: &str) -> bool {
    let len = value.chars().count();

    if !(3..=16).contains(&len) {
        return false;
    }

    value
        .chars()
        .all(|ch| ch.is_ascii_alphanumeric() || ch == '_')
}

fn accounts_path() -> Result<PathBuf, AuthError> {
    let config_home = if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            PathBuf::from(value)
        } else {
            home_dir()?.join(".config")
        }
    } else {
        home_dir()?.join(".config")
    };

    Ok(config_home.join("mc-launcher").join("accounts.json"))
}

pub(crate) fn home_dir() -> Result<PathBuf, AuthError> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
}

pub(crate) fn http_client() -> Result<Client, AuthError> {
    Ok(Client::builder()
        .user_agent("mc-launcher/0.1 auth")
        .build()?)
}

pub(crate) fn simple_error(message: impl Into<String>) -> AuthError {
    Box::new(io::Error::other(message.into()))
}

