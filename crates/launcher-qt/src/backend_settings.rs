use crate::backend::qobject;
use core::pin::Pin;
use cxx_qt_lib::QString;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

impl qobject::LauncherBackend {
    pub fn refresh_appearance_options(self: Pin<&mut Self>) -> QString {
        QString::from(&appearance_options_json())
    }

    pub fn export_launcher_theme_pack(mut self: Pin<&mut Self>) -> QString {
        match export_theme_pack_file() {
            Ok(path) => {
                let message = format!("主题包已导出：{}", path.display());
                self.as_mut().set_output(QString::from(&message));
                QString::from(&path.display().to_string())
            }
            Err(err) => {
                let message = format!("导出主题包失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&message));
                QString::from(&message)
            }
        }
    }

    pub fn refresh_system_memory(self: Pin<&mut Self>) -> QString {
        QString::from(&system_memory_json())
    }

    pub fn refresh_launcher_settings(mut self: Pin<&mut Self>) -> QString {
        let value = load_launcher_settings_value();
        let text = value.to_string();

        self.as_mut()
            .set_launcher_settings_json(QString::from(&text));

        QString::from(&text)
    }

    pub fn open_folder(mut self: Pin<&mut Self>, path: QString) {
        let path_str = path.to_string();
        let p = std::path::Path::new(&path_str);

        if !p.exists() {
            self.as_mut()
                .set_output(QString::from(&format!("目录不存在：{path_str}")));
            return;
        }

        if let Err(err) = launcher_core::platform::open_folder::open_folder(p) {
            self.as_mut()
                .set_output(QString::from(&format!("打开文件夹失败。\n\n{err}")));
        }
    }

    pub fn open_launcher_special_folder(mut self: Pin<&mut Self>, kind: QString) -> QString {
        let kind = kind.to_string();
        let path = launcher_special_folder(&kind);

        if let Err(err) = fs::create_dir_all(&path) {
            let message = format!("创建目录失败：{}\n\n{err}", path.display());
            self.as_mut().set_output(QString::from(&message));
            return QString::from(&message);
        }

        match launcher_core::platform::open_folder::open_folder(&path) {
            Ok(()) => {
                let message = format!("已打开目录：{}", path.display());
                self.as_mut().set_output(QString::from(&message));
                QString::from(&path.display().to_string())
            }
            Err(err) => {
                let message = format!("打开目录失败：{}\n\n{err}", path.display());
                self.as_mut().set_output(QString::from(&message));
                QString::from(&message)
            }
        }
    }

    pub fn export_launcher_diagnostics(mut self: Pin<&mut Self>) -> QString {
        let diagnostics_dir = launcher_config_dir().join("diagnostics");

        if let Err(err) = fs::create_dir_all(&diagnostics_dir) {
            let message = format!("创建诊断目录失败。\n\n{err}");
            self.as_mut().set_output(QString::from(&message));
            return QString::from(&message);
        }

        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|duration| duration.as_secs())
            .unwrap_or(0);
        let path = diagnostics_dir.join(format!("diagnostics-{timestamp}.json"));
        let settings = load_launcher_settings_value();
        let diagnostics = serde_json::json!({
            "launcher": {
                "name": "mc-launcher",
                "version": "0.1.0",
                "os": std::env::consts::OS,
                "arch": std::env::consts::ARCH,
                "target_family": std::env::consts::FAMILY
            },
            "paths": {
                "config": launcher_config_dir(),
                "data": launcher_data_dir(),
                "cache": launcher_cache_dir(),
                "logs": launcher_logs_dir(),
                "minecraft": launcher_minecraft_dir(),
                "settings": launcher_settings_path()
            },
            "settings": settings
        });

        match fs::File::create(&path).and_then(|mut file| file.write_all(serde_json::to_string_pretty(&diagnostics).unwrap_or_else(|_| "{}".to_string()).as_bytes())) {
            Ok(()) => {
                let message = format!("诊断信息已导出：{}", path.display());
                self.as_mut().set_output(QString::from(&message));
                QString::from(&path.display().to_string())
            }
            Err(err) => {
                let message = format!("导出诊断信息失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&message));
                QString::from(&message)
            }
        }
    }


    pub fn clear_launcher_cache(mut self: Pin<&mut Self>) -> QString {
        let cache_dir = launcher_cache_dir();
        let target = cache_dir.join("downloads");
        let path = if target.exists() { target } else { cache_dir };

        let result = if path.exists() {
            fs::remove_dir_all(&path).and_then(|_| fs::create_dir_all(&path))
        } else {
            fs::create_dir_all(&path)
        };

        match result {
            Ok(()) => {
                let message = format!("下载缓存已清理：{}", path.display());
                self.as_mut().set_output(QString::from(&message));
                QString::from(&message)
            }
            Err(err) => {
                let message = format!("清理下载缓存失败：{}\n\n{err}", path.display());
                self.as_mut().set_output(QString::from(&message));
                QString::from(&message)
            }
        }
    }

    pub fn reset_launcher_settings(mut self: Pin<&mut Self>) -> QString {
        let settings = default_launcher_settings_value();

        match save_launcher_settings_value(&settings) {
            Ok(()) => {
                let text = settings.to_string();
                self.as_mut().set_launcher_settings_json(QString::from(&text));
                self.as_mut().set_output(QString::from("启动器设置已恢复默认值。"));
                QString::from(&text)
            }
            Err(err) => {
                let message = format!("重置设置失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&message));
                QString::from(&message)
            }
        }
    }

    pub fn open_url(mut self: Pin<&mut Self>, url: QString) {
        let url_str = url.to_string();
        let result = match std::env::consts::OS {
            "linux" => std::process::Command::new("xdg-open").arg(&url_str).spawn(),
            "macos" => std::process::Command::new("open").arg(&url_str).spawn(),
            "windows" => std::process::Command::new("cmd").args(["/c", "start", &url_str]).spawn(),
            _ => return,
        };

        if let Err(err) = result {
            self.as_mut()
                .set_output(QString::from(&format!("打开链接失败。\n\n{err}")));
        }
    }

    pub fn update_launcher_setting(mut self: Pin<&mut Self>, key: QString, value: QString) {
        let key = key.to_string();
        let raw_value = value.to_string();

        let mut settings = load_launcher_settings_value();
        let Some(object) = settings.as_object_mut() else {
            self.as_mut()
                .set_output(QString::from("保存设置失败：设置文件结构不是对象。"));
            return;
        };

        object.insert(key.clone(), parse_launcher_setting_value(&key, &raw_value));

        match save_launcher_settings_value(&settings) {
            Ok(()) => {
                let text = settings.to_string();
                self.as_mut()
                    .set_launcher_settings_json(QString::from(&text));
                self.as_mut()
                    .set_output(QString::from(&format!("设置已保存：{key} = {raw_value}")));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("保存设置失败。\n\n{err}")));
            }
        }
    }
}


fn system_memory_json() -> String {
    let mut total_kib: u64 = 0;
    let mut available_kib: u64 = 0;

    if let Ok(text) = fs::read_to_string("/proc/meminfo") {
        for line in text.lines() {
            if let Some(rest) = line.strip_prefix("MemTotal:") {
                total_kib = rest.split_whitespace().next().and_then(|v| v.parse().ok()).unwrap_or(0);
            } else if let Some(rest) = line.strip_prefix("MemAvailable:") {
                available_kib = rest.split_whitespace().next().and_then(|v| v.parse().ok()).unwrap_or(0);
            }
        }
    }

    if total_kib == 0 {
        return serde_json::json!({
            "total_gib": 31.2,
            "used_gib": 12.9,
            "available_gib": 18.3
        }).to_string();
    }

    let used_kib = total_kib.saturating_sub(available_kib);
    let kib_per_gib = 1024.0 * 1024.0;

    serde_json::json!({
        "total_gib": (total_kib as f64) / kib_per_gib,
        "used_gib": (used_kib as f64) / kib_per_gib,
        "available_gib": (available_kib as f64) / kib_per_gib
    }).to_string()
}

fn launcher_settings_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value)
                .join("mc-launcher")
                .join("settings.json");
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join(".config")
            .join("mc-launcher")
            .join("settings.json");
    }

    std::env::temp_dir()
        .join("mc-launcher")
        .join("settings.json")
}

fn launcher_config_dir() -> PathBuf {
    launcher_settings_path()
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| std::env::temp_dir().join("mc-launcher"))
}

fn home_dir() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
}

fn launcher_data_dir() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_DATA_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value).join("mc-launcher");
        }
    }

    home_dir().join(".local").join("share").join("mc-launcher")
}

fn launcher_cache_dir() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value).join("mc-launcher");
        }
    }

    home_dir().join(".cache").join("mc-launcher")
}

fn launcher_logs_dir() -> PathBuf {
    launcher_config_dir().join("logs")
}

fn launcher_minecraft_dir() -> PathBuf {
    launcher_data_dir().join("minecraft")
}

fn launcher_special_folder(kind: &str) -> PathBuf {
    match kind {
        "config" => launcher_config_dir(),
        "logs" => launcher_logs_dir(),
        "data" => launcher_data_dir(),
        "cache" => launcher_cache_dir(),
        "minecraft" => launcher_minecraft_dir(),
        "settings" => launcher_settings_path()
            .parent()
            .map(Path::to_path_buf)
            .unwrap_or_else(launcher_config_dir),
        "themes" => launcher_config_dir().join("themes"),
        _ => launcher_config_dir(),
    }
}


fn appearance_options_json() -> String {
    let fonts = detect_font_families();
    serde_json::json!({
        "themePacks": [
            {"id": "default", "title": "默认"}
        ],
        "builtinBackgrounds": [
            {"id": "classic", "title": "经典"},
            {"id": "default", "title": "默认"}
        ],
        "themeColors": [
            {"id": "default", "title": "默认"},
            {"id": "purple", "title": "紫色"},
            {"id": "blue", "title": "蓝色"},
            {"id": "green", "title": "绿色"},
            {"id": "red", "title": "红色"},
            {"id": "orange", "title": "橙色"}
        ],
        "fonts": fonts
    }).to_string()
}

fn detect_font_families() -> Vec<String> {
    let mut fonts: Vec<String> = Vec::new();

    if let Ok(output) = std::process::Command::new("fc-list")
        .args([":", "family"])
        .output()
    {
        if output.status.success() {
            let text = String::from_utf8_lossy(&output.stdout);
            for line in text.lines() {
                for family in line.split(',') {
                    let family = family.trim();
                    if !family.is_empty() && !fonts.iter().any(|item| item == family) {
                        fonts.push(family.to_string());
                    }
                }
            }
        }
    }

    if fonts.is_empty() {
        fonts.extend([
            "Noto Sans CJK SC".to_string(),
            "Sans Serif".to_string(),
            "Serif".to_string(),
            "monospace".to_string(),
        ]);
    }

    fonts.sort();
    fonts.truncate(120);
    fonts
}

fn export_theme_pack_file() -> Result<PathBuf, Box<dyn std::error::Error + Send + Sync + 'static>> {
    let settings = load_launcher_settings_value();
    let themes_dir = launcher_config_dir().join("themes");
    fs::create_dir_all(&themes_dir)?;

    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0);
    let path = themes_dir.join(format!("theme-pack-{timestamp}.json"));

    let package = serde_json::json!({
        "format": "mc-launcher-theme-pack",
        "hmcl_mapping": {
            "source_classes": [
                "PersonalizationPage.java",
                "Themes.java",
                "ThemePackExporter.java",
                "ThemePackManager.java"
            ]
        },
        "exported_at_unix": timestamp,
        "appearance": {
            "selectedThemeTitle": settings.get("selectedThemeTitle"),
            "themeBrightnessMode": settings.get("themeBrightnessMode"),
            "themeColorType": settings.get("themeColorType"),
            "customThemeColor": settings.get("customThemeColor"),
            "themeColor": settings.get("themeColor"),
            "themeColorStyle": settings.get("themeColorStyle"),
            "backgroundType": settings.get("backgroundType"),
            "builtinBackgroundId": settings.get("builtinBackgroundId"),
            "customBackgroundImagePath": settings.get("customBackgroundImagePath"),
            "networkBackgroundImageUrl": settings.get("networkBackgroundImageUrl"),
            "customBackgroundPaint": settings.get("customBackgroundPaint"),
            "backgroundOpacity": settings.get("backgroundOpacity"),
            "backgroundFallbackType": settings.get("backgroundFallbackType"),
            "backgroundFallbackPaint": settings.get("backgroundFallbackPaint"),
            "backgroundLoadPolicy": settings.get("backgroundLoadPolicy"),
            "titleBarTransparent": settings.get("titleBarTransparent"),
            "animationDisabled": settings.get("animationDisabled"),
            "launcherFontFamily": settings.get("launcherFontFamily"),
            "logFontFamily": settings.get("logFontFamily"),
            "logFontSize": settings.get("logFontSize"),
            "fontAntiAliasing": settings.get("fontAntiAliasing"),
            "themeAppearanceOverrides": settings.get("themeAppearanceOverrides")
        }
    });

    fs::write(&path, serde_json::to_string_pretty(&package)?)?;
    Ok(path)
}

fn default_launcher_settings_value() -> serde_json::Value {
    // 按 HMCL 迁移规则：默认设置属于应用层配置模型，不在 QML 中硬编码。
    // 这里避免使用过深的 serde_json::json! 宏，防止 Rust 宏递归上限触发编译失败。
    serde_json::from_str::<serde_json::Value>(
        r#"{
            "themeMode": "light",
            "themeBrightnessMode": "auto",
            "themeColor": "default",
            "themeColorType": "default",
            "customThemeColor": "default",
            "themeAppearanceOverrides": "",
            "selectedThemeTitle": "默认",
            "launcherVisibility": "hide",

            "updateChannel": "stable",
            "acceptPreviewUpdate": false,
            "disableAutoShowUpdateDialog": false,
            "checkUpdateOnStartup": true,

            "minMemoryMb": 256,
            "maxMemoryMb": 7936,
            "autoMemory": true,
            "defaultIsolation": "modded",
            "javaType": "auto",
            "customJavaVersion": "17",
            "gameWidth": 854,
            "gameHeight": 480,
            "fullscreen": false,
            "windowType": "windowed",
            "gameResolution": "854x480",
            "quickPlayType": "none",
            "quickPlayServer": "",
            "quickPlaySingleplayer": "",
            "javaPath": "",
            "javaAuto": true,
            "jvmArgs": "",
            "noJVMOptions": false,
            "noOptimizingJVMOptions": false,
            "notCheckJVM": false,
            "permSize": "",
            "gameDir": "",
            "preLaunchCommand": "",
            "commandWrapper": "",
            "postExitCommand": "",

            "language": "zh_CN",
            "disableAprilFools": false,
            "titleTransparent": false,
            "turnOffAnimations": false,
            "disableAutoGameOptions": false,
            "enableGameList": true,
            "enableOfflineAccount": true,
            "allowAutoAgent": true,
            "showLogs": false,
            "enableDebugLogOutput": false,
            "notCheckGame": false,
            "runningDir": "",
            "gameArguments": "",
            "environmentVariables": "",
            "processPriority": "normal",
            "graphicsBackend": "default",
            "openGLRenderer": "default",
            "themePack": "default",
            "themeColorStyle": "system",
            "themeBrightness": "auto",
            "backgroundType": "default",
            "builtinBackgroundId": "classic",
            "backgroundImage": "",
            "customBackgroundImagePath": "",
            "backgroundImageUrl": "",
            "networkBackgroundImageUrl": "",
            "backgroundPaint": "",
            "customBackgroundPaint": "",
            "backgroundOpacity": 1.0,
            "fallbackBackgroundType": "builtin",
            "backgroundFallbackType": "builtin",
            "backgroundFallbackPaint": "",
            "backgroundLoadPolicy": "wait_for_background",
            "networkBackgroundImageCachePolicy": "enabled",
            "logFont": "monospace",
            "logFontFamily": "monospace",
            "logFontSize": 12.0,
            "globalFontFamily": "",
            "launcherFontFamily": "",

            "autoChooseDownloadSource": true,
            "versionListSource": "balanced",
            "downloadSource": "balanced",
            "defaultAddonSource": "modrinth",
            "commonDirType": "default",
            "commonDirectory": "",
            "autoDownloadThreads": true,
            "downloadThreads": 64,

            "proxyType": "default",
            "proxyHost": "",
            "proxyPort": 0,
            "proxyUsername": "",
            "proxyPassword": "",
            "hasProxyAuth": false,

            "uiScale": 1.0,
            "fontAntiAliasing": "auto"
        }"#,
    )
    .expect("default launcher settings JSON must be valid")
}

pub(crate) fn load_launcher_settings_value() -> serde_json::Value {
    let path = launcher_settings_path();
    let mut settings = default_launcher_settings_value();

    if let Ok(text) = fs::read_to_string(&path) {
        if let Ok(user_settings) = serde_json::from_str::<serde_json::Value>(&text) {
            merge_json_object(&mut settings, user_settings);
        }
    }

    let _ = save_launcher_settings_value(&settings);
    settings
}

fn save_launcher_settings_value(
    value: &serde_json::Value,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let path = launcher_settings_path();

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string_pretty(value)?)?;
    Ok(())
}

fn merge_json_object(base: &mut serde_json::Value, overlay: serde_json::Value) {
    let Some(base_object) = base.as_object_mut() else {
        return;
    };

    let Some(overlay_object) = overlay.as_object() else {
        return;
    };

    for (key, value) in overlay_object {
        base_object.insert(key.clone(), value.clone());
    }
}

fn parse_launcher_setting_value(key: &str, raw: &str) -> serde_json::Value {
    match key {
        "minMemoryMb" | "maxMemoryMb" | "gameWidth" | "gameHeight" | "downloadThreads"
        | "proxyPort" | "permSize" => {
            let value = raw.trim().parse::<u64>().unwrap_or(0);
            serde_json::Value::Number(value.into())
        }
        "autoMemory"
        | "noJVMOptions"
        | "noOptimizingJVMOptions"
        | "notCheckJVM"
        | "javaAuto"
        | "titleTransparent"
        | "turnOffAnimations"
        | "animationDisabled"
        | "acceptPreviewUpdate"
        | "disableAutoShowUpdateDialog"
        | "checkUpdateOnStartup"
        | "disableAprilFools"
        | "disableAutoGameOptions"
        | "showLogs"
        | "enableDebugLogOutput"
        | "notCheckGame"
        | "enableGameList"
        | "enableOfflineAccount"
        | "allowAutoAgent"
        | "autoChooseDownloadSource"
        | "autoDownloadThreads"
        | "hasProxyAuth"
        | "fullscreen" => serde_json::Value::Bool(raw.trim() == "true"),
        "uiScale" | "backgroundOpacity" | "logFontSize" => {
            let value = raw.trim().parse::<f64>().unwrap_or(1.0);
            serde_json::Number::from_f64(value)
                .map(serde_json::Value::Number)
                .unwrap_or_else(|| serde_json::Value::Number(serde_json::Number::from(1)))
        }
        _ => serde_json::Value::String(raw.to_string()),
    }
}

pub(crate) fn launcher_setting_u32(settings: &serde_json::Value, key: &str) -> Option<u32> {
    settings.get(key).and_then(|value| {
        value
            .as_u64()
            .and_then(|value| u32::try_from(value).ok())
            .or_else(|| value.as_str().and_then(|value| value.parse::<u32>().ok()))
    })
}

pub(crate) fn launcher_setting_bool(settings: &serde_json::Value, key: &str) -> Option<bool> {
    settings.get(key).and_then(|value| {
        value
            .as_bool()
            .or_else(|| value.as_str().map(|value| value == "true"))
    })
}

pub(crate) fn launcher_setting_string(settings: &serde_json::Value, key: &str) -> Option<String> {
    settings
        .get(key)
        .and_then(|value| value.as_str())
        .map(ToString::to_string)
}
