use crate::backend::qobject;
use crate::backend_settings::{
    launcher_setting_bool, launcher_setting_string, launcher_setting_u32,
    load_launcher_settings_value,
};
use crate::task_bridge::{read_status_text, task_status_is_active};
use core::pin::Pin;
use cxx_qt_lib::QString;
use launcher_core::download_center::DownloadService;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};
use std::thread;

static DOWNLOAD_CANCEL_FLAG: OnceLock<Arc<AtomicBool>> = OnceLock::new();

impl qobject::LauncherBackend {
    pub fn refresh_download_catalog(mut self: Pin<&mut Self>, source: QString) -> QString {
        let source = source.to_string();

        self.as_mut().set_output(QString::from(
            "正在获取 Minecraft / Fabric / Quilt / Forge / NeoForge 版本列表...",
        ));

        match DownloadService::fetch_catalog_json(&source) {
            Ok(json) => {
                self.as_mut()
                    .set_download_catalog_json(QString::from(&json));
                self.as_mut().set_output(QString::from(
                    "版本列表获取完成。选择 Minecraft 版本和加载器后即可安装。",
                ));
                QString::from(&json)
            }
            Err(err) => {
                let text = format!("版本列表获取失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));

                let fallback = serde_json::json!({
                    "source": source,
                    "latestRelease": "",
                    "latestSnapshot": "",
                    "gameVersions": [],
                    "fabricLoaders": [],
                    "quiltLoaders": [],
                    "forgeInstallers": [],
                    "neoforgeInstallers": [],
                    "warnings": [err.to_string()]
                })
                .to_string();

                self.as_mut()
                    .set_download_catalog_json(QString::from(&fallback));

                QString::from(&fallback)
            }
        }
    }

    pub fn start_refresh_download_catalog(mut self: Pin<&mut Self>, source: QString) {
        let requested_source = source.to_string();
        let settings = load_launcher_settings_value();
        apply_download_runtime_settings(&settings);
        let source = resolve_download_source(&settings, &requested_source, true);
        let status_path = download_catalog_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut().set_output(QString::from(
                "版本列表正在加载中。请等待当前刷新任务完成。",
            ));
            return;
        }

        write_download_catalog_task_status(
            &status_path,
            true,
            5,
            "正在获取版本列表",
            "正在连接版本源，界面不会卡死。",
            false,
            "",
        );

        self.as_mut().set_output(QString::from(
            "正在后台获取 Minecraft / Fabric / Quilt / Forge / NeoForge 版本列表。",
        ));

        thread::spawn(move || {
            write_download_catalog_task_status(
                &status_path,
                true,
                15,
                "正在获取原版版本清单",
                "正在请求 Mojang/BMCLAPI manifest。",
                false,
                "",
            );

            let result = DownloadService::fetch_catalog_json(&source);

            match result {
                Ok(json) => {
                    write_download_catalog_task_status(
                        &status_path,
                        false,
                        100,
                        "版本列表获取完成",
                        "版本列表已加载完成。",
                        true,
                        &json,
                    );
                }
                Err(err) => {
                    let fallback = serde_json::json!({
                        "source": source,
                        "latestRelease": "",
                        "latestSnapshot": "",
                        "gameVersions": [],
                        "fabricLoaders": [],
                        "quiltLoaders": [],
                        "forgeInstallers": [],
                        "neoforgeInstallers": [],
                        "warnings": [err.to_string()]
                    })
                    .to_string();

                    write_download_catalog_task_status(
                        &status_path,
                        false,
                        0,
                        "版本列表获取失败",
                        &err.to_string(),
                        true,
                        &fallback,
                    );
                }
            }
        });
    }

    pub fn poll_download_catalog_task(mut self: Pin<&mut Self>) -> QString {
        let path = download_catalog_task_status_path();
        let text = read_download_catalog_task_status_text(&path);

        if let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) {
            let title = value
                .get("title")
                .and_then(|value| value.as_str())
                .unwrap_or("版本列表");

            let message = value
                .get("message")
                .and_then(|value| value.as_str())
                .unwrap_or_default();

            if let Some(catalog_json) = value.get("catalogJson").and_then(|value| value.as_str()) {
                if !catalog_json.is_empty() {
                    self.as_mut()
                        .set_download_catalog_json(QString::from(catalog_json));
                }
            }

            if value
                .get("active")
                .and_then(|value| value.as_bool())
                .unwrap_or(false)
            {
                self.as_mut()
                    .set_output(QString::from(&format!("{title}\n\n{message}")));
            }
        }

        QString::from(&text)
    }

    pub fn start_fetch_installer_metadata(
        mut self: Pin<&mut Self>,
        source: QString,
        game_version: QString,
    ) {
        let requested_source = source.to_string();
        let game_version = game_version.to_string();

        if game_version.trim().is_empty() {
            self.as_mut()
                .set_output(QString::from("还没有选择 Minecraft 版本。"));
            return;
        }

        let settings = load_launcher_settings_value();
        apply_download_runtime_settings(&settings);
        let source = resolve_download_source(&settings, &requested_source, false);
        let status_path = installer_metadata_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut().set_output(QString::from(
                "安装器元数据正在加载中。请等待当前任务完成。",
            ));
            return;
        }

        write_installer_metadata_task_status(
            &status_path,
            true,
            5,
            "正在加载安装器列表",
            &format!("Minecraft {game_version}"),
            false,
            "",
        );

        self.as_mut().set_output(QString::from(&format!(
            "正在后台加载 Minecraft {game_version} 的 Fabric / Quilt / Forge / NeoForge 安装器列表。"
        )));

        thread::spawn(move || {
            write_installer_metadata_task_status(
                &status_path,
                true,
                30,
                "正在请求安装器元数据",
                "正在连接 Fabric / Quilt / Forge / NeoForge 元数据源。",
                false,
                "",
            );

            match DownloadService::fetch_installer_metadata_json(&source, &game_version) {
                Ok(json) => {
                    write_installer_metadata_task_status(
                        &status_path,
                        false,
                        100,
                        "安装器列表加载完成",
                        "可以选择加载器并开始安装。",
                        true,
                        &json,
                    );
                }
                Err(err) => {
                    let fallback = serde_json::json!({
                        "gameVersion": game_version,
                        "fabricLoaders": [],
                        "quiltLoaders": [],
                        "forgeInstallers": [],
                        "neoforgeInstallers": [],
                        "warnings": [err.to_string()]
                    })
                    .to_string();

                    write_installer_metadata_task_status(
                        &status_path,
                        false,
                        0,
                        "安装器列表加载失败",
                        &err.to_string(),
                        true,
                        &fallback,
                    );
                }
            }
        });
    }

    pub fn poll_installer_metadata_task(mut self: Pin<&mut Self>) -> QString {
        let path = installer_metadata_task_status_path();
        let text = read_installer_metadata_task_status_text(&path);

        if let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) {
            let title = value
                .get("title")
                .and_then(|value| value.as_str())
                .unwrap_or("安装器列表");

            let message = value
                .get("message")
                .and_then(|value| value.as_str())
                .unwrap_or_default();

            if value
                .get("active")
                .and_then(|value| value.as_bool())
                .unwrap_or(false)
            {
                self.as_mut()
                    .set_output(QString::from(&format!("{title}\n\n{message}")));
            }
        }

        QString::from(&text)
    }

    pub fn install_game_version(
        mut self: Pin<&mut Self>,
        source: QString,
        game_version: QString,
        loader_kind: QString,
        loader_version: QString,
    ) {
        let requested_source = source.to_string();
        let settings = load_launcher_settings_value();
        apply_download_runtime_settings(&settings);
        let source = resolve_download_source(&settings, &requested_source, false);
        let game_version = game_version.to_string();
        let loader_kind = loader_kind.to_string();
        let loader_version = loader_version.to_string();

        if game_version.trim().is_empty() {
            self.as_mut()
                .set_output(QString::from("安装失败：还没有选择 Minecraft 版本。"));
            return;
        }

        let status_path = download_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut().set_output(QString::from(
                "已经有下载任务在运行。可以先取消当前任务，再开始新的安装。",
            ));
            return;
        }

        let cancel_flag = download_cancel_flag();
        cancel_flag.store(false, Ordering::Relaxed);

        let title = format!("安装 Minecraft {game_version}");

        match launcher_core::download::DownloadManager::new(
            title.clone(),
            status_path.clone(),
            cancel_flag.clone(),
        ) {
            Ok(manager) => {
                let _ = manager.set_message(format!(
                    "准备安装。\n下载源: {source}\nMinecraft: {game_version}\n加载器: {loader_kind} {loader_version}"
                ));

                self.as_mut().set_download_task_json(QString::from(
                    &read_download_task_status_text(&status_path),
                ));

                self.as_mut().set_output(QString::from(&format!(
                    "下载任务已在后台开始。\n\n这次使用 DownloadManager 真实统计文件数、字节数、当前文件和速度，不再使用假进度 ticker。\n\n下载源: {source}\nMinecraft: {game_version}\n加载器: {loader_kind}\n加载器版本: {loader_version}"
                )));

                thread::spawn(move || {
                    let result = DownloadService::install_game_version_with_manager(
                        &manager,
                        &source,
                        &game_version,
                        &loader_kind,
                        &loader_version,
                    );

                    match result {
                        Ok(result) => {
                            let _ = launcher_core::select_version(&result.version_id);

                            let _ = manager.finish(format!(
                                "Minecraft: {}\n加载器: {} {}\n版本 ID: {}\n下载/写入文件数: {}\n安装位置:\n{}\n\n{}\n\n已自动设为当前启动版本。",
                                result.game_version,
                                result.loader_kind,
                                result.loader_version,
                                result.version_id,
                                result.downloaded_files,
                                result.install_dir.display(),
                                result.message,
                            ));
                        }
                        Err(err) => {
                            if cancel_flag.load(Ordering::Relaxed) {
                                let _ = manager.fail("下载已取消。");
                            } else {
                                let _ = manager.fail(format!("安装失败。\n\n{err}"));
                            }
                        }
                    }
                });
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("创建下载任务失败。\n\n{err}")));
            }
        }
    }

    pub fn poll_download_task(mut self: Pin<&mut Self>) -> QString {
        let path = download_task_status_path();
        let text = read_download_task_status_text(&path);

        self.as_mut().set_download_task_json(QString::from(&text));

        QString::from(&text)
    }

    pub fn cancel_download_task(mut self: Pin<&mut Self>) {
        download_cancel_flag().store(true, Ordering::Relaxed);

        let path = download_task_status_path();
        let text = read_download_task_status_text(&path);

        if let Ok(mut value) = serde_json::from_str::<serde_json::Value>(&text) {
            value["cancelled"] = serde_json::Value::Bool(true);
            value["active"] = serde_json::Value::Bool(true);
            value["status"] = serde_json::Value::String("cancelling".to_string());
            value["title"] = serde_json::Value::String("正在取消下载".to_string());
            value["message"] = serde_json::Value::String(
                "正在停止下载线程并清理本次任务写入的文件。旧任务真正退出前不会允许启动新下载。"
                    .to_string(),
            );
            value["speed"] = serde_json::Value::Number(0.into());

            let _ = fs::write(&path, value.to_string());

            self.as_mut()
                .set_download_task_json(QString::from(&value.to_string()));
        }

        self.as_mut().set_output(QString::from(
            "正在取消下载。旧下载线程真正退出前，不会允许启动新的下载任务。",
        ));
    }

    pub fn refresh_installed_versions(mut self: Pin<&mut Self>) -> QString {
        match launcher_core::installed_versions_json() {
            Ok(json) => {
                self.as_mut()
                    .set_installed_versions_json(QString::from(&json));

                if let Ok(value) = serde_json::from_str::<serde_json::Value>(&json) {
                    let selected = value
                        .get("selectedVersion")
                        .and_then(|value| value.as_str())
                        .unwrap_or_default();

                    self.as_mut()
                        .set_selected_game_version(QString::from(selected));
                }

                QString::from(&json)
            }
            Err(err) => {
                let json = serde_json::json!({
                    "selectedVersion": "",
                    "versions": [],
                    "error": err.to_string()
                })
                .to_string();

                self.as_mut()
                    .set_installed_versions_json(QString::from(&json));

                self.as_mut()
                    .set_output(QString::from(&format!("刷新已安装版本失败。\n\n{err}")));

                QString::from(&json)
            }
        }
    }

    pub fn select_game_version(mut self: Pin<&mut Self>, version_id: QString) {
        match launcher_core::select_version(&version_id.to_string()) {
            Ok(version_id) => {
                self.as_mut()
                    .set_selected_game_version(QString::from(&version_id));

                let _ = self.as_mut().refresh_installed_versions();

                self.as_mut()
                    .set_output(QString::from(&format!("已选择版本：{version_id}")));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("选择版本失败。\n\n{err}")));
            }
        }
    }

    pub fn delete_game_version(mut self: Pin<&mut Self>, version_id: QString) {
        let version_id = version_id.to_string();

        match launcher_core::delete_version(&version_id) {
            Ok(()) => {
                let _ = self.as_mut().refresh_installed_versions();

                self.as_mut()
                    .set_output(QString::from(&format!("已删除版本：{version_id}")));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("删除版本失败。\n\n{err}")));
            }
        }
    }

    pub fn generate_launch_command(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_core::generate_launch_command_json(&version_id) {
            Ok(json) => {
                self.as_mut()
                    .set_output(QString::from(&format!("启动命令已生成。\n\n{json}")));

                QString::from(&json)
            }
            Err(err) => {
                let json = serde_json::json!({
                    "error": err.to_string()
                })
                .to_string();

                self.as_mut()
                    .set_output(QString::from(&format!("生成启动命令失败。\n\n{err}")));

                QString::from(&json)
            }
        }
    }
}

fn download_cancel_flag() -> Arc<AtomicBool> {
    DOWNLOAD_CANCEL_FLAG
        .get_or_init(|| Arc::new(AtomicBool::new(false)))
        .clone()
}

fn resolve_download_source(
    settings: &serde_json::Value,
    requested_source: &str,
    for_version_list: bool,
) -> String {
    let requested = normalize_requested_download_source(requested_source);

    if requested != "auto" && requested != "default" && !requested.is_empty() {
        return requested;
    }

    let auto = launcher_setting_bool(settings, "autoChooseDownloadSource").unwrap_or(true);

    if auto {
        if for_version_list {
            let source = launcher_setting_string(settings, "versionListSource")
                .unwrap_or_else(|| "balanced".to_string());
            return normalize_requested_download_source(&source);
        }

        return "balanced".to_string();
    }

    let setting_key = if for_version_list {
        "versionListSource"
    } else {
        "downloadSource"
    };

    let source =
        launcher_setting_string(settings, setting_key).unwrap_or_else(|| "balanced".to_string());

    normalize_requested_download_source(&source)
}

fn normalize_requested_download_source(value: &str) -> String {
    match value.trim().to_ascii_lowercase().as_str() {
        "bmcl" | "bmclapi" | "mirror" => "bmcl".to_string(),
        "official" | "mojang" => "official".to_string(),
        "balanced" | "auto" | "" => "balanced".to_string(),
        _ => "balanced".to_string(),
    }
}

fn apply_download_runtime_settings(settings: &serde_json::Value) {
    let workers = resolve_download_workers(settings);

    // Rust 2024 下修改进程环境变量是 unsafe。
    // 这里在创建下载线程前写入，DownloadManager::new 会读取这些值。
    unsafe {
        std::env::set_var("MC_LAUNCHER_DOWNLOAD_WORKERS", workers.to_string());

        if let Some(dir_type) = launcher_setting_string(settings, "commonDirType") {
            if dir_type == "custom" {
                if let Some(dir) = launcher_setting_string(settings, "commonDirectory") {
                    if !dir.trim().is_empty() {
                        std::env::set_var("MC_LAUNCHER_COMMON_DIRECTORY", dir);
                    }
                }
            } else {
                std::env::remove_var("MC_LAUNCHER_COMMON_DIRECTORY");
            }
        }
    }
}

fn resolve_download_workers(settings: &serde_json::Value) -> usize {
    let auto = launcher_setting_bool(settings, "autoDownloadThreads").unwrap_or(true);

    if auto {
        return std::thread::available_parallelism()
            .map(|value| value.get().saturating_mul(2))
            .unwrap_or(6)
            .clamp(6, 64);
    }

    launcher_setting_u32(settings, "downloadThreads")
        .map(|value| value as usize)
        .unwrap_or(64)
        .clamp(1, 256)
}

fn download_catalog_task_status_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value)
                .join("mc-launcher")
                .join("download-catalog-task.json");
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join(".cache")
            .join("mc-launcher")
            .join("download-catalog-task.json");
    }

    std::env::temp_dir()
        .join("mc-launcher")
        .join("download-catalog-task.json")
}

fn read_download_catalog_task_status_text(path: &Path) -> String {
    read_status_text(
        path,
        &serde_json::json!({
            "active": false,
            "percent": 0,
            "title": "空闲",
            "message": "还没有版本列表刷新任务。",
            "catalogReady": false,
            "catalogJson": ""
        })
        .to_string(),
    )
}

fn write_download_catalog_task_status(
    path: &Path,
    active: bool,
    percent: u32,
    title: &str,
    message: &str,
    catalog_ready: bool,
    catalog_json: &str,
) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let payload = serde_json::json!({
        "active": active,
        "percent": percent.min(100),
        "title": title,
        "message": message,
        "catalogReady": catalog_ready,
        "catalogJson": catalog_json
    });

    let _ = fs::write(path, payload.to_string());
}

fn download_task_status_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value)
                .join("mc-launcher")
                .join("download-task.json");
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join(".cache")
            .join("mc-launcher")
            .join("download-task.json");
    }

    std::env::temp_dir()
        .join("mc-launcher")
        .join("download-task.json")
}

fn read_download_task_status_text(path: &Path) -> String {
    read_status_text(
        path,
        &serde_json::json!({
            "active": false,
            "percent": 0,
            "title": "空闲",
            "message": "还没有下载任务。"
        })
        .to_string(),
    )
}


fn installer_metadata_task_status_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value)
                .join("mc-launcher")
                .join("installer-metadata-task.json");
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join(".cache")
            .join("mc-launcher")
            .join("installer-metadata-task.json");
    }

    std::env::temp_dir()
        .join("mc-launcher")
        .join("installer-metadata-task.json")
}

fn read_installer_metadata_task_status_text(path: &Path) -> String {
    read_status_text(
        path,
        &serde_json::json!({
            "active": false,
            "percent": 0,
            "title": "空闲",
            "message": "还没有安装器元数据任务。",
            "metadataReady": false,
            "metadataJson": ""
        })
        .to_string(),
    )
}

fn write_installer_metadata_task_status(
    path: &Path,
    active: bool,
    percent: u32,
    title: &str,
    message: &str,
    metadata_ready: bool,
    metadata_json: &str,
) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let payload = serde_json::json!({
        "active": active,
        "percent": percent.min(100),
        "title": title,
        "message": message,
        "metadataReady": metadata_ready,
        "metadataJson": metadata_json
    });

    let _ = fs::write(path, payload.to_string());
}
