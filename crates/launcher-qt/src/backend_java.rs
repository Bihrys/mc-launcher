use crate::backend::qobject;
use core::pin::Pin;
use cxx_qt_lib::QString;
use std::fs;
use std::path::PathBuf;
use std::thread;

impl qobject::LauncherBackend {
    pub fn detect_java(mut self: Pin<&mut Self>) {
        let runtimes = launcher_core::detect_java_runtimes();
        let json = java_runtimes_json(&runtimes);
        self.as_mut().set_detected_java_json(QString::from(&json));

        let text = if runtimes.is_empty() {
            "未检测到本机 Java 运行时。".to_string()
        } else {
            format!("已检测到 {} 个 Java 运行时。", runtimes.len())
        };

        self.as_mut().set_output(QString::from(&text));
    }

    pub fn start_detect_java(mut self: Pin<&mut Self>) {
        let path = java_task_status_path();
        write_java_status(
            &path,
            serde_json::json!({
                "active": true,
                "progress": 10,
                "title": "检测 Java",
                "message": "正在扫描本机 Java 运行时。",
                "runtimes": []
            }),
        );

        self.as_mut().set_output(QString::from("正在后台检测 Java。"));

        thread::spawn(move || {
            let runtimes = launcher_core::detect_java_runtimes();
            let items = java_runtimes_value(&runtimes);
            let message = if runtimes.is_empty() {
                "未检测到本机 Java 运行时。".to_string()
            } else {
                format!("已检测到 {} 个 Java 运行时。", runtimes.len())
            };
            write_java_status(
                &path,
                serde_json::json!({
                    "active": false,
                    "progress": 100,
                    "title": "检测 Java",
                    "message": message,
                    "runtimes": items
                }),
            );
        });
    }

    pub fn poll_java_task(mut self: Pin<&mut Self>) -> QString {
        let path = java_task_status_path();
        let text = fs::read_to_string(&path).unwrap_or_else(|_| {
            serde_json::json!({
                "active": false,
                "progress": 0,
                "title": "检测 Java",
                "message": "尚未开始检测。",
                "runtimes": []
            })
            .to_string()
        });

        if let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) {
            let runtimes = value
                .get("runtimes")
                .cloned()
                .unwrap_or_else(|| serde_json::Value::Array(vec![]));
            self.as_mut().set_detected_java_json(QString::from(
                &serde_json::json!({ "runtimes": runtimes }).to_string(),
            ));

            let title = value
                .get("title")
                .and_then(|value| value.as_str())
                .unwrap_or("检测 Java");
            let message = value
                .get("message")
                .and_then(|value| value.as_str())
                .unwrap_or_default();
            self.as_mut()
                .set_output(QString::from(&format!("{title}\n\n{message}")));
        }

        QString::from(&text)
    }

    pub fn download_java(
        mut self: Pin<&mut Self>,
        distribution: QString,
        major: QString,
        package_type: QString,
    ) {
        let distribution = distribution.to_string();
        let package_type = package_type.to_string();
        let major_text = major.to_string();

        let major = match major_text.trim().parse::<u32>() {
            Ok(major) => major,
            Err(err) => {
                self.as_mut().set_output(QString::from(&format!(
                    "Java 下载失败：无效 Java 版本 `{major_text}`\n\n{err}"
                )));
                return;
            }
        };

        self.as_mut().set_output(QString::from(&format!(
            "准备下载 Java...\n\n发行版: {distribution}\n版本: Java {major}\n包类型: {package_type}\n"
        )));

        match launcher_core::download_java_runtime(&distribution, major, &package_type) {
            Ok(result) => {
                let text = format!(
                    "Java 下载完成。\n\n发行版: {}\n包类型: {}\nJava 大版本: {}\nJava 版本: {}\n发行版版本: {}\n文件名: {}\n\n压缩包:\n{}\n\n安装目录:\n{}\n\nJava 可执行文件:\n{}\n",
                    result.distribution,
                    result.package_type,
                    result.major,
                    result.java_version,
                    result.distribution_version,
                    result.file_name,
                    result.archive_path.display(),
                    result.install_dir.display(),
                    result.java_binary.display(),
                );

                self.as_mut().set_output(QString::from(&text));
                self.as_mut().detect_java();
            }
            Err(err) => {
                let text = format!(
                    "Java 下载失败。\n\n发行版: {distribution}\n版本: Java {major}\n包类型: {package_type}\n\n{err}"
                );

                self.as_mut().set_output(QString::from(&text));
            }
        }
    }
}

fn java_runtimes_json(runtimes: &[launcher_core::JavaRuntime]) -> String {
    serde_json::json!({ "runtimes": java_runtimes_value(runtimes) }).to_string()
}

fn java_runtimes_value(runtimes: &[launcher_core::JavaRuntime]) -> Vec<serde_json::Value> {
    runtimes
        .iter()
        .map(|runtime| {
            serde_json::json!({
                "path": runtime.executable.display().to_string(),
                "version": runtime.version.clone().unwrap_or_default(),
                "major": runtime.major.map(|m| m.to_string()).unwrap_or_default(),
                "vendor": runtime.vendor_hint.clone().unwrap_or_default(),
                "managed": runtime.executable.display().to_string().contains("mc-launcher"),
            })
        })
        .collect()
}

fn write_java_status(path: &PathBuf, value: serde_json::Value) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(path, serde_json::to_string_pretty(&value).unwrap_or_else(|_| "{}".to_string()));
}

fn java_task_status_path() -> PathBuf {
    let cache_home = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
        .unwrap_or_else(std::env::temp_dir);
    cache_home.join("mc-launcher").join("java-detect-task.json")
}
