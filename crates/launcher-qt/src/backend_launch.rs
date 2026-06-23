use crate::backend::qobject;
use crate::backend_settings::{
    launcher_setting_bool, launcher_setting_string, launcher_setting_u32,
    load_launcher_settings_value,
};
use core::pin::Pin;
use cxx_qt_lib::QString;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

impl qobject::LauncherBackend {
    pub fn launch_selected_version(mut self: Pin<&mut Self>) {
        self.as_mut()
            .start_launch_selected_version(QString::from("keep"));
    }

    pub fn start_launch_selected_version(mut self: Pin<&mut Self>, visibility: QString) {
        let visibility = normalize_launcher_visibility(&visibility.to_string());
        let status_path = launch_task_status_path();

        if launch_task_is_active(&status_path) {
            self.as_mut().set_output(QString::from(
                "已经有启动任务在运行。请等待当前启动流程结束。",
            ));
            return;
        }

        let cancel_flag = launch_cancel_flag();
        cancel_flag.store(false, Ordering::Relaxed);

        let version_id = match launcher_core::selected_version() {
            Ok(version_id) => version_id,
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("启动失败。\n\n{err}")));
                return;
            }
        };

        self.as_mut()
            .set_selected_game_version(QString::from(&version_id));

        let launch_id = new_launch_task_id();

        write_hmcl_launch_task_status(
            &status_path,
            &launch_id,
            true,
            0,
            "launch.state.java",
            "检测 Java 版本",
            "请耐心等待",
            -1.0,
            "running",
            &visibility,
            false,
            false,
            false,
            false,
            0,
            true,
            false,
        );

        self.as_mut()
            .set_launch_task_json(QString::from(&read_launch_task_status_text(&status_path)));

        self.as_mut().set_output(QString::from(&format!(
            "启动游戏\n\n版本: {version_id}\n启动器可见性: {}",
            launcher_visibility_text(&visibility),
        )));

        thread::spawn(move || {
            let check_cancelled = |stage: &str,
                                   title: &str,
                                   status_path: &Path,
                                   launch_id: &str,
                                   visibility: &str|
             -> bool {
                if cancel_flag.load(Ordering::Relaxed) {
                    write_hmcl_launch_task_status(
                        status_path,
                        launch_id,
                        false,
                        0,
                        stage,
                        title,
                        "启动已取消。",
                        0.0,
                        "cancelled",
                        visibility,
                        false,
                        false,
                        false,
                        false,
                        0,
                        false,
                        true,
                    );

                    return true;
                }

                false
            };

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                8,
                "launch.state.java",
                "检测 Java 版本",
                "正在检测可用 Java，并匹配当前游戏版本要求。",
                0.35,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            thread::sleep(Duration::from_millis(160));

            if check_cancelled(
                "launch.state.java",
                "检测 Java 版本",
                &status_path,
                &launch_id,
                &visibility,
            ) {
                return;
            }

            let java_count = launcher_core::detect_java_runtimes().len();

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                16,
                "launch.state.java",
                "检测 Java 版本",
                &format!("Java 检测完成，找到 {java_count} 个运行时。"),
                1.0,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            thread::sleep(Duration::from_millis(120));

            if check_cancelled(
                "launch.state.dependencies",
                "检查游戏文件完整性",
                &status_path,
                &launch_id,
                &visibility,
            ) {
                return;
            }

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                25,
                "launch.state.dependencies",
                "检查游戏文件完整性",
                "正在检查版本 JSON、客户端 jar 和启动目录。",
                0.20,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            thread::sleep(Duration::from_millis(160));

            if check_cancelled(
                "launch.state.dependencies",
                "检查资源文件",
                &status_path,
                &launch_id,
                &visibility,
            ) {
                return;
            }

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                36,
                "launch.state.dependencies",
                "检查资源文件",
                "正在检查 assets 索引和资源目录。",
                0.45,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            thread::sleep(Duration::from_millis(160));

            if check_cancelled(
                "launch.state.dependencies",
                "检查依赖库",
                &status_path,
                &launch_id,
                &visibility,
            ) {
                return;
            }

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                48,
                "launch.state.dependencies",
                "检查依赖库",
                "正在检查 libraries 和 classpath。",
                0.70,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            thread::sleep(Duration::from_millis(160));

            if check_cancelled(
                "launch.state.dependencies",
                "解压本地库",
                &status_path,
                &launch_id,
                &visibility,
            ) {
                return;
            }

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                58,
                "launch.state.dependencies",
                "解压本地库",
                "正在准备 natives 目录。",
                0.88,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            thread::sleep(Duration::from_millis(160));

            if check_cancelled(
                "launch.state.logging_in",
                "登录",
                &status_path,
                &launch_id,
                &visibility,
            ) {
                return;
            }

            let account_text = match launcher_core::selected_account() {
                Ok(Some(account)) => format!("正在使用账户 {} 登录。", account.username),
                Ok(None) => "正在读取账户信息。".to_string(),
                Err(err) => {
                    write_hmcl_launch_task_status(
                        &status_path,
                        &launch_id,
                        false,
                        0,
                        "launch.state.logging_in",
                        "登录",
                        &format!("读取账户失败：{err}"),
                        0.0,
                        "failed",
                        &visibility,
                        false,
                        false,
                        false,
                        false,
                        0,
                        false,
                        false,
                    );
                    return;
                }
            };

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                70,
                "launch.state.logging_in",
                "登录",
                &account_text,
                0.55,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            thread::sleep(Duration::from_millis(180));

            if check_cancelled(
                "launch.state.waiting_launching",
                "启动游戏",
                &status_path,
                &launch_id,
                &visibility,
            ) {
                return;
            }

            write_hmcl_launch_task_status(
                &status_path,
                &launch_id,
                true,
                82,
                "launch.state.waiting_launching",
                "启动游戏",
                "请耐心等待，正在生成启动命令并创建游戏进程。",
                -1.0,
                "running",
                &visibility,
                false,
                false,
                false,
                false,
                0,
                true,
                false,
            );

            let settings = load_launcher_settings_value();

            let mut options = launcher_core::LaunchOptions::default();
            options.version_id = version_id.clone();
            options.min_memory_mb = launcher_setting_u32(&settings, "minMemoryMb");
            options.max_memory_mb =
                launcher_setting_u32(&settings, "maxMemoryMb").or(options.max_memory_mb);
            options.width = launcher_setting_u32(&settings, "gameWidth").or(options.width);
            options.height = launcher_setting_u32(&settings, "gameHeight").or(options.height);
            options.fullscreen = launcher_setting_bool(&settings, "fullscreen").unwrap_or(false);

            if let Some(java_path) = launcher_setting_string(&settings, "javaPath") {
                if !java_path.trim().is_empty() {
                    options.java_path = Some(PathBuf::from(java_path));
                }
            }

            match launcher_core::launch_game(options) {
                Ok(result) => {
                    let pid = result.pid.unwrap_or(0);
                    let message = format!(
                        "游戏进程已创建。\n\n版本: {}\nPID: {}\n运行目录:\n{}\n启动脚本:\n{}",
                        result.version_id,
                        if pid == 0 {
                            "unknown".to_string()
                        } else {
                            pid.to_string()
                        },
                        result.game_dir.display(),
                        result.script_path.display(),
                    );

                    // HMCL 语义：
                    // CLOSE：游戏启动后结束启动器。
                    // HIDE：游戏启动后隐藏/关闭启动器，不在游戏退出后重新打开。
                    // HIDE_AND_REOPEN：隐藏启动器，并在游戏退出后重新打开。
                    let should_close = visibility == "close" || visibility == "hide";
                    let should_hide = visibility == "hide_and_reopen";
                    let wait_game = visibility == "hide_and_reopen" && pid != 0;

                    write_hmcl_launch_task_status(
                        &status_path,
                        &launch_id,
                        wait_game,
                        100,
                        "launch.state.waiting_launching",
                        "请耐心等待",
                        &message,
                        1.0,
                        if wait_game { "gameRunning" } else { "finished" },
                        &visibility,
                        true,
                        should_hide,
                        should_close,
                        false,
                        pid,
                        false,
                        false,
                    );

                    if wait_game {
                        while process_is_alive(pid) {
                            thread::sleep(Duration::from_secs(1));
                        }

                        write_hmcl_launch_task_status(
                            &status_path,
                            &launch_id,
                            false,
                            100,
                            "launch.state.waiting_launching",
                            "游戏已退出",
                            "游戏进程已结束，正在恢复启动器窗口。",
                            1.0,
                            "gameExited",
                            &visibility,
                            true,
                            false,
                            false,
                            true,
                            pid,
                            false,
                            false,
                        );
                    }
                }
                Err(err) => {
                    write_hmcl_launch_task_status(
                        &status_path,
                        &launch_id,
                        false,
                        0,
                        "launch.state.waiting_launching",
                        "启动游戏",
                        &err.to_string(),
                        0.0,
                        "failed",
                        &visibility,
                        false,
                        false,
                        false,
                        false,
                        0,
                        false,
                        false,
                    );
                }
            }
        });
    }

    pub fn cancel_launch_task(mut self: Pin<&mut Self>) {
        launch_cancel_flag().store(true, Ordering::Relaxed);

        let path = launch_task_status_path();
        let mut value =
            serde_json::from_str::<serde_json::Value>(&read_launch_task_status_text(&path))
                .unwrap_or_else(|_| serde_json::json!({}));

        value["active"] = serde_json::Value::Bool(true);
        value["cancelled"] = serde_json::Value::Bool(true);
        value["canCancel"] = serde_json::Value::Bool(false);
        value["status"] = serde_json::Value::String("cancelling".to_string());
        value["title"] = serde_json::Value::String("启动游戏".to_string());
        value["message"] = serde_json::Value::String("正在取消启动任务。".to_string());

        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }

        let _ = fs::write(&path, value.to_string());

        self.as_mut()
            .set_launch_task_json(QString::from(&value.to_string()));

        self.as_mut()
            .set_output(QString::from("正在取消启动任务。"));
    }

    pub fn poll_launch_task(mut self: Pin<&mut Self>) -> QString {
        let path = launch_task_status_path();
        let text = read_launch_task_status_text(&path);

        self.as_mut().set_launch_task_json(QString::from(&text));

        QString::from(&text)
    }
}

fn launch_cancel_flag() -> Arc<AtomicBool> {
    LAUNCH_CANCEL_FLAG
        .get_or_init(|| Arc::new(AtomicBool::new(false)))
        .clone()
}

fn write_hmcl_launch_task_status(
    path: &Path,
    id: &str,
    active: bool,
    percent: u32,
    current_stage: &str,
    task_title: &str,
    task_message: &str,
    task_progress: f64,
    status: &str,
    visibility: &str,
    game_started: bool,
    should_hide: bool,
    should_close: bool,
    should_reopen: bool,
    pid: u32,
    can_cancel: bool,
    cancelled: bool,
) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let stages = hmcl_launch_stages(current_stage, status);
    let tasks = if status == "finished" || status == "gameRunning" || status == "gameExited" {
        Vec::new()
    } else {
        vec![serde_json::json!({
            "stage": current_stage,
            "title": task_title,
            "message": task_message,
            "progress": task_progress,
            "active": active,
            "failed": status == "failed",
            "cancelled": cancelled
        })]
    };

    let payload = serde_json::json!({
        "id": id,
        "active": active,
        "cancelled": cancelled,
        "canCancel": can_cancel && active && !cancelled,
        "percent": percent.min(100),
        "title": "启动游戏",
        "message": task_message,
        "status": status,
        "visibility": visibility,
        "gameStarted": game_started,
        "shouldHide": should_hide,
        "shouldClose": should_close,
        "shouldReopen": should_reopen,
        "pid": pid,
        "currentStage": current_stage,
        "stages": stages,
        "tasks": tasks,
        "speedText": "请耐心等待"
    });

    let _ = fs::write(path, payload.to_string());
}

fn hmcl_launch_stages(current_stage: &str, status: &str) -> Vec<serde_json::Value> {
    let order = [
        ("launch.state.java", "检测 Java 版本"),
        ("launch.state.dependencies", "处理游戏依赖"),
        ("launch.state.logging_in", "登录"),
        ("launch.state.waiting_launching", "等待游戏启动"),
    ];

    let current_index = order
        .iter()
        .position(|(key, _)| *key == current_stage)
        .unwrap_or(0);

    order
        .iter()
        .enumerate()
        .map(|(index, (key, title))| {
            let stage_status = if status == "failed" && *key == current_stage {
                "failed"
            } else if status == "cancelled" && *key == current_stage {
                "failed"
            } else if index < current_index {
                "success"
            } else if index == current_index {
                if status == "finished" || status == "gameRunning" || status == "gameExited" {
                    "success"
                } else {
                    "running"
                }
            } else {
                "waiting"
            };

            serde_json::json!({
                "key": key,
                "title": title,
                "status": stage_status,
                "done": if stage_status == "success" { 1 } else { 0 },
                "total": 1
            })
        })
        .collect()
}

fn launch_task_status_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value)
                .join("mc-launcher")
                .join("launch-task.json");
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join(".cache")
            .join("mc-launcher")
            .join("launch-task.json");
    }

    std::env::temp_dir()
        .join("mc-launcher")
        .join("launch-task.json")
}

fn read_launch_task_status_text(path: &Path) -> String {
    fs::read_to_string(path).unwrap_or_else(|_| {
        serde_json::json!({
            "id": "",
            "active": false,
            "percent": 0,
            "title": "空闲",
            "message": "还没有启动任务。",
            "status": "idle",
            "visibility": "hide",
            "gameStarted": false,
            "shouldHide": false,
            "shouldClose": false,
            "shouldReopen": false,
            "pid": 0
        })
        .to_string()
    })
}

fn launch_task_is_active(path: &Path) -> bool {
    let Ok(text) = fs::read_to_string(path) else {
        return false;
    };

    serde_json::from_str::<serde_json::Value>(&text)
        .ok()
        .and_then(|value| {
            value
                .get("active")
                .and_then(|value| value.as_bool())
                .map(bool::from)
        })
        .unwrap_or(false)
}

fn write_launch_task_status(
    path: &Path,
    id: &str,
    active: bool,
    percent: u32,
    title: &str,
    message: &str,
    status: &str,
    visibility: &str,
    game_started: bool,
    should_hide: bool,
    should_close: bool,
    should_reopen: bool,
    pid: u32,
) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let payload = serde_json::json!({
        "id": id,
        "active": active,
        "percent": percent.min(100),
        "title": title,
        "message": message,
        "status": status,
        "visibility": visibility,
        "gameStarted": game_started,
        "shouldHide": should_hide,
        "shouldClose": should_close,
        "shouldReopen": should_reopen,
        "pid": pid
    });

    let _ = fs::write(path, payload.to_string());
}

fn new_launch_task_id() -> String {
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or(0);

    format!("launch-{millis}")
}

fn normalize_launcher_visibility(value: &str) -> String {
    match value.trim() {
        "close" => "close".to_string(),
        "hide" => "hide".to_string(),
        "keep" => "keep".to_string(),
        "hide_and_reopen" => "hide_and_reopen".to_string(),
        _ => "hide".to_string(),
    }
}

fn launcher_visibility_text(value: &str) -> &'static str {
    match value {
        "close" => "游戏启动后关闭启动器",
        "hide" => "游戏启动后隐藏启动器",
        "keep" => "保持启动器可见",
        "hide_and_reopen" => "隐藏启动器，并在游戏退出后重新打开",
        _ => "游戏启动后隐藏启动器",
    }
}

fn process_is_alive(pid: u32) -> bool {
    if pid == 0 {
        return false;
    }

    PathBuf::from("/proc").join(pid.to_string()).exists()
}
