#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");

        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, output)]
        #[qproperty(QString, current_account_name, cxx_name = "currentAccountName")]
        #[qproperty(QString, current_account_kind, cxx_name = "currentAccountKind")]
        #[qproperty(QString, current_account_avatar_url, cxx_name = "currentAccountAvatarUrl")]
        #[qproperty(QString, accounts_json, cxx_name = "accountsJson")]
        #[qproperty(QString, pending_yggdrasil_profiles_json, cxx_name = "pendingYggdrasilProfilesJson")]
        #[qproperty(QString, download_catalog_json, cxx_name = "downloadCatalogJson")]
        #[qproperty(QString, download_task_json, cxx_name = "downloadTaskJson")]
        #[qproperty(QString, installed_versions_json, cxx_name = "installedVersionsJson")]
        #[qproperty(QString, selected_game_version, cxx_name = "selectedGameVersion")]
        #[qproperty(QString, launch_task_json, cxx_name = "launchTaskJson")]
        #[qproperty(QString, launcher_settings_json, cxx_name = "launcherSettingsJson")]
        #[namespace = "launcher_backend"]
        type LauncherBackend = super::LauncherBackendRust;

        #[qinvokable]
        #[cxx_name = "detectJava"]
        fn detect_java(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "downloadJava"]
        fn download_java(
            self: Pin<&mut LauncherBackend>,
            distribution: QString,
            major: QString,
            package_type: QString,
        );

        #[qinvokable]
        #[cxx_name = "loginOffline"]
        fn login_offline(self: Pin<&mut LauncherBackend>, username: QString);

        #[qinvokable]
        #[cxx_name = "loginYggdrasil"]
        fn login_yggdrasil(
            self: Pin<&mut LauncherBackend>,
            server_url: QString,
            username: QString,
            password: QString,
        );

        #[qinvokable]
        #[cxx_name = "loginMicrosoftBrowser"]
        fn login_microsoft_browser(self: Pin<&mut LauncherBackend>, client_id: QString);

        #[qinvokable]
        #[cxx_name = "selectYggdrasilProfile"]
        fn select_yggdrasil_profile(self: Pin<&mut LauncherBackend>, index: QString);

        #[qinvokable]
        #[cxx_name = "refreshAccounts"]
        fn refresh_accounts(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "switchAccount"]
        fn switch_account(self: Pin<&mut LauncherBackend>, index: QString);

        #[qinvokable]
        #[cxx_name = "deleteAccount"]
        fn delete_account(self: Pin<&mut LauncherBackend>, index: QString);

        #[qinvokable]
        #[cxx_name = "refreshDownloadCatalog"]
        fn refresh_download_catalog(self: Pin<&mut LauncherBackend>, source: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "startRefreshDownloadCatalog"]
        fn start_refresh_download_catalog(self: Pin<&mut LauncherBackend>, source: QString);

        #[qinvokable]
        #[cxx_name = "pollDownloadCatalogTask"]
        fn poll_download_catalog_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "installGameVersion"]
        fn install_game_version(
            self: Pin<&mut LauncherBackend>,
            source: QString,
            game_version: QString,
            loader_kind: QString,
            loader_version: QString,
        );

        #[qinvokable]
        #[cxx_name = "pollDownloadTask"]
        fn poll_download_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "cancelDownloadTask"]
        fn cancel_download_task(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "refreshInstalledVersions"]
        fn refresh_installed_versions(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "selectGameVersion"]
        fn select_game_version(self: Pin<&mut LauncherBackend>, version_id: QString);

        #[qinvokable]
        #[cxx_name = "deleteGameVersion"]
        fn delete_game_version(self: Pin<&mut LauncherBackend>, version_id: QString);

        #[qinvokable]
        #[cxx_name = "launchSelectedVersion"]
        fn launch_selected_version(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "startLaunchSelectedVersion"]
        fn start_launch_selected_version(self: Pin<&mut LauncherBackend>, visibility: QString);

        #[qinvokable]
        #[cxx_name = "cancelLaunchTask"]
        fn cancel_launch_task(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "pollLaunchTask"]
        fn poll_launch_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "refreshLauncherSettings"]
        fn refresh_launcher_settings(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "updateLauncherSetting"]
        fn update_launcher_setting(self: Pin<&mut LauncherBackend>, key: QString, value: QString);

        #[qinvokable]
        #[cxx_name = "generateLaunchCommand"]
        fn generate_launch_command(self: Pin<&mut LauncherBackend>, version_id: QString) -> QString;
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;
use launcher_core::AuthAccount;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[derive(Default)]
pub struct LauncherBackendRust {
    output: QString,
    current_account_name: QString,
    current_account_kind: QString,
    current_account_avatar_url: QString,
    accounts_json: QString,
    pending_yggdrasil_profiles_json: QString,
    download_catalog_json: QString,
    download_task_json: QString,
    installed_versions_json: QString,
    selected_game_version: QString,
    launch_task_json: QString,
    launcher_settings_json: QString,
}

impl qobject::LauncherBackend {
    pub fn detect_java(mut self: Pin<&mut Self>) {
        let runtimes = launcher_core::detect_java_runtimes();

        let text = if runtimes.is_empty() {
            "No Java runtime found.".to_string()
        } else {
            let mut text = String::from("Detected Java runtimes:\n\n");

            for runtime in runtimes {
                let version = runtime.version.as_deref().unwrap_or("unknown");
                let major = runtime
                    .major
                    .map(|major| major.to_string())
                    .unwrap_or_else(|| "unknown".to_string());

                text.push_str(&format!("- {}\n", runtime.executable.display()));
                text.push_str(&format!("  version: {version}\n"));
                text.push_str(&format!("  major: {major}\n"));

                if let Some(vendor) = runtime.vendor_hint {
                    text.push_str(&format!("  vendor: {vendor}\n"));
                }

                text.push('\n');
            }

            text
        };

        self.as_mut().set_output(QString::from(&text));
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
            }
            Err(err) => {
                let text = format!(
                    "Java 下载失败。\n\n发行版: {distribution}\n版本: Java {major}\n包类型: {package_type}\n\n{err}"
                );

                self.as_mut().set_output(QString::from(&text));
            }
        }
    }

    pub fn login_offline(mut self: Pin<&mut Self>, username: QString) {
        match launcher_core::login_offline(&username.to_string()).and_then(|account| {
            let path = launcher_core::save_account(&account)?;
            Ok((account, path))
        }) {
            Ok((account, path)) => {
                set_current_account(self.as_mut(), &account);
                refresh_accounts_property(self.as_mut());

                self.as_mut().set_output(QString::from(&format!(
                    "离线账户添加完成，并已切换到该账户。\n\n玩家名: {}\nUUID: {}\n账户文件:\n{}",
                    account.username,
                    account.uuid,
                    path.display()
                )));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("离线账户添加失败。\n\n{err}")));
            }
        }
    }

    pub fn login_yggdrasil(
        mut self: Pin<&mut Self>,
        server_url: QString,
        username: QString,
        password: QString,
    ) {
        let server_url = server_url.to_string();
        let username = username.to_string();
        let password = password.to_string();

        self.as_mut().set_output(QString::from(&format!(
            "正在登录第三方服务器...\n\n服务器: {server_url}\n用户名: {username}"
        )));

        match launcher_core::login_yggdrasil_start(&server_url, &username, &password) {
            Ok(launcher_core::YggdrasilLoginResult::Account(account)) => {
                match launcher_core::save_account(&account) {
                    Ok(path) => {
                        clear_pending_yggdrasil_login();
                        self.as_mut()
                            .set_pending_yggdrasil_profiles_json(QString::from(""));
                        set_current_account(self.as_mut(), &account);
                        refresh_accounts_property(self.as_mut());

                        self.as_mut().set_output(QString::from(&format!(
                            "第三方服务器登录完成，并已切换到该账户。\n\n服务器: {}\n角色名: {}\nUUID: {}\n账户文件:\n{}",
                            account.server_url.as_deref().unwrap_or("unknown"),
                            account.username,
                            account.uuid,
                            path.display()
                        )));
                    }
                    Err(err) => {
                        self.as_mut()
                            .set_output(QString::from(&format!("保存第三方账户失败。\n\n{err}")));
                    }
                }
            }
            Ok(launcher_core::YggdrasilLoginResult::Pending(pending)) => {
                if pending.profiles.len() == 1 {
                    match launcher_core::complete_yggdrasil_login(&pending, 0)
                        .and_then(|account| {
                            let path = launcher_core::save_account(&account)?;
                            Ok((account, path))
                        }) {
                        Ok((account, path)) => {
                            clear_pending_yggdrasil_login();
                            self.as_mut()
                                .set_pending_yggdrasil_profiles_json(QString::from(""));
                            set_current_account(self.as_mut(), &account);
                            refresh_accounts_property(self.as_mut());
                            self.as_mut().set_output(QString::from(&format!(
                                "第三方服务器登录完成，并已切换到唯一角色。\n\n角色名: {}\nUUID: {}\n账户文件:\n{}",
                                account.username,
                                account.uuid,
                                path.display()
                            )));
                        }
                        Err(err) => {
                            self.as_mut().set_output(QString::from(&format!(
                                "第三方服务器选择角色失败。\n\n{err}"
                            )));
                        }
                    }
                } else {
                    let profiles = pending
                        .profiles
                        .iter()
                        .map(|profile| {
                            let avatar_url = launcher_core::yggdrasil_profile_avatar_url(
                                &pending.server_url,
                                &profile.id,
                                96,
                            )
                            .ok()
                            .flatten()
                            .unwrap_or_default();

                            serde_json::json!({
                                "id": profile.id,
                                "name": profile.name,
                                "avatarUrl": avatar_url,
                            })
                        })
                        .collect::<Vec<_>>();

                    let json = serde_json::json!({
                        "serverUrl": pending.server_url,
                        "username": pending.username,
                        "profiles": profiles,
                    })
                    .to_string();

                    if let Err(err) = write_pending_yggdrasil_login(&pending) {
                        self.as_mut().set_output(QString::from(&format!(
                            "保存第三方角色选择状态失败。\n\n{err}"
                        )));
                        return;
                    }

                    self.as_mut()
                        .set_pending_yggdrasil_profiles_json(QString::from(&json));

                    self.as_mut().set_output(QString::from(&format!(
                        "该第三方账户有多个角色，请在弹出的角色选择框中选择一个。\n\n服务器: {}\n登录用户: {}\n角色数量: {}",
                        pending.server_url,
                        pending.username,
                        pending.profiles.len()
                    )));
                }
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("第三方服务器登录失败。\n\n{err}")));
            }
        }
    }


    pub fn select_yggdrasil_profile(mut self: Pin<&mut Self>, index: QString) {
        let index = match index.to_string().parse::<usize>() {
            Ok(value) => value,
            Err(err) => {
                self.as_mut().set_output(QString::from(&format!(
                    "选择第三方角色失败：无效索引。\n\n{err}"
                )));
                return;
            }
        };

        let pending = match read_pending_yggdrasil_login() {
            Ok(pending) => pending,
            Err(err) => {
                self.as_mut().set_output(QString::from(&format!(
                    "读取第三方角色选择状态失败。\n\n{err}"
                )));
                return;
            }
        };

        match launcher_core::complete_yggdrasil_login(&pending, index).and_then(|account| {
            let path = launcher_core::save_account(&account)?;
            Ok((account, path))
        }) {
            Ok((account, path)) => {
                clear_pending_yggdrasil_login();
                self.as_mut()
                    .set_pending_yggdrasil_profiles_json(QString::from(""));
                set_current_account(self.as_mut(), &account);
                refresh_accounts_property(self.as_mut());

                self.as_mut().set_output(QString::from(&format!(
                    "第三方角色选择完成，并已切换到该账户。\n\n服务器: {}\n角色名: {}\nUUID: {}\n账户文件:\n{}",
                    account.server_url.as_deref().unwrap_or("unknown"),
                    account.username,
                    account.uuid,
                    path.display()
                )));
            }
            Err(err) => {
                self.as_mut().set_output(QString::from(&format!(
                    "第三方角色选择失败。\n\n{err}"
                )));
            }
        }
    }

    pub fn login_microsoft_browser(mut self: Pin<&mut Self>, client_id: QString) {
        self.as_mut().set_output(QString::from(
            "正在打开浏览器进行 Microsoft 登录。\n\n授权完成后浏览器会跳回本地启动器回调地址。",
        ));

        match launcher_core::login_microsoft_browser(&client_id.to_string()).and_then(|account| {
            let path = launcher_core::save_account(&account)?;
            Ok((account, path))
        }) {
            Ok((account, path)) => {
                set_current_account(self.as_mut(), &account);
                refresh_accounts_property(self.as_mut());

                self.as_mut().set_output(QString::from(&format!(
                    "微软账户登录完成，并已切换到该账户。\n\n角色名: {}\nUUID: {}\n{}\n\n账户文件:\n{}",
                    account.username,
                    account.uuid,
                    account.note.unwrap_or_default(),
                    path.display()
                )));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("微软账户登录失败。\n\n{err}")));
            }
        }
    }

    pub fn refresh_accounts(mut self: Pin<&mut Self>) -> QString {
        match launcher_core::load_accounts() {
            Ok(accounts) => {
                let json = accounts_public_json(&accounts);
                self.as_mut().set_accounts_json(QString::from(&json));

                if accounts.is_empty() {
                    clear_current_account(self.as_mut());
                } else if let Ok(Some(account)) = launcher_core::selected_account() {
                    set_current_account(self.as_mut(), &account);
                }

                QString::from(&json)
            }
            Err(err) => {
                let json = serde_json::json!({
                    "accounts": [],
                    "error": err.to_string()
                })
                .to_string();

                self.as_mut().set_accounts_json(QString::from(&json));
                self.as_mut()
                    .set_output(QString::from(&format!("读取账户列表失败。\n\n{err}")));

                QString::from(&json)
            }
        }
    }

    pub fn switch_account(mut self: Pin<&mut Self>, index: QString) {
        let index = match index.to_string().parse::<usize>() {
            Ok(value) => value,
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("切换账户失败：无效索引。\n\n{err}")));
                return;
            }
        };

        match launcher_core::load_accounts() {
            Ok(accounts) => {
                let Some(account) = accounts.get(index) else {
                    self.as_mut()
                        .set_output(QString::from("切换账户失败：账户索引不存在。"));
                    return;
                };

                if let Err(err) = launcher_core::select_account(account) {
                    self.as_mut()
                        .set_output(QString::from(&format!("切换账户失败：无法保存选择。\n\n{err}")));
                    return;
                }

                set_current_account(self.as_mut(), account);
                refresh_accounts_property(self.as_mut());
                self.as_mut().set_output(QString::from(&format!(
                    "已切换账户。\n\n账户: {}\n类型: {}\nUUID: {}",
                    account.username,
                    display_account_kind(&account.kind),
                    account.uuid
                )));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("切换账户失败。\n\n{err}")));
            }
        }
    }

    pub fn delete_account(mut self: Pin<&mut Self>, index: QString) {
        let index = match index.to_string().parse::<usize>() {
            Ok(value) => value,
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("删除账户失败：无效索引。\n\n{err}")));
                return;
            }
        };

        match launcher_core::load_accounts() {
            Ok(accounts) => {
                let Some(account) = accounts.get(index) else {
                    self.as_mut()
                        .set_output(QString::from("删除账户失败：账户索引不存在。"));
                    return;
                };

                let deleted_name = account.username.clone();
                let deleted_kind = account.kind.clone();
                let deleted_uuid = account.uuid.clone();
                let deleted_server = account.server_url.clone();

                match launcher_core::delete_account(
                    &deleted_kind,
                    &deleted_uuid,
                    deleted_server.as_deref(),
                ) {
                    Ok(accounts) => {
                        let json = accounts_public_json(&accounts);
                        self.as_mut().set_accounts_json(QString::from(&json));

                        if let Some(first) = accounts.first() {
                            set_current_account(self.as_mut(), first);
                        } else {
                            clear_current_account(self.as_mut());
                        }

                        self.as_mut().set_output(QString::from(&format!(
                            "已删除账户：{deleted_name}"
                        )));
                    }
                    Err(err) => {
                        self.as_mut()
                            .set_output(QString::from(&format!("删除账户失败。\n\n{err}")));
                    }
                }
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("删除账户失败。\n\n{err}")));
            }
        }
    }

    pub fn refresh_download_catalog(
        mut self: Pin<&mut Self>,
        source: QString,
    ) -> QString {
        let source = source.to_string();

        self.as_mut().set_output(QString::from(
            "正在获取 Minecraft / Fabric / Quilt / Forge / NeoForge 版本列表...",
        ));

        match launcher_core::fetch_download_catalog_json(&source) {
            Ok(json) => {
                self.as_mut().set_download_catalog_json(QString::from(&json));
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
                }).to_string();

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

        if download_task_is_active(&status_path) {
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

            let result = launcher_core::fetch_download_catalog_json(&source);

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

        if download_task_is_active(&status_path) {
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
                    let result = launcher_core::install_game_version_with_manager(
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

        self.as_mut()
            .set_download_task_json(QString::from(&text));

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
            value["message"] = serde_json::Value::String("正在停止下载线程并清理本次任务写入的文件。旧任务真正退出前不会允许启动新下载。".to_string());
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
            let check_cancelled = |stage: &str, title: &str, status_path: &Path, launch_id: &str, visibility: &str| -> bool {
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

            if check_cancelled("launch.state.java", "检测 Java 版本", &status_path, &launch_id, &visibility) {
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

            if check_cancelled("launch.state.dependencies", "检查游戏文件完整性", &status_path, &launch_id, &visibility) {
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

            if check_cancelled("launch.state.dependencies", "检查资源文件", &status_path, &launch_id, &visibility) {
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

            if check_cancelled("launch.state.dependencies", "检查依赖库", &status_path, &launch_id, &visibility) {
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

            if check_cancelled("launch.state.dependencies", "解压本地库", &status_path, &launch_id, &visibility) {
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

            if check_cancelled("launch.state.logging_in", "登录", &status_path, &launch_id, &visibility) {
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

            if check_cancelled("launch.state.waiting_launching", "启动游戏", &status_path, &launch_id, &visibility) {
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
            options.max_memory_mb = launcher_setting_u32(&settings, "maxMemoryMb").or(options.max_memory_mb);
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
        let mut value = serde_json::from_str::<serde_json::Value>(&read_launch_task_status_text(&path))
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

        self.as_mut()
            .set_launch_task_json(QString::from(&text));

        QString::from(&text)
    }



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


static DOWNLOAD_CANCEL_FLAG: OnceLock<Arc<AtomicBool>> = OnceLock::new();
static LAUNCH_CANCEL_FLAG: OnceLock<Arc<AtomicBool>> = OnceLock::new();

fn download_cancel_flag() -> Arc<AtomicBool> {
    DOWNLOAD_CANCEL_FLAG
        .get_or_init(|| Arc::new(AtomicBool::new(false)))
        .clone()
}






fn resolve_download_source(settings: &serde_json::Value, requested_source: &str, for_version_list: bool) -> String {
    let auto = launcher_setting_bool(settings, "autoChooseDownloadSource").unwrap_or(true);

    if auto {
        let source = launcher_setting_string(settings, "versionListSource")
            .unwrap_or_else(|| "balanced".to_string());

        return match source.as_str() {
            // HMCL DEFAULT_AUTO_PROVIDER_ID = "balanced"。
            // 中国大陆时 balanced 默认走 BMCLAPI；这里按中文环境直接走 bmcl。
            "" | "auto" | "balanced" => "balanced".to_string(),

            // HMCL 的 official auto provider 偏向官方列表。
            "official" | "mojang" => {
                if for_version_list {
                    "official".to_string()
                } else {
                    "balanced".to_string()
                }
            }

            // HMCL mirror 对应镜像优先。
            "mirror" | "bmcl" | "bmclapi" => "mirror".to_string(),

            _ => "balanced".to_string(),
        };
    }

    let source = launcher_setting_string(settings, "downloadSource")
        .unwrap_or_else(|| requested_source.to_string());

    match source.as_str() {
        "bmcl" | "bmclapi" | "mirror" => "bmcl".to_string(),
        "official" | "mojang" => "official".to_string(),
        "" | "auto" => normalize_requested_download_source(requested_source),
        _ => normalize_requested_download_source(requested_source),
    }
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

fn launcher_settings_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CONFIG_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value).join("mc-launcher").join("settings.json");
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
        "downloadSource": "mojang",
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

fn load_launcher_settings_value() -> serde_json::Value {
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

fn save_launcher_settings_value(value: &serde_json::Value) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
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
        "minMemoryMb"
        | "maxMemoryMb"
        | "gameWidth"
        | "gameHeight"
        | "downloadThreads"
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

fn launcher_setting_u32(settings: &serde_json::Value, key: &str) -> Option<u32> {
    settings
        .get(key)
        .and_then(|value| {
            value
                .as_u64()
                .and_then(|value| u32::try_from(value).ok())
                .or_else(|| value.as_str().and_then(|value| value.parse::<u32>().ok()))
        })
}

fn launcher_setting_bool(settings: &serde_json::Value, key: &str) -> Option<bool> {
    settings
        .get(key)
        .and_then(|value| {
            value
                .as_bool()
                .or_else(|| value.as_str().map(|value| value == "true"))
        })
}

fn launcher_setting_string(settings: &serde_json::Value, key: &str) -> Option<String> {
    settings
        .get(key)
        .and_then(|value| value.as_str())
        .map(ToString::to_string)
}

fn pending_yggdrasil_login_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value)
                .join("mc-launcher")
                .join("pending-yggdrasil-login.json");
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join(".cache")
            .join("mc-launcher")
            .join("pending-yggdrasil-login.json");
    }

    std::env::temp_dir()
        .join("mc-launcher")
        .join("pending-yggdrasil-login.json")
}

fn write_pending_yggdrasil_login(
    pending: &launcher_core::YggdrasilPendingLogin,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let path = pending_yggdrasil_login_path();

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string_pretty(pending)?)?;
    Ok(())
}

fn read_pending_yggdrasil_login(
) -> Result<launcher_core::YggdrasilPendingLogin, Box<dyn std::error::Error + Send + Sync + 'static>> {
    let path = pending_yggdrasil_login_path();
    let text = fs::read_to_string(path)?;
    Ok(serde_json::from_str(&text)?)
}

fn clear_pending_yggdrasil_login() {
    let _ = fs::remove_file(pending_yggdrasil_login_path());
}


fn launch_cancel_flag() -> Arc<AtomicBool> {
    LAUNCH_CANCEL_FLAG
        .get_or_init(|| Arc::new(AtomicBool::new(false)))
        .clone()
}

#[allow(clippy::too_many_arguments)]
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
        .and_then(|value| value.get("active").and_then(|value| value.as_bool()).map(bool::from))
        .unwrap_or(false)
}

#[allow(clippy::too_many_arguments)]
#[allow(dead_code)]
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
    fs::read_to_string(path).unwrap_or_else(|_| {
        serde_json::json!({
            "active": false,
            "percent": 0,
            "title": "空闲",
            "message": "还没有版本列表刷新任务。",
            "catalogReady": false,
            "catalogJson": ""
        })
        .to_string()
    })
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
    fs::read_to_string(path).unwrap_or_else(|_| {
        serde_json::json!({
            "active": false,
            "percent": 0,
            "title": "空闲",
            "message": "还没有下载任务。"
        })
        .to_string()
    })
}

fn download_task_is_active(path: &Path) -> bool {
    let Ok(text) = fs::read_to_string(path) else {
        return false;
    };

    serde_json::from_str::<serde_json::Value>(&text)
        .ok()
        .and_then(|value| value.get("active").and_then(|value| value.as_bool()).map(bool::from))
        .unwrap_or(false)
}

fn refresh_accounts_property(mut qobject: Pin<&mut qobject::LauncherBackend>) {
    if let Ok(accounts) = launcher_core::load_accounts() {
        qobject
            .as_mut()
            .set_accounts_json(QString::from(&accounts_public_json(&accounts)));

        if accounts.is_empty() {
            clear_current_account(qobject.as_mut());
        } else if let Ok(Some(account)) = launcher_core::selected_account() {
            set_current_account(qobject.as_mut(), &account);
        }
    }
}

fn set_current_account(mut qobject: Pin<&mut qobject::LauncherBackend>, account: &AuthAccount) {
    let _ = launcher_core::select_account(account);

    qobject
        .as_mut()
        .set_current_account_name(QString::from(&account.username));

    qobject
        .as_mut()
        .set_current_account_kind(QString::from(&display_account_kind(&account.kind)));

    qobject
        .as_mut()
        .set_current_account_avatar_url(QString::from(&avatar_url_for_account(account)));
}

fn clear_current_account(mut qobject: Pin<&mut qobject::LauncherBackend>) {
    qobject
        .as_mut()
        .set_current_account_name(QString::from(""));

    qobject
        .as_mut()
        .set_current_account_kind(QString::from(""));

    qobject
        .as_mut()
        .set_current_account_avatar_url(QString::from(""));
}

fn accounts_public_json(accounts: &[AuthAccount]) -> String {
    let values = accounts
        .iter()
        .map(|account| {
            serde_json::json!({
                "username": account.username,
                "uuid": account.uuid,
                "kind": account.kind,
                "displayKind": display_account_kind(&account.kind),
                "serverUrl": account.server_url,
                "avatarUrl": avatar_url_for_account(account),
                "note": account.note,
                "identifier": launcher_core::account_identifier(account),
                "selected": launcher_core::selected_account()
                    .ok()
                    .flatten()
                    .map(|selected| launcher_core::account_identifier(&selected) == launcher_core::account_identifier(account))
                    .unwrap_or(false),
            })
        })
        .collect::<Vec<_>>();

    serde_json::json!({
        "accounts": values
    })
    .to_string()
}

fn display_account_kind(kind: &str) -> String {
    match kind {
        "offline" => "离线账户".to_string(),
        "microsoft" => "Microsoft".to_string(),
        "yggdrasil" => "第三方服务器".to_string(),
        other => other.to_string(),
    }
}

fn avatar_url_for_account(account: &AuthAccount) -> String {
    launcher_core::account_avatar_url(account, 96)
        .ok()
        .flatten()
        .unwrap_or_default()
}
