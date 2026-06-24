use super::oauth::{
    create_pkce_challenge, create_pkce_verifier, open_browser, url_encode, wait_for_oauth_callback,
};
use super::{AuthAccount, AuthError, http_client, simple_error};
use serde::Deserialize;
use serde_json::json;
use std::collections::HashMap;
use std::net::TcpListener;
use uuid::Uuid;

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

    let mut account =
        authenticate_minecraft_with_live_token(token.access_token, token.refresh_token)?;
    account.client_id = Some(client_id);
    Ok(account)
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
        client_id: None,
        skin_path: None,
        skin_model: None,
        storage_scope: Some("global".to_string()),
        note: Some("Microsoft 浏览器登录。".to_string()),
    })
}

pub(crate) fn refresh_microsoft_account(account: &AuthAccount) -> Result<AuthAccount, AuthError> {
    let client_id = account.client_id.as_deref().ok_or_else(|| {
        simple_error("Microsoft 账户缺少 client_id。需要重新通过浏览器登录一次。")
    })?;

    let refresh_token = account
        .refresh_token
        .as_deref()
        .ok_or_else(|| simple_error("Microsoft 账户没有 refresh_token。需要重新登录。"))?;

    let token = exchange_microsoft_refresh_token(client_id, refresh_token)?;
    let mut refreshed =
        authenticate_minecraft_with_live_token(token.access_token, token.refresh_token)?;

    refreshed.client_id = Some(client_id.to_string());
    refreshed.storage_scope = account.storage_scope.clone();
    refreshed.skin_path = account.skin_path.clone();
    refreshed.skin_model = account.skin_model.clone();

    Ok(refreshed)
}

fn exchange_microsoft_refresh_token(
    client_id: &str,
    refresh_token: &str,
) -> Result<MicrosoftTokenResponse, AuthError> {
    let response = http_client()?
        .post("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id),
            ("grant_type", "refresh_token"),
            ("refresh_token", refresh_token),
            ("scope", "XboxLive.signin offline_access"),
        ])
        .send()?;

    let status = response.status();
    let text = response.text()?;

    let parsed: MicrosoftTokenResponse = serde_json::from_str(&text).map_err(|err| {
        simple_error(format!(
            "微软 refresh token 响应不是有效 JSON。\n\nHTTP: {status}\n\n{err}\n\n{text}"
        ))
    })?;

    if !status.is_success() || parsed.error.is_some() {
        return Err(simple_error(format!(
            "微软 refresh token 刷新失败。\n\nHTTP: {status}\n错误: {}\n{}",
            parsed.error.unwrap_or_else(|| "unknown".to_string()),
            parsed.error_description.unwrap_or_default()
        )));
    }

    if parsed.access_token.is_none() {
        return Err(simple_error("微软 refresh token 响应缺少 access_token。"));
    }

    Ok(parsed)
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
