use super::{AuthError, simple_error};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::process::Command;
use std::time::Duration;
use uuid::Uuid;

pub(crate) fn wait_for_oauth_callback(
    listener: TcpListener,
    expected_state: &str,
) -> Result<String, AuthError> {
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

pub(crate) fn open_browser(url: &str) -> Result<(), AuthError> {
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

pub(crate) fn create_pkce_verifier() -> String {
    format!(
        "{}{}{}",
        Uuid::new_v4().simple(),
        Uuid::new_v4().simple(),
        Uuid::new_v4().simple()
    )
}

pub(crate) fn create_pkce_challenge(verifier: &str) -> String {
    let digest = Sha256::digest(verifier.as_bytes());
    URL_SAFE_NO_PAD.encode(digest)
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

pub(crate) fn url_encode(value: &str) -> String {
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
