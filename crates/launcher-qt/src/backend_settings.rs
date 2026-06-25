use crate::backend::qobject;
use core::pin::Pin;
use cxx_qt_lib::QString;
use std::fs;
use std::path::PathBuf;

impl qobject::LauncherBackend {
    pub fn refresh_launcher_settings(mut self: Pin<&mut Self>) -> QString {
        let value = load_launcher_settings_value();
        let text = value.to_string();

        self.as_mut()
            .set_launcher_settings_json(QString::from(&text));

        QString::from(&text)
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

fn default_launcher_settings_value() -> serde_json::Value {
    serde_json::json!({
        "themeMode": "light",
        "launcherVisibility": "hide",

        "minMemoryMb": 256,
        "maxMemoryMb": 2048,
        "gameWidth": 854,
        "gameHeight": 480,
        "fullscreen": false,
        "javaPath": "",
        "javaAuto": true,
        "jvmArgs": "",
        "gameDir": "",

        "language": "zh_CN",
        "themeColor": "default",
        "titleTransparent": false,
        "turnOffAnimations": false,
        "disableAutoGameOptions": false,
        "enableGameList": true,
        "allowAutoAgent": true,
        "logFont": "monospace",

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

        "uiScale": 1.0,
        "fontAntiAliasing": "auto"
    })
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
        | "proxyPort" => {
            let value = raw.trim().parse::<u64>().unwrap_or(0);
            serde_json::Value::Number(value.into())
        }
        "fullscreen"
        | "javaAuto"
        | "titleTransparent"
        | "turnOffAnimations"
        | "disableAutoGameOptions"
        | "enableGameList"
        | "allowAutoAgent"
        | "autoChooseDownloadSource"
        | "autoDownloadThreads" => serde_json::Value::Bool(raw.trim() == "true"),
        "uiScale" => {
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
