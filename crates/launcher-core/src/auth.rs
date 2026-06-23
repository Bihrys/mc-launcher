use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
use std::io::{self, Read, Write};
use std::net::TcpListener;
use std::path::PathBuf;
use std::process::Command;
use std::time::Duration;
use uuid::Uuid;

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
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthServer {
    pub name: String,
    pub url: String,
    pub host: String,
}

#[derive(Debug, Deserialize)]
struct MicrosoftTokenResponse {
    access_token: Option<String>,
    refresh_token: Option<String>,
    error: Option<String>,
    error_description: Option<String>,
}

#[derive(Debug, Deserialize)]
struct XboxAuthResponse {
    #[serde(rename = "Token")]
    token: Option<String>,

    #[serde(rename = "DisplayClaims")]
    display_claims: Option<XboxDisplayClaims>,

    #[serde(rename = "XErr")]
    xerr: Option<u64>,

    #[serde(rename = "Message")]
    message: Option<String>,
}

#[derive(Debug, Deserialize)]
struct XboxDisplayClaims {
    xui: Vec<HashMap<String, String>>,
}

#[derive(Debug, Deserialize)]
struct MinecraftLoginResponse {
    access_token: String,
}

#[derive(Debug, Deserialize)]
struct MinecraftProfileResponse {
    id: String,
    name: String,
}

#[derive(Debug, Deserialize)]
struct YggdrasilAuthResponse {
    #[serde(rename = "accessToken")]
    access_token: Option<String>,

    #[serde(rename = "clientToken")]
    client_token: Option<String>,

    #[serde(rename = "selectedProfile")]
    selected_profile: Option<YggdrasilProfile>,

    #[serde(rename = "availableProfiles")]
    available_profiles: Option<Vec<YggdrasilProfile>>,

    user: Option<serde_json::Value>,

    error: Option<String>,

    #[serde(rename = "errorMessage")]
    error_message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct YggdrasilProfile {
    id: String,
    name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YggdrasilProfileChoice {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YggdrasilPendingLogin {
    pub server_url: String,
    pub username: String,
    pub access_token: String,
    pub client_token: String,
    pub profiles: Vec<YggdrasilProfileChoice>,
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
        return Err(simple_error("离线用户名只能包含 3-16 位字母、数字或下划线。"));
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
        note: Some("离线账户，不进行正版验证。".to_string()),
    })
}

pub fn login_yggdrasil(
    server_url: &str,
    username: &str,
    password: &str,
) -> Result<AuthAccount, AuthError> {
    match login_yggdrasil_start(server_url, username, password)? {
        YggdrasilLoginResult::Account(account) => Ok(account),
        YggdrasilLoginResult::Pending(pending) => {
            if pending.profiles.len() == 1 {
                complete_yggdrasil_login(&pending, 0)
            } else {
                Err(simple_error("该第三方账户有多个角色，需要先选择角色。"))
            }
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum YggdrasilLoginResult {
    Account(AuthAccount),
    Pending(YggdrasilPendingLogin),
}

pub fn login_yggdrasil_start(
    server_url: &str,
    username: &str,
    password: &str,
) -> Result<YggdrasilLoginResult, AuthError> {
    let server_url = normalize_server_url(server_url)?;
    let username = username.trim();

    if username.is_empty() {
        return Err(simple_error("第三方账户用户名不能为空。"));
    }

    if password.is_empty() {
        return Err(simple_error("第三方账户密码不能为空。"));
    }

    let client_token = Uuid::new_v4().to_string();
    let auth_url = format!("{}/authserver/authenticate", server_url.trim_end_matches('/'));

    let body = json!({
        "agent": {
            "name": "Minecraft",
            "version": 1
        },
        "username": username,
        "password": password,
        "clientToken": client_token,
        "requestUser": true
    });

    let client = http_client()?;
    let response = client.post(&auth_url).json(&body).send()?;
    let status = response.status();
    let text = response.text()?;

    let parsed: YggdrasilAuthResponse = serde_json::from_str(&text).map_err(|err| {
        simple_error(format!(
            "第三方服务器响应不是有效 Yggdrasil JSON。\n\nHTTP: {status}\nURL: {auth_url}\n\n{err}\n\n{text}"
        ))
    })?;

    if !status.is_success() {
        let message = parsed
            .error_message
            .or(parsed.error)
            .unwrap_or_else(|| text.clone());

        return Err(simple_error(format!(
            "第三方服务器登录失败。\n\nHTTP: {status}\nURL: {auth_url}\n\n{message}"
        )));
    }

    if let Some(error) = parsed.error {
        let message = parsed.error_message.unwrap_or_default();
        return Err(simple_error(format!("第三方服务器登录失败：{error}\n{message}")));
    }

    let access_token = parsed
        .access_token
        .ok_or_else(|| simple_error("第三方服务器没有返回 accessToken。"))?;

    let response_client_token = parsed.client_token.unwrap_or_else(|| client_token.clone());

    if response_client_token != client_token {
        return Err(simple_error(format!(
            "第三方服务器返回的 clientToken 不一致。\n请求: {client_token}\n响应: {response_client_token}"
        )));
    }

    let user_properties_json = yggdrasil_user_properties_json(parsed.user.as_ref());

    if let Some(profile) = parsed.selected_profile {
        return Ok(YggdrasilLoginResult::Account(yggdrasil_account_from_profile(
            &server_url,
            username,
            access_token,
            Some(client_token),
            profile,
            user_properties_json,
        )));
    }

    let profiles = parsed
        .available_profiles
        .unwrap_or_default()
        .into_iter()
        .map(|profile| YggdrasilProfileChoice {
            id: profile.id,
            name: profile.name,
        })
        .collect::<Vec<_>>();

    if profiles.is_empty() {
        return Err(simple_error("第三方服务器没有返回可用角色。"));
    }

    Ok(YggdrasilLoginResult::Pending(YggdrasilPendingLogin {
        server_url,
        username: username.to_string(),
        access_token,
        client_token,
        profiles,
    }))
}

pub fn complete_yggdrasil_login(
    pending: &YggdrasilPendingLogin,
    profile_index: usize,
) -> Result<AuthAccount, AuthError> {
    let profile = pending
        .profiles
        .get(profile_index)
        .ok_or_else(|| simple_error("选择的第三方角色不存在。"))?;

    let refresh_url = format!(
        "{}/authserver/refresh",
        pending.server_url.trim_end_matches('/')
    );

    let body = json!({
        "accessToken": pending.access_token,
        "clientToken": pending.client_token,
        "requestUser": true,
        "selectedProfile": {
            "id": profile.id,
            "name": profile.name
        }
    });

    let client = http_client()?;
    let response = client.post(&refresh_url).json(&body).send()?;
    let status = response.status();
    let text = response.text()?;

    let parsed: YggdrasilAuthResponse = serde_json::from_str(&text).map_err(|err| {
        simple_error(format!(
            "第三方服务器 refresh 响应不是有效 Yggdrasil JSON。\n\nHTTP: {status}\nURL: {refresh_url}\n\n{err}\n\n{text}"
        ))
    })?;

    if !status.is_success() {
        let message = parsed
            .error_message
            .or(parsed.error)
            .unwrap_or_else(|| text.clone());

        return Err(simple_error(format!(
            "第三方服务器选择角色失败。\n\nHTTP: {status}\nURL: {refresh_url}\n\n{message}"
        )));
    }

    if let Some(error) = parsed.error {
        let message = parsed.error_message.unwrap_or_default();
        return Err(simple_error(format!("第三方服务器选择角色失败：{error}\n{message}")));
    }

    let user_properties_json = yggdrasil_user_properties_json(parsed.user.as_ref());

    let selected = parsed
        .selected_profile
        .ok_or_else(|| simple_error("第三方服务器 refresh 没有返回 selectedProfile。"))?;

    if selected.id != profile.id {
        return Err(simple_error(format!(
            "第三方服务器选择角色后返回了不同 UUID。\n期望: {}\n实际: {}",
            profile.id, selected.id
        )));
    }

    let access_token = parsed
        .access_token
        .ok_or_else(|| simple_error("第三方服务器 refresh 没有返回 accessToken。"))?;

    Ok(yggdrasil_account_from_profile(
        &pending.server_url,
        &pending.username,
        access_token,
        Some(pending.client_token.clone()),
        selected,
        user_properties_json,
    ))
}


fn yggdrasil_user_properties_json(user: Option<&serde_json::Value>) -> Option<String> {
    let user = user?;
    let properties = user.get("properties")?;

    let mut out = serde_json::Map::new();

    if let Some(array) = properties.as_array() {
        for property in array {
            let Some(name) = property.get("name").and_then(|value| value.as_str()) else {
                continue;
            };

            let Some(value) = property.get("value").and_then(|value| value.as_str()) else {
                continue;
            };

            out.insert(
                name.to_string(),
                serde_json::Value::Array(vec![serde_json::Value::String(value.to_string())]),
            );
        }
    } else if let Some(object) = properties.as_object() {
        for (name, value) in object {
            if let Some(value) = value.as_str() {
                out.insert(
                    name.clone(),
                    serde_json::Value::Array(vec![serde_json::Value::String(value.to_string())]),
                );
            } else {
                out.insert(name.clone(), value.clone());
            }
        }
    }

    if out.is_empty() {
        None
    } else {
        Some(serde_json::Value::Object(out).to_string())
    }
}

fn yggdrasil_account_from_profile(
    server_url: &str,
    login_username: &str,
    access_token: String,
    client_token: Option<String>,
    profile: YggdrasilProfile,
    user_properties_json: Option<String>,
) -> AuthAccount {
    AuthAccount {
        kind: "yggdrasil".to_string(),
        username: profile.name,
        uuid: profile.id,
        access_token,
        refresh_token: None,
        client_token,
        user_properties_json,
        server_url: Some(server_url.to_string()),
        note: Some(format!("第三方登录：{login_username}")),
    }
}



pub fn login_microsoft_browser(client_id: &str) -> Result<AuthAccount, AuthError> {
    let client_id = normalize_client_id(client_id)?;

    let listener = TcpListener::bind(("127.0.0.1", 0))?;
    let port = listener.local_addr()?.port();
    let redirect_uri = format!("http://127.0.0.1:{port}/callback");

    let state = Uuid::new_v4().to_string();
    let code_verifier = create_pkce_verifier();
    let code_challenge = create_pkce_challenge(&code_verifier);

    let authorize_url = format!(
        "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id={}&response_type=code&redirect_uri={}&scope={}&prompt=select_account&state={}&code_challenge={}&code_challenge_method=S256",
        url_encode(&client_id),
        url_encode(&redirect_uri),
        url_encode("XboxLive.signin offline_access"),
        url_encode(&state),
        url_encode(&code_challenge),
    );

    open_browser(&authorize_url)?;

    let code = wait_for_oauth_callback(listener, &state)?;
    let token = exchange_microsoft_code(&client_id, &redirect_uri, &code, &code_verifier)?;

    authenticate_minecraft_with_live_token(token.access_token, token.refresh_token)
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
        let same_server = account.server_url.as_deref().unwrap_or("")
            == server_url.unwrap_or("");

        !(account.kind == kind && account.uuid == uuid && same_server)
    });

    if accounts.len() == before {
        return Err(simple_error("没有找到要删除的账户。"));
    }

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(&path, serde_json::to_string_pretty(&accounts)?)?;

    let removed_identifier = format!(
        "{}|{}|{}",
        kind,
        server_url.unwrap_or(""),
        uuid
    );

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

fn exchange_microsoft_code(
    client_id: &str,
    redirect_uri: &str,
    code: &str,
    code_verifier: &str,
) -> Result<MicrosoftTokenResponse, AuthError> {
    let response = http_client()?
        .post("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id),
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", redirect_uri),
            ("scope", "XboxLive.signin offline_access"),
            ("code_verifier", code_verifier),
        ])
        .send()?;

    let status = response.status();
    let text = response.text()?;

    let parsed: MicrosoftTokenResponse = serde_json::from_str(&text).map_err(|err| {
        simple_error(format!(
            "微软 token 响应不是有效 JSON。\n\nHTTP: {status}\n\n{err}\n\n{text}"
        ))
    })?;

    if !status.is_success() || parsed.error.is_some() {
        return Err(simple_error(format!(
            "微软 OAuth 换取 token 失败。\n\nHTTP: {status}\n错误: {}\n{}",
            parsed.error.unwrap_or_else(|| "unknown".to_string()),
            parsed.error_description.unwrap_or_default()
        )));
    }

    if parsed.access_token.is_none() {
        return Err(simple_error("微软 OAuth 响应缺少 access_token。"));
    }

    Ok(parsed)
}

fn authenticate_minecraft_with_live_token(
    live_access_token: Option<String>,
    live_refresh_token: Option<String>,
) -> Result<AuthAccount, AuthError> {
    let live_access_token =
        live_access_token.ok_or_else(|| simple_error("微软 OAuth 没有返回 access_token。"))?;

    let client = http_client()?;

    let xbox: XboxAuthResponse = client
        .post("https://user.auth.xboxlive.com/user/authenticate")
        .json(&json!({
            "Properties": {
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": format!("d={live_access_token}")
            },
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT"
        }))
        .send()?
        .json()?;

    let xbox_token = xbox.token.clone().ok_or_else(|| {
        simple_error(format!(
            "Xbox Live 登录失败。XErr={:?}, Message={:?}",
            xbox.xerr, xbox.message
        ))
    })?;

    let uhs = extract_uhs(&xbox)?;

    let xsts: XboxAuthResponse = client
        .post("https://xsts.auth.xboxlive.com/xsts/authorize")
        .json(&json!({
            "Properties": {
                "SandboxId": "RETAIL",
                "UserTokens": [xbox_token]
            },
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT"
        }))
        .send()?
        .json()?;

    let xsts_token = xsts.token.clone().ok_or_else(|| {
        simple_error(format!(
            "XSTS 授权失败。XErr={:?}, Message={:?}",
            xsts.xerr, xsts.message
        ))
    })?;

    let xsts_uhs = extract_uhs(&xsts)?;

    if xsts_uhs != uhs {
        return Err(simple_error("Xbox UHS 不一致，微软登录响应异常。"));
    }

    let minecraft: MinecraftLoginResponse = client
        .post("https://api.minecraftservices.com/authentication/login_with_xbox")
        .json(&json!({
            "identityToken": format!("XBL3.0 x={uhs};{xsts_token}")
        }))
        .send()?
        .error_for_status()?
        .json()?;

    let profile: MinecraftProfileResponse = client
        .get("https://api.minecraftservices.com/minecraft/profile")
        .bearer_auth(&minecraft.access_token)
        .send()?
        .error_for_status()?
        .json()?;

    Ok(AuthAccount {
        kind: "microsoft".to_string(),
        username: profile.name,
        uuid: profile.id,
        access_token: minecraft.access_token,
        refresh_token: live_refresh_token,
        client_token: None,
        user_properties_json: None,
        server_url: None,
        note: Some("Microsoft 浏览器登录。".to_string()),
    })
}

fn wait_for_oauth_callback(listener: TcpListener, expected_state: &str) -> Result<String, AuthError> {
    listener.set_nonblocking(false)?;

    let (mut stream, _) = listener.accept()?;
    stream.set_read_timeout(Some(Duration::from_secs(300)))?;

    let mut buffer = [0_u8; 8192];
    let n = stream.read(&mut buffer)?;
    let request = String::from_utf8_lossy(&buffer[..n]);

    let first_line = request.lines().next().unwrap_or_default();
    let target = first_line.split_whitespace().nth(1).unwrap_or_default();
    let query = target
        .split_once('?')
        .map(|(_, query)| query)
        .unwrap_or_default();

    let params = parse_query(query);

    if let Some(error) = params.get("error") {
        let response_html = format!(
            "<html><body><h2>登录失败</h2><p>{}</p><p>可以关闭此页面。</p></body></html>",
            html_escape(error)
        );

        write_http_response(&mut stream, &response_html)?;

        return Err(simple_error(format!(
            "微软浏览器授权失败：{}\n{}",
            error,
            params.get("error_description").cloned().unwrap_or_default()
        )));
    }

    let state = params
        .get("state")
        .ok_or_else(|| simple_error("微软回调缺少 state。"))?;

    if state != expected_state {
        write_http_response(
            &mut stream,
            "<html><body><h2>登录失败</h2><p>state 不匹配，可以关闭此页面。</p></body></html>",
        )?;

        return Err(simple_error("微软回调 state 不匹配。"));
    }

    let code = params
        .get("code")
        .ok_or_else(|| simple_error("微软回调缺少 code。"))?
        .to_string();

    write_http_response(
        &mut stream,
        "<html><body><h2>登录完成</h2><p>已经收到 Microsoft 授权，可以回到启动器。</p><p>此页面可以关闭。</p></body></html>",
    )?;

    Ok(code)
}

fn write_http_response(stream: &mut std::net::TcpStream, html: &str) -> Result<(), AuthError> {
    let body = html.as_bytes();

    write!(
        stream,
        "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
        body.len()
    )?;

    stream.write_all(body)?;

    Ok(())
}

fn open_browser(url: &str) -> Result<(), AuthError> {
    let mut command = match std::env::consts::OS {
        "linux" => {
            let mut command = Command::new("xdg-open");
            command.arg(url);
            command
        }
        "macos" => {
            let mut command = Command::new("open");
            command.arg(url);
            command
        }
        "windows" => {
            let mut command = Command::new("cmd");
            command.args(["/C", "start", "", url]);
            command
        }
        other => return Err(simple_error(format!("暂不支持打开浏览器的系统：{other}"))),
    };

    command.spawn()?;

    Ok(())
}

fn extract_uhs(response: &XboxAuthResponse) -> Result<String, AuthError> {
    response
        .display_claims
        .as_ref()
        .and_then(|claims| claims.xui.first())
        .and_then(|xui| xui.get("uhs"))
        .cloned()
        .ok_or_else(|| simple_error("Xbox 登录响应缺少 uhs。"))
}

fn normalize_client_id(client_id: &str) -> Result<String, AuthError> {
    let client_id = client_id.trim();

    if client_id.is_empty() {
        return Err(simple_error("Microsoft Client ID 不能为空。"));
    }

    Ok(client_id.to_string())
}

fn normalize_server_url(server_url: &str) -> Result<String, AuthError> {
    let mut server_url = server_url.trim().trim_end_matches('/').to_string();

    if server_url.is_empty() {
        return Err(simple_error("第三方服务器地址不能为空。可以直接填 littleskin.cn，或点击 LittleSkin 快捷按钮。"));
    }

    if server_url.contains("example.com") {
        return Err(simple_error("第三方服务器地址仍然包含 example.com。请清空后重新填写，例如：https://littleskin.cn/api/yggdrasil"));
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
        return Err(simple_error("第三方服务器地址必须以 http:// 或 https:// 开头。"));
    }

    Ok(server_url)
}

fn is_valid_minecraft_name(value: &str) -> bool {
    let len = value.chars().count();

    if !(3..=16).contains(&len) {
        return false;
    }

    value
        .chars()
        .all(|ch| ch.is_ascii_alphanumeric() || ch == '_')
}

fn create_pkce_verifier() -> String {
    format!(
        "{}{}{}",
        Uuid::new_v4().simple(),
        Uuid::new_v4().simple(),
        Uuid::new_v4().simple()
    )
}

fn create_pkce_challenge(verifier: &str) -> String {
    let digest = Sha256::digest(verifier.as_bytes());
    URL_SAFE_NO_PAD.encode(digest)
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

fn home_dir() -> Result<PathBuf, AuthError> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
}

fn http_client() -> Result<Client, AuthError> {
    Ok(Client::builder()
        .user_agent("mc-launcher/0.1 auth")
        .build()?)
}

fn parse_query(query: &str) -> HashMap<String, String> {
    let mut out = HashMap::new();

    for pair in query.split('&') {
        if pair.is_empty() {
            continue;
        }

        let (key, value) = pair.split_once('=').unwrap_or((pair, ""));
        out.insert(percent_decode(key), percent_decode(value));
    }

    out
}

fn percent_decode(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;

    while i < bytes.len() {
        match bytes[i] {
            b'+' => {
                out.push(b' ');
                i += 1;
            }
            b'%' if i + 2 < bytes.len() => {
                let hi = from_hex(bytes[i + 1]);
                let lo = from_hex(bytes[i + 2]);

                if let (Some(hi), Some(lo)) = (hi, lo) {
                    out.push((hi << 4) | lo);
                    i += 3;
                } else {
                    out.push(bytes[i]);
                    i += 1;
                }
            }
            b => {
                out.push(b);
                i += 1;
            }
        }
    }

    String::from_utf8_lossy(&out).to_string()
}

fn from_hex(value: u8) -> Option<u8> {
    match value {
        b'0'..=b'9' => Some(value - b'0'),
        b'a'..=b'f' => Some(value - b'a' + 10),
        b'A'..=b'F' => Some(value - b'A' + 10),
        _ => None,
    }
}

fn url_encode(value: &str) -> String {
    let mut out = String::new();

    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.' | b'_' | b'~') {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }

    out
}

fn html_escape(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

fn simple_error(message: impl Into<String>) -> AuthError {
    Box::new(io::Error::other(message.into()))
}
