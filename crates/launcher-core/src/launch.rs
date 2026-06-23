use crate::auth::{AuthAccount, load_accounts, selected_account};
use crate::java::detect_java_runtimes;
use base64::Engine as _;
use base64::engine::general_purpose::STANDARD;
use reqwest::blocking::Client;
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::Duration;

pub type LaunchError = Box<dyn std::error::Error + Send + Sync + 'static>;

#[derive(Debug, Clone)]
pub struct LaunchOptions {
    pub version_id: String,
    pub account_uuid: Option<String>,
    pub java_path: Option<PathBuf>,
    pub game_dir: Option<PathBuf>,
    pub min_memory_mb: Option<u32>,
    pub max_memory_mb: Option<u32>,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub fullscreen: bool,
    pub dry_run: bool,
}

impl Default for LaunchOptions {
    fn default() -> Self {
        Self {
            version_id: String::new(),
            account_uuid: None,
            java_path: None,
            game_dir: None,
            min_memory_mb: None,
            max_memory_mb: Some(2048),
            width: Some(854),
            height: Some(480),
            fullscreen: false,
            dry_run: false,
        }
    }
}

#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchResult {
    pub version_id: String,
    pub game_dir: PathBuf,
    pub minecraft_root: PathBuf,
    pub java_path: PathBuf,
    pub natives_dir: PathBuf,
    pub classpath_entries: usize,
    pub command: Vec<String>,
    pub script_path: PathBuf,
    pub pid: Option<u32>,
    pub message: String,
}

#[derive(Debug, Clone)]
struct ResolvedVersion {
    id: String,
    version_type: String,
    main_class: String,
    minecraft_arguments: Option<String>,
    arguments: Option<Value>,
    libraries: Vec<Value>,
    asset_index: Option<Value>,
    jar_version: String,
    json: Value,
}

pub fn launch_game(options: LaunchOptions) -> Result<LaunchResult, LaunchError> {
    let root = minecraft_root()?;
    let version_id = options.version_id.trim();

    if version_id.is_empty() {
        return Err(simple_error("还没有选择要启动的版本。"));
    }

    let resolved = resolve_version(&root, version_id)?;
    let account = choose_account(options.account_uuid.as_deref())?;
    let java_path = choose_java(options.java_path.as_deref(), required_java_major(&resolved));
    let game_dir = options.game_dir.clone().unwrap_or_else(|| root.clone());
    let natives_dir = root.join("versions").join(&resolved.id).join("natives");

    fs::create_dir_all(&game_dir)?;
    fs::create_dir_all(&natives_dir)?;
    fs::create_dir_all(root.join("logs"))?;
    fs::create_dir_all(root.join("resourcepacks"))?;
    fs::create_dir_all(root.join("saves"))?;
    fs::create_dir_all(root.join("mods"))?;

    extract_natives(&root, &resolved, &natives_dir)?;

    let classpath = build_classpath(&root, &resolved)?;
    let command = build_launch_command(
        &root,
        &game_dir,
        &natives_dir,
        &classpath,
        &resolved,
        &account,
        &java_path,
        &options,
    )?;

    let script_path = write_launch_script(&root, &resolved.id, &command, &game_dir)?;

    let pid = if options.dry_run {
        None
    } else {
        let child = Command::new(&command[0])
            .args(&command[1..])
            .current_dir(&game_dir)
            .env("APPDATA", root.parent().unwrap_or(root.as_path()))
            .env("INST_NAME", &resolved.id)
            .env("INST_ID", &resolved.id)
            .env("INST_DIR", root.join("versions").join(&resolved.id))
            .env("INST_MC_DIR", &game_dir)
            .env("INST_JAVA", &java_path)
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .spawn()?;

        Some(child.id())
    };

    Ok(LaunchResult {
        version_id: resolved.id,
        game_dir,
        minecraft_root: root,
        java_path,
        natives_dir,
        classpath_entries: classpath.len(),
        command,
        script_path,
        pid,
        message: "启动命令已生成，游戏进程已启动。".to_string(),
    })
}

pub fn generate_launch_command_json(version_id: &str) -> Result<String, LaunchError> {
    let options = LaunchOptions {
        version_id: version_id.to_string(),
        dry_run: true,
        ..LaunchOptions::default()
    };

    Ok(serde_json::to_string_pretty(&launch_game(options)?)?)
}

fn resolve_version(root: &Path, version_id: &str) -> Result<ResolvedVersion, LaunchError> {
    let mut seen = HashSet::new();
    resolve_version_inner(root, version_id, &mut seen)
}

fn resolve_version_inner(
    root: &Path,
    version_id: &str,
    seen: &mut HashSet<String>,
) -> Result<ResolvedVersion, LaunchError> {
    if !seen.insert(version_id.to_string()) {
        return Err(simple_error(format!("版本继承循环：{version_id}")));
    }

    let json_path = root
        .join("versions")
        .join(version_id)
        .join(format!("{version_id}.json"));

    let text = fs::read_to_string(&json_path).map_err(|err| {
        simple_error(format!(
            "读取版本 JSON 失败：{}\n{}",
            json_path.display(),
            err
        ))
    })?;

    let json: Value = serde_json::from_str(&text)?;

    let parent = json
        .get("inheritsFrom")
        .and_then(Value::as_str)
        .map(|parent_id| resolve_version_inner(root, parent_id, seen))
        .transpose()?;

    let id = json
        .get("id")
        .and_then(Value::as_str)
        .unwrap_or(version_id)
        .to_string();

    let version_type = json
        .get("type")
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .or_else(|| parent.as_ref().map(|value| value.version_type.clone()))
        .unwrap_or_else(|| "release".to_string());

    let main_class = json
        .get("mainClass")
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .or_else(|| parent.as_ref().map(|value| value.main_class.clone()))
        .ok_or_else(|| simple_error(format!("版本 {version_id} 没有 mainClass。")))?;

    let minecraft_arguments = json
        .get("minecraftArguments")
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .or_else(|| {
            parent
                .as_ref()
                .and_then(|value| value.minecraft_arguments.clone())
        });

    let arguments = merge_arguments(
        parent.as_ref().and_then(|value| value.arguments.clone()),
        json.get("arguments").cloned(),
    );

    let mut libraries = parent
        .as_ref()
        .map(|value| value.libraries.clone())
        .unwrap_or_default();

    if let Some(child_libraries) = json.get("libraries").and_then(Value::as_array) {
        libraries.extend(child_libraries.iter().cloned());
    }

    let asset_index = json
        .get("assetIndex")
        .cloned()
        .or_else(|| parent.as_ref().and_then(|value| value.asset_index.clone()));

    let jar_version = if json
        .get("downloads")
        .and_then(|value| value.get("client"))
        .is_some()
        || root
            .join("versions")
            .join(&id)
            .join(format!("{id}.jar"))
            .is_file()
    {
        id.clone()
    } else {
        parent
            .as_ref()
            .map(|value| value.jar_version.clone())
            .unwrap_or_else(|| id.clone())
    };

    Ok(ResolvedVersion {
        id,
        version_type,
        main_class,
        minecraft_arguments,
        arguments,
        libraries,
        asset_index,
        jar_version,
        json,
    })
}

fn merge_arguments(parent: Option<Value>, child: Option<Value>) -> Option<Value> {
    match (parent, child) {
        (None, None) => None,
        (Some(value), None) | (None, Some(value)) => Some(value),
        (Some(parent), Some(child)) => {
            let mut out = serde_json::Map::new();

            for key in ["jvm", "game"] {
                let mut values = Vec::new();

                if let Some(arr) = parent.get(key).and_then(Value::as_array) {
                    values.extend(arr.iter().cloned());
                }

                if let Some(arr) = child.get(key).and_then(Value::as_array) {
                    values.extend(arr.iter().cloned());
                }

                if !values.is_empty() {
                    out.insert(key.to_string(), Value::Array(values));
                }
            }

            Some(Value::Object(out))
        }
    }
}

fn build_launch_command(
    root: &Path,
    game_dir: &Path,
    natives_dir: &Path,
    classpath: &[PathBuf],
    version: &ResolvedVersion,
    account: &AuthAccount,
    java_path: &Path,
    options: &LaunchOptions,
) -> Result<Vec<String>, LaunchError> {
    let classpath_os: OsString = std::env::join_paths(classpath)?;
    let classpath_joined = classpath_os.to_string_lossy().to_string();

    let assets_root = root.join("assets");
    let asset_id = version
        .asset_index
        .as_ref()
        .and_then(|value| value.get("id"))
        .and_then(Value::as_str)
        .unwrap_or("legacy");

    let width = options.width.unwrap_or(854).to_string();
    let height = options.height.unwrap_or(480).to_string();
    let compact_uuid = account.uuid.replace('-', "");
    let access_token = if account.access_token.trim().is_empty() {
        "0"
    } else {
        account.access_token.as_str()
    };

    let mut vars = HashMap::new();
    vars.insert("auth_player_name", account.username.clone());
    vars.insert("auth_session", access_token.to_string());
    vars.insert("auth_access_token", access_token.to_string());
    vars.insert("auth_uuid", compact_uuid);
    vars.insert("version_name", version.id.clone());
    vars.insert("profile_name", "Minecraft".to_string());
    vars.insert("version_type", version.version_type.clone());
    vars.insert("game_directory", abs(game_dir));
    vars.insert("user_type", user_type(account));
    vars.insert("assets_index_name", asset_id.to_string());
    vars.insert(
        "user_properties",
        account
            .user_properties_json
            .clone()
            .unwrap_or_else(|| "{}".to_string()),
    );
    vars.insert("resolution_width", width.clone());
    vars.insert("resolution_height", height.clone());
    vars.insert("library_directory", abs(&root.join("libraries")));
    vars.insert("libraries_directory", abs(&root.join("libraries")));
    vars.insert(
        "classpath_separator",
        if cfg!(windows) { ";" } else { ":" }.to_string(),
    );
    vars.insert("classpath", classpath_joined);
    vars.insert("game_assets", abs(&assets_root));
    vars.insert("assets_root", abs(&assets_root));
    vars.insert("natives_directory", abs(natives_dir));
    vars.insert(
        "primary_jar",
        abs(&version_jar_path(root, &version.jar_version)),
    );
    vars.insert("primary_jar_name", format!("{}.jar", version.jar_version));
    vars.insert("launcher_name", "mc-launcher".to_string());
    vars.insert("launcher_version", env!("CARGO_PKG_VERSION").to_string());

    let mut command = Vec::new();
    command.push(java_path.to_string_lossy().to_string());

    if let Some(min) = options.min_memory_mb {
        if min > 0 {
            command.push(format!("-Xms{min}m"));
        }
    }

    if let Some(max) = options.max_memory_mb {
        if max > 0 {
            command.push(format!("-Xmx{max}m"));
        }
    }

    command.push("-Dfile.encoding=UTF-8".to_string());
    command.push("-Dsun.stdout.encoding=UTF-8".to_string());
    command.push("-Dsun.stderr.encoding=UTF-8".to_string());
    command.push("-Djava.rmi.server.useCodebaseOnly=true".to_string());
    command.push("-Dcom.sun.jndi.rmi.object.trustURLCodebase=false".to_string());
    command.push("-Dcom.sun.jndi.cosnaming.object.trustURLCodebase=false".to_string());
    command.push("-Dlog4j2.formatMsgNoLookups=true".to_string());
    command.push("-Dfml.ignoreInvalidMinecraftCertificates=true".to_string());
    command.push("-Dfml.ignorePatchDiscrepancies=true".to_string());

    // HMCL: AuthlibInjectorAccount.getLaunchArguments()
    // 外置登录必须在 Minecraft mainClass 前注入 authlib-injector。
    command.extend(authlib_injector_jvm_args(root, account)?);

    let jvm_args = version
        .arguments
        .as_ref()
        .and_then(|value| value.get("jvm"))
        .and_then(Value::as_array)
        .map(|args| parse_argument_array(args, &vars))
        .unwrap_or_else(|| default_jvm_args(&vars));

    command.extend(jvm_args);
    command.push(version.main_class.clone());

    if let Some(minecraft_arguments) = &version.minecraft_arguments {
        for token in tokenize(minecraft_arguments) {
            command.push(replace_vars(&token, &vars));
        }
    } else if let Some(args) = version
        .arguments
        .as_ref()
        .and_then(|value| value.get("game"))
        .and_then(Value::as_array)
    {
        command.extend(parse_argument_array(args, &vars));
    }

    if options.fullscreen {
        command.push("--fullscreen".to_string());
    }

    Ok(command.into_iter().filter(|arg| !arg.is_empty()).collect())
}

fn default_jvm_args(vars: &HashMap<&'static str, String>) -> Vec<String> {
    vec![
        replace_vars("-Djava.library.path=${natives_directory}", vars),
        replace_vars("-Dminecraft.launcher.brand=${launcher_name}", vars),
        replace_vars("-Dminecraft.launcher.version=${launcher_version}", vars),
        "-cp".to_string(),
        replace_vars("${classpath}", vars),
    ]
}

fn parse_argument_array(args: &[Value], vars: &HashMap<&'static str, String>) -> Vec<String> {
    let mut out = Vec::new();

    for arg in args {
        match arg {
            Value::String(value) => out.push(replace_vars(value, vars)),
            Value::Object(map) => {
                if let Some(rules) = map.get("rules").and_then(Value::as_array) {
                    if !rules_apply(rules) {
                        continue;
                    }
                }

                if let Some(value) = map.get("value") {
                    match value {
                        Value::String(value) => out.push(replace_vars(value, vars)),
                        Value::Array(values) => {
                            for value in values {
                                if let Some(value) = value.as_str() {
                                    out.push(replace_vars(value, vars));
                                }
                            }
                        }
                        _ => {}
                    }
                }
            }
            _ => {}
        }
    }

    out
}

fn rules_apply(rules: &[Value]) -> bool {
    let mut allowed = false;

    for rule in rules {
        let Some(action) = rule.get("action").and_then(Value::as_str) else {
            continue;
        };

        if rule_matches(rule) {
            allowed = action == "allow";
        }
    }

    allowed
}

fn rule_matches(rule: &Value) -> bool {
    if let Some(os) = rule.get("os") {
        if let Some(name) = os.get("name").and_then(Value::as_str) {
            if name != os_name() {
                return false;
            }
        }

        if let Some(arch) = os.get("arch").and_then(Value::as_str) {
            let current = if cfg!(target_arch = "x86_64") {
                "x86_64"
            } else {
                std::env::consts::ARCH
            };

            if arch != current {
                return false;
            }
        }
    }

    if let Some(features) = rule.get("features").and_then(Value::as_object) {
        for (key, expected) in features {
            let expected = expected.as_bool().unwrap_or(false);
            let actual = match key.as_str() {
                "has_custom_resolution" => true,
                _ => false,
            };

            if expected != actual {
                return false;
            }
        }
    }

    true
}

fn build_classpath(root: &Path, version: &ResolvedVersion) -> Result<Vec<PathBuf>, LaunchError> {
    let mut out = Vec::new();
    let mut seen = HashSet::new();

    for lib in &version.libraries {
        if !library_rules_apply(lib) {
            continue;
        }

        if native_classifier_key(lib).is_some() {
            continue;
        }

        if let Some(path) = lib
            .get("downloads")
            .and_then(|value| value.get("artifact"))
            .and_then(|value| value.get("path"))
            .and_then(Value::as_str)
        {
            let path = root.join("libraries").join(path);

            if path.is_file() && seen.insert(path.clone()) {
                out.push(path);
            }
        } else if let Some(name) = lib.get("name").and_then(Value::as_str) {
            if let Some(path) = maven_path(name) {
                let path = root.join("libraries").join(path);

                if path.is_file() && seen.insert(path.clone()) {
                    out.push(path);
                }
            }
        }
    }

    let jar = version_jar_path(root, &version.jar_version);

    if !jar.is_file() {
        return Err(simple_error(format!(
            "客户端 jar 不存在：{}。请先在下载页安装该版本。",
            jar.display()
        )));
    }

    out.push(jar);

    Ok(out)
}

fn extract_natives(
    root: &Path,
    version: &ResolvedVersion,
    natives_dir: &Path,
) -> Result<(), LaunchError> {
    if natives_dir.exists() {
        fs::remove_dir_all(natives_dir)?;
    }

    fs::create_dir_all(natives_dir)?;

    for lib in &version.libraries {
        if !library_rules_apply(lib) {
            continue;
        }

        let Some(classifier_key) = native_classifier_key(lib) else {
            continue;
        };

        let Some(native_path) = lib
            .get("downloads")
            .and_then(|value| value.get("classifiers"))
            .and_then(|value| value.get(&classifier_key))
            .and_then(|value| value.get("path"))
            .and_then(Value::as_str)
        else {
            continue;
        };

        let jar = root.join("libraries").join(native_path);

        if jar.is_file() {
            extract_native_jar_with_unzip(&jar, natives_dir)?;
        }
    }

    let meta_inf = natives_dir.join("META-INF");

    if meta_inf.exists() {
        let _ = fs::remove_dir_all(meta_inf);
    }

    Ok(())
}

fn extract_native_jar_with_unzip(jar: &Path, dest: &Path) -> Result<(), LaunchError> {
    let status = Command::new("unzip")
        .arg("-q")
        .arg("-o")
        .arg(jar)
        .arg("-d")
        .arg(dest)
        .status();

    match status {
        Ok(status) if status.success() => Ok(()),
        Ok(status) => Err(simple_error(format!(
            "解压 native 失败：{}，退出码：{}。请确认系统安装了 unzip。",
            jar.display(),
            status
        ))),
        Err(err) => Err(simple_error(format!(
            "无法调用 unzip 解压 native：{}\n{}\nArch 可执行：sudo pacman -S unzip",
            jar.display(),
            err
        ))),
    }
}

fn native_classifier_key(lib: &Value) -> Option<String> {
    let natives = lib.get("natives")?.as_object()?;
    let key = natives.get(os_name())?.as_str()?;

    Some(key.replace(
        "${arch}",
        if cfg!(target_pointer_width = "64") {
            "64"
        } else {
            "32"
        },
    ))
}

fn library_rules_apply(lib: &Value) -> bool {
    lib.get("rules")
        .and_then(Value::as_array)
        .map(|rules| rules_apply(rules))
        .unwrap_or(true)
}

fn version_jar_path(root: &Path, version_id: &str) -> PathBuf {
    root.join("versions")
        .join(version_id)
        .join(format!("{version_id}.jar"))
}

fn write_launch_script(
    root: &Path,
    version_id: &str,
    command: &[String],
    game_dir: &Path,
) -> Result<PathBuf, LaunchError> {
    let script_dir = root.join("launch-scripts");
    fs::create_dir_all(&script_dir)?;

    let script = script_dir.join(format!("launch-{version_id}.sh"));
    let mut text = String::new();

    text.push_str("#!/usr/bin/env bash\n");
    text.push_str("set -e\n");
    text.push_str(&format!("cd {}\n", shell_quote(&abs(game_dir))));

    for (index, arg) in command.iter().enumerate() {
        if index == 0 {
            text.push_str(&shell_quote(arg));
        } else {
            text.push(' ');
            text.push_str(&shell_quote(arg));
        }
    }

    text.push('\n');
    fs::write(&script, text)?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;

        let mut permissions = fs::metadata(&script)?.permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&script, permissions)?;
    }

    Ok(script)
}

fn choose_account(uuid: Option<&str>) -> Result<AuthAccount, LaunchError> {
    let accounts = load_accounts()?;

    if accounts.is_empty() {
        return Err(simple_error("没有可用账户。请先到账户管理添加或切换账户。"));
    }

    if let Some(uuid) = uuid {
        if let Some(account) = accounts.iter().find(|account| account.uuid == uuid) {
            return Ok(account.clone());
        }
    }

    // HMCL: 优先使用上次选择的账户，而不是账户列表第一个。
    if let Some(account) = selected_account()? {
        return Ok(account);
    }

    Ok(accounts[0].clone())
}

fn choose_java(configured: Option<&Path>, required_major: Option<u32>) -> PathBuf {
    if let Some(path) = configured {
        if path.is_file() {
            return path.to_path_buf();
        }
    }

    let mut runtimes = detect_java_runtimes();

    if let Some(required) = required_major {
        runtimes.sort_by_key(|runtime| runtime.major.unwrap_or(0));

        if let Some(runtime) = runtimes
            .iter()
            .find(|runtime| runtime.major.unwrap_or(0) >= required)
        {
            return runtime.executable.clone();
        }
    }

    if let Some(runtime) = runtimes.first() {
        return runtime.executable.clone();
    }

    PathBuf::from("java")
}

fn required_java_major(version: &ResolvedVersion) -> Option<u32> {
    version
        .json
        .get("javaVersion")
        .and_then(|value| value.get("majorVersion"))
        .and_then(Value::as_u64)
        .map(|value| value as u32)
}

fn user_type(account: &AuthAccount) -> String {
    match account.kind.as_str() {
        "microsoft" => "msa".to_string(),
        // HMCL 的 YggdrasilSession.toAuthInfo() 使用 USER_TYPE_MSA。
        "yggdrasil" => "msa".to_string(),
        _ => "legacy".to_string(),
    }
}

fn replace_vars(input: &str, vars: &HashMap<&'static str, String>) -> String {
    let mut out = input.to_string();

    for (key, value) in vars {
        out = out.replace(&format!("${{{key}}}"), value);
    }

    out
}

fn tokenize(input: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut current = String::new();
    let mut quoted = false;
    let mut escaped = false;

    for ch in input.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
            continue;
        }

        match ch {
            '\\' => escaped = true,
            '"' => quoted = !quoted,
            ch if ch.is_whitespace() && !quoted => {
                if !current.is_empty() {
                    out.push(std::mem::take(&mut current));
                }
            }
            _ => current.push(ch),
        }
    }

    if !current.is_empty() {
        out.push(current);
    }

    out
}

fn maven_path(descriptor: &str) -> Option<PathBuf> {
    let mut parts = descriptor.split(':').collect::<Vec<_>>();

    if parts.len() < 3 {
        return None;
    }

    let mut ext = "jar".to_string();

    if let Some(last) = parts.last_mut() {
        if let Some((before, after)) = last.split_once('@') {
            *last = before;
            ext = after.to_string();
        }
    }

    let group = parts[0].replace('.', "/");
    let artifact = parts[1];
    let version = parts[2];

    let file_name = if parts.len() >= 4 {
        let classifier = parts[3];
        format!("{artifact}-{version}-{classifier}.{ext}")
    } else {
        format!("{artifact}-{version}.{ext}")
    };

    Some(
        PathBuf::from(group)
            .join(artifact)
            .join(version)
            .join(file_name),
    )
}

fn authlib_injector_jvm_args(
    root: &Path,
    account: &AuthAccount,
) -> Result<Vec<String>, LaunchError> {
    if account.kind != "yggdrasil" {
        return Ok(Vec::new());
    }

    let server_url = account
        .server_url
        .as_deref()
        .ok_or_else(|| simple_error("第三方账户缺少 Yggdrasil 服务器地址。"))?;

    let server_url = server_url.trim_end_matches('/').to_string() + "/";
    let artifact = ensure_authlib_injector(root)?;
    let metadata = fetch_authlib_injector_metadata(&server_url)?;

    Ok(vec![
        format!("-javaagent:{}={}", artifact.to_string_lossy(), server_url),
        "-Dauthlibinjector.side=client".to_string(),
        format!(
            "-Dauthlibinjector.yggdrasil.prefetched={}",
            STANDARD.encode(metadata.as_bytes())
        ),
    ])
}

fn ensure_authlib_injector(root: &Path) -> Result<PathBuf, LaunchError> {
    let dir = root
        .join("libraries")
        .join("org")
        .join("glavo")
        .join("hmcl")
        .join("authlib-injector");

    fs::create_dir_all(&dir)?;

    if let Some(local) = find_local_authlib_injector(&dir)? {
        return Ok(local);
    }

    let latest = fetch_authlib_injector_latest()
        .unwrap_or_else(|_| AuthlibInjectorLatest {
            version: "1.2.7".to_string(),
            download_url: "https://repo1.maven.org/maven2/org/glavo/hmcl/authlib-injector/1.2.7/authlib-injector-1.2.7.jar".to_string(),
        });

    let jar = dir.join(format!("authlib-injector-{}.jar", latest.version));

    if jar.is_file() && is_probably_jar(&jar) {
        return Ok(jar);
    }

    let _ = fs::remove_file(&jar);
    download_authlib_injector(&latest.download_url, &jar)?;

    if !jar.is_file() || !is_probably_jar(&jar) {
        let _ = fs::remove_file(&jar);
        return Err(simple_error(format!(
            "authlib-injector 下载结果不是有效 jar：{}",
            jar.display()
        )));
    }

    Ok(jar)
}

#[derive(Debug, serde::Deserialize)]
struct AuthlibInjectorLatest {
    version: String,

    #[serde(rename = "download_url")]
    download_url: String,
}

fn fetch_authlib_injector_latest() -> Result<AuthlibInjectorLatest, LaunchError> {
    let client = http_client()?;
    let urls = [
        "https://authlib-injector.yushi.moe/artifact/latest.json",
        "https://bmclapi2.bangbang93.com/mirrors/authlib-injector/artifact/latest.json",
    ];

    let mut last_error = String::new();

    for url in urls {
        match client
            .get(url)
            .send()
            .and_then(|response| response.error_for_status())
        {
            Ok(response) => match response.json::<AuthlibInjectorLatest>() {
                Ok(latest) => return Ok(latest),
                Err(err) => last_error = format!("{url}\n{err}"),
            },
            Err(err) => last_error = format!("{url}\n{err}"),
        }
    }

    Err(simple_error(format!(
        "获取 authlib-injector 最新版本失败。\n\n{last_error}"
    )))
}

fn download_authlib_injector(url: &str, target: &Path) -> Result<(), LaunchError> {
    let client = http_client()?;

    let mut urls = vec![url.to_string()];

    if url.contains("authlib-injector.yushi.moe") {
        urls.push(url.replace(
            "https://authlib-injector.yushi.moe/",
            "https://bmclapi2.bangbang93.com/mirrors/authlib-injector/",
        ));
    }

    if !urls.iter().any(|url| url.contains("repo1.maven.org")) {
        urls.push("https://repo1.maven.org/maven2/org/glavo/hmcl/authlib-injector/1.2.7/authlib-injector-1.2.7.jar".to_string());
    }

    let mut last_error = String::new();

    for url in urls {
        match client
            .get(&url)
            .send()
            .and_then(|response| response.error_for_status())
        {
            Ok(response) => {
                let bytes = response.bytes()?;

                if bytes.len() < 1024 {
                    last_error = format!("文件过小：{url}");
                    continue;
                }

                fs::write(target, &bytes)?;

                if is_probably_jar(target) {
                    return Ok(());
                }

                let _ = fs::remove_file(target);
                last_error = format!("不是有效 jar：{url}");
            }
            Err(err) => last_error = format!("{url}\n{err}"),
        }
    }

    Err(simple_error(format!(
        "下载 authlib-injector 失败。\n\n{last_error}"
    )))
}

fn find_local_authlib_injector(dir: &Path) -> Result<Option<PathBuf>, LaunchError> {
    if !dir.is_dir() {
        return Ok(None);
    }

    let mut candidates = Vec::new();

    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();

        let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
            continue;
        };

        if path.is_file()
            && name.starts_with("authlib-injector-")
            && name.ends_with(".jar")
            && is_probably_jar(&path)
        {
            candidates.push(path);
        }
    }

    candidates.sort();
    Ok(candidates.pop())
}

fn is_probably_jar(path: &Path) -> bool {
    let Ok(bytes) = fs::read(path) else {
        return false;
    };

    bytes.len() >= 4 && bytes[0] == b'P' && bytes[1] == b'K'
}

fn fetch_authlib_injector_metadata(server_url: &str) -> Result<String, LaunchError> {
    Ok(http_client()?
        .get(server_url)
        .send()?
        .error_for_status()?
        .text()?)
}

fn http_client() -> Result<Client, LaunchError> {
    Ok(Client::builder()
        .user_agent("mc-launcher/0.1 hmcl-authlib-injector")
        .connect_timeout(Duration::from_secs(10))
        .timeout(Duration::from_secs(60))
        .build()?)
}

fn minecraft_root() -> Result<PathBuf, LaunchError> {
    Ok(data_root()?.join("minecraft"))
}

fn data_root() -> Result<PathBuf, LaunchError> {
    if let Some(value) = std::env::var_os("XDG_DATA_HOME") {
        if !value.is_empty() {
            return Ok(PathBuf::from(value).join("mc-launcher"));
        }
    }

    Ok(home_dir()?.join(".local").join("share").join("mc-launcher"))
}

fn home_dir() -> Result<PathBuf, LaunchError> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| simple_error("无法确定 HOME 目录。"))
}

fn os_name() -> &'static str {
    match std::env::consts::OS {
        "macos" => "osx",
        "windows" => "windows",
        _ => "linux",
    }
}

fn abs(path: &Path) -> String {
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()
            .map(|cwd| cwd.join(path))
            .unwrap_or_else(|_| path.to_path_buf())
    }
    .to_string_lossy()
    .to_string()
}

fn shell_quote(input: &str) -> String {
    format!("'{}'", input.replace('\'', "'\\''"))
}

fn simple_error(message: impl Into<String>) -> LaunchError {
    Box::new(io::Error::other(message.into()))
}
