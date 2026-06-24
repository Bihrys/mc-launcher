use super::{AuthAccount, AuthError, http_client, normalize_server_url, simple_error};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

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

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum YggdrasilLoginResult {
    Account(AuthAccount),
    Pending(YggdrasilPendingLogin),
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
    let auth_url = format!(
        "{}/authserver/authenticate",
        server_url.trim_end_matches('/')
    );

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
        return Err(simple_error(format!(
            "第三方服务器登录失败：{error}\n{message}"
        )));
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
        return Ok(YggdrasilLoginResult::Account(
            yggdrasil_account_from_profile(
                &server_url,
                username,
                access_token,
                Some(client_token),
                profile,
                user_properties_json,
            ),
        ));
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
        return Err(simple_error(format!(
            "第三方服务器选择角色失败：{error}\n{message}"
        )));
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
        client_id: None,
        skin_path: None,
        skin_model: None,
        storage_scope: Some("global".to_string()),
        note: Some(format!("第三方登录：{login_username}")),
    }
}

pub(crate) fn refresh_yggdrasil_account(account: &AuthAccount) -> Result<AuthAccount, AuthError> {
    let server_url = account
        .server_url
        .as_deref()
        .ok_or_else(|| simple_error("第三方账户缺少服务器地址。"))?;

    let client_token = account
        .client_token
        .clone()
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let refresh_url = format!("{}/authserver/refresh", server_url.trim_end_matches('/'));

    let body = json!({
        "accessToken": account.access_token,
        "clientToken": client_token,
        "requestUser": true,
        "selectedProfile": {
            "id": account.uuid,
            "name": account.username
        }
    });

    let response = http_client()?.post(&refresh_url).json(&body).send()?;
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
            "第三方服务器刷新失败。\n\nHTTP: {status}\nURL: {refresh_url}\n\n{message}"
        )));
    }

    let user_properties_json = yggdrasil_user_properties_json(parsed.user.as_ref());
    let selected = parsed
        .selected_profile
        .ok_or_else(|| simple_error("第三方服务器 refresh 没有返回 selectedProfile。"))?;

    let access_token = parsed
        .access_token
        .ok_or_else(|| simple_error("第三方服务器 refresh 没有返回 accessToken。"))?;

    let mut refreshed = yggdrasil_account_from_profile(
        server_url,
        &account.username,
        access_token,
        parsed.client_token.or(account.client_token.clone()),
        selected,
        user_properties_json,
    );

    refreshed.storage_scope = account.storage_scope.clone();
    refreshed.skin_path = account.skin_path.clone();
    refreshed.skin_model = account.skin_model.clone();

    Ok(refreshed)
}
