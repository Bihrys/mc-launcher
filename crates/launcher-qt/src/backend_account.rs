use crate::backend::qobject;
use crate::json_models::{accounts_public_json, avatar_url_for_account, display_account_kind};
use crate::task_bridge::{read_status_text, task_status_is_active};
use core::pin::Pin;
use cxx_qt_lib::QString;
use launcher_core::{Account as AuthAccount, AccountService};
use std::fs;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};

impl qobject::LauncherBackend {
    pub fn login_offline(mut self: Pin<&mut Self>, username: QString) {
        match AccountService::login_offline(&username.to_string()).and_then(|account| {
            let path = AccountService::save(&account)?;
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
        let status_path = yggdrasil_login_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut()
                .set_output(QString::from("第三方账户登录任务正在执行中。"));
            return;
        }

        write_yggdrasil_login_task_status(
            &status_path,
            true,
            "正在登录第三方服务器",
            &format!("服务器: {server_url}\n用户名: {username}"),
            false,
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        );

        self.as_mut().set_output(QString::from(&format!(
            "正在后台登录第三方服务器...\n\n服务器: {server_url}\n用户名: {username}"
        )));

        thread::spawn(move || {
            match AccountService::login_yggdrasil_start(&server_url, &username, &password) {
                Ok(launcher_core::YggdrasilLoginResult::Account(account)) => {
                    match AccountService::save(&account).and_then(|path| {
                        AccountService::select_account(&account)?;
                        Ok(path)
                    }) {
                        Ok(path) => {
                            clear_pending_yggdrasil_login();

                            let accounts = AccountService::list().unwrap_or_default();
                            let accounts_json = accounts_public_json(&accounts);
                            let kind = display_account_kind(&account.kind);
                            let avatar = avatar_url_for_account(&account);

                            write_yggdrasil_login_task_status(
                                &status_path,
                                false,
                                "第三方服务器登录完成",
                                "第三方账户已保存并切换为当前账户。",
                                true,
                                &accounts_json,
                                "",
                                &account.username,
                                &kind,
                                &avatar,
                                &format!(
                                    "第三方服务器登录完成，并已切换到该账户。\n\n服务器: {}\n角色名: {}\nUUID: {}\n账户文件:\n{}",
                                    account.server_url.as_deref().unwrap_or("unknown"),
                                    account.username,
                                    account.uuid,
                                    path.display()
                                ),
                                "",
                            );
                        }
                        Err(err) => {
                            write_yggdrasil_login_task_status(
                                &status_path,
                                false,
                                "保存第三方账户失败",
                                &err.to_string(),
                                false,
                                "",
                                "",
                                "",
                                "",
                                "",
                                "",
                                &err.to_string(),
                            );
                        }
                    }
                }
                Ok(launcher_core::YggdrasilLoginResult::Pending(pending)) => {
                    if pending.profiles.len() == 1 {
                        match AccountService::complete_yggdrasil_login(&pending, 0).and_then(
                            |account| {
                                let path = AccountService::save(&account)?;
                                AccountService::select_account(&account)?;
                                Ok((account, path))
                            },
                        ) {
                            Ok((account, path)) => {
                                clear_pending_yggdrasil_login();

                                let accounts = AccountService::list().unwrap_or_default();
                                let accounts_json = accounts_public_json(&accounts);
                                let kind = display_account_kind(&account.kind);
                                let avatar = avatar_url_for_account(&account);

                                write_yggdrasil_login_task_status(
                                    &status_path,
                                    false,
                                    "第三方服务器登录完成",
                                    "第三方账户只有一个角色，已自动选择。",
                                    true,
                                    &accounts_json,
                                    "",
                                    &account.username,
                                    &kind,
                                    &avatar,
                                    &format!(
                                        "第三方服务器登录完成，并已切换到唯一角色。\n\n角色名: {}\nUUID: {}\n账户文件:\n{}",
                                        account.username,
                                        account.uuid,
                                        path.display()
                                    ),
                                    "",
                                );
                            }
                            Err(err) => {
                                write_yggdrasil_login_task_status(
                                    &status_path,
                                    false,
                                    "第三方服务器选择角色失败",
                                    &err.to_string(),
                                    false,
                                    "",
                                    "",
                                    "",
                                    "",
                                    "",
                                    "",
                                    &err.to_string(),
                                );
                            }
                        }
                    } else {
                        let profiles = pending
                            .profiles
                            .iter()
                            .map(|profile| {
                                let avatar_url = AccountService::yggdrasil_profile_avatar_url(
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

                        let pending_json = serde_json::json!({
                            "serverUrl": pending.server_url,
                            "username": pending.username,
                            "profiles": profiles,
                        })
                        .to_string();

                        if let Err(err) = write_pending_yggdrasil_login(&pending) {
                            write_yggdrasil_login_task_status(
                                &status_path,
                                false,
                                "保存第三方角色选择状态失败",
                                &err.to_string(),
                                false,
                                "",
                                "",
                                "",
                                "",
                                "",
                                "",
                                &err.to_string(),
                            );
                            return;
                        }

                        write_yggdrasil_login_task_status(
                            &status_path,
                            false,
                            "需要选择第三方角色",
                            "该第三方账户有多个角色，请选择一个。",
                            true,
                            "",
                            &pending_json,
                            "",
                            "",
                            "",
                            &format!(
                                "该第三方账户有多个角色，请在弹出的角色选择框中选择一个。\n\n服务器: {}\n登录用户: {}\n角色数量: {}",
                                pending.server_url,
                                pending.username,
                                pending.profiles.len()
                            ),
                            "",
                        );
                    }
                }
                Err(err) => {
                    write_yggdrasil_login_task_status(
                        &status_path,
                        false,
                        "第三方服务器登录失败",
                        &err.to_string(),
                        false,
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                }
            }
        });
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

        match AccountService::complete_yggdrasil_login(&pending, index).and_then(|account| {
            let path = AccountService::save(&account)?;
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
                self.as_mut()
                    .set_output(QString::from(&format!("第三方角色选择失败。\n\n{err}")));
            }
        }
    }


    pub fn poll_yggdrasil_login_task(mut self: Pin<&mut Self>) -> QString {
        let status_path = yggdrasil_login_task_status_path();
        let text = read_yggdrasil_login_task_status_text(&status_path);

        let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) else {
            return QString::from(&text);
        };

        let active = value
            .get("active")
            .and_then(|value| value.as_bool())
            .unwrap_or(false);

        if !active {
            let accounts_json = value
                .get("accountsJson")
                .and_then(|value| value.as_str())
                .unwrap_or_default();

            if !accounts_json.is_empty() {
                self.as_mut()
                    .set_accounts_json(QString::from(accounts_json));
            }

            let pending_profiles_json = value
                .get("pendingProfilesJson")
                .and_then(|value| value.as_str())
                .unwrap_or_default();

            self.as_mut()
                .set_pending_yggdrasil_profiles_json(QString::from(pending_profiles_json));

            let current_name = value
                .get("currentAccountName")
                .and_then(|value| value.as_str())
                .unwrap_or_default();

            if !current_name.is_empty() {
                self.as_mut()
                    .set_current_account_name(QString::from(current_name));

                self.as_mut().set_current_account_kind(QString::from(
                    value.get("currentAccountKind")
                        .and_then(|value| value.as_str())
                        .unwrap_or_default(),
                ));

                self.as_mut()
                    .set_current_account_avatar_url(QString::from(
                        value.get("currentAccountAvatarUrl")
                            .and_then(|value| value.as_str())
                            .unwrap_or_default(),
                    ));
            }

            let output = value
                .get("output")
                .and_then(|value| value.as_str())
                .unwrap_or_default();

            if !output.is_empty() {
                self.as_mut().set_output(QString::from(output));
            }
        }

        QString::from(&text)
    }

    pub fn login_microsoft_browser(mut self: Pin<&mut Self>, client_id: QString) {
        self.as_mut().set_output(QString::from(
            "正在打开浏览器进行 Microsoft 登录。\n\n授权完成后浏览器会跳回本地启动器回调地址。",
        ));

        match AccountService::login_microsoft_browser(&client_id.to_string()).and_then(|account| {
            let path = AccountService::save(&account)?;
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
        match AccountService::list() {
            Ok(accounts) => {
                let json = accounts_public_json(&accounts);
                self.as_mut().set_accounts_json(QString::from(&json));

                if accounts.is_empty() {
                    clear_current_account(self.as_mut());
                } else if let Ok(Some(account)) = AccountService::selected() {
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

    pub fn refresh_auth_servers(mut self: Pin<&mut Self>) -> QString {
        match AccountService::list_auth_servers() {
            Ok(servers) => {
                let json = serde_json::json!({ "servers": servers }).to_string();
                self.as_mut().set_auth_servers_json(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                let json =
                    serde_json::json!({ "servers": [], "error": err.to_string() }).to_string();
                self.as_mut().set_auth_servers_json(QString::from(&json));
                self.as_mut().set_output(QString::from(&format!(
                    "读取第三方认证服务器失败。\n\n{err}"
                )));
                QString::from(&json)
            }
        }
    }

    pub fn add_auth_server(mut self: Pin<&mut Self>, name: QString, url: QString) -> QString {
        match AccountService::add_auth_server(&name.to_string(), &url.to_string()) {
            Ok(servers) => {
                let json = serde_json::json!({ "servers": servers }).to_string();
                self.as_mut().set_auth_servers_json(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("添加认证服务器失败。\n\n{err}")));
                self.as_mut().refresh_auth_servers()
            }
        }
    }

    pub fn delete_auth_server(mut self: Pin<&mut Self>, index: QString) -> QString {
        let index = match index.to_string().parse::<usize>() {
            Ok(value) => value,
            Err(err) => {
                self.as_mut().set_output(QString::from(&format!(
                    "删除认证服务器失败：无效索引。\n\n{err}"
                )));
                return self.as_mut().refresh_auth_servers();
            }
        };

        match AccountService::remove_auth_server_by_index(index) {
            Ok(servers) => {
                let json = serde_json::json!({ "servers": servers }).to_string();
                self.as_mut().set_auth_servers_json(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("删除认证服务器失败。\n\n{err}")));
                self.as_mut().refresh_auth_servers()
            }
        }
    }

    pub fn offline_avatar_preview(self: Pin<&mut Self>, username: QString) -> QString {
        match AccountService::offline_avatar_preview(&username.to_string(), 96) {
            Ok(url) => QString::from(&url),
            Err(_) => QString::from(""),
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

        match AccountService::list() {
            Ok(accounts) => {
                let Some(account) = accounts.get(index) else {
                    self.as_mut()
                        .set_output(QString::from("切换账户失败：账户索引不存在。"));
                    return;
                };

                if let Err(err) = AccountService::select_account(account) {
                    self.as_mut().set_output(QString::from(&format!(
                        "切换账户失败：无法保存选择。\n\n{err}"
                    )));
                    return;
                }

                // HMCL 选择账号只切 selected item，不重建列表，不刷新头像。
                self.as_mut()
                    .set_current_account_name(QString::from(&account.username));
                self.as_mut()
                    .set_current_account_kind(QString::from(&display_account_kind(&account.kind)));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("切换账户失败。\n\n{err}")));
            }
        }
    }

    pub fn switch_account_fast(
        mut self: Pin<&mut Self>,
        index: QString,
        username: QString,
        display_kind: QString,
        avatar_url: QString,
    ) {
        let index = match index.to_string().parse::<usize>() {
            Ok(value) => value,
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("切换账户失败：无效索引。\n\n{err}")));
                return;
            }
        };

        match AccountService::list() {
            Ok(accounts) => {
                let Some(account) = accounts.get(index) else {
                    self.as_mut()
                        .set_output(QString::from("切换账户失败：账户索引不存在。"));
                    return;
                };

                if let Err(err) = AccountService::select_account(account) {
                    self.as_mut().set_output(QString::from(&format!(
                        "切换账户失败：无法保存选择。\n\n{err}"
                    )));
                    return;
                }

                let username = username.to_string();
                let display_kind = display_kind.to_string();
                let avatar_url = avatar_url.to_string();

                self.as_mut()
                    .set_current_account_name(QString::from(if username.is_empty() {
                        &account.username
                    } else {
                        &username
                    }));

                self.as_mut()
                    .set_current_account_kind(QString::from(if display_kind.is_empty() {
                        display_account_kind(&account.kind)
                    } else {
                        display_kind
                    }));

                // 使用 QML 已经显示出来的头像 URL，避免重新生成/下载头像导致 UI 卡顿。
                if !avatar_url.is_empty() {
                    self.as_mut()
                        .set_current_account_avatar_url(QString::from(&avatar_url));
                }
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("切换账户失败。\n\n{err}")));
            }
        }
    }

    pub fn switch_account_by_identifier(
        mut self: Pin<&mut Self>,
        identifier: QString,
        username: QString,
        display_kind: QString,
        avatar_url: QString,
    ) {
        let identifier = identifier.to_string();

        if identifier.trim().is_empty() {
            self.as_mut()
                .set_output(QString::from("切换账户失败：账户 identifier 为空。"));
            return;
        }

        if let Err(err) = AccountService::select(&identifier) {
            self.as_mut().set_output(QString::from(&format!(
                "切换账户失败：无法保存选择。\n\n{err}"
            )));
            return;
        }

        let username = username.to_string();
        let display_kind = display_kind.to_string();
        let avatar_url = avatar_url.to_string();

        self.as_mut()
            .set_current_account_name(QString::from(&username));

        self.as_mut()
            .set_current_account_kind(QString::from(&display_kind));

        self.as_mut()
            .set_current_account_avatar_url(QString::from(&avatar_url));
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

        match AccountService::list() {
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

                match AccountService::delete_account_parts(
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

                        self.as_mut()
                            .set_output(QString::from(&format!("已删除账户：{deleted_name}")));
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

    pub fn start_refresh_account(mut self: Pin<&mut Self>, index: QString) {
        let index_text = index.to_string();
        let status_path = account_refresh_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut()
                .set_output(QString::from("账户任务正在执行中。请等待当前任务完成。"));
            return;
        }

        write_account_refresh_task_status(
            &status_path,
            true,
            index_text.parse::<i64>().unwrap_or(-1),
            "正在刷新账户",
            "正在后台刷新账户登录状态、皮肤和头像缓存。",
            false,
            "",
            "",
            "",
            "",
            "",
        );

        thread::spawn(move || {
            let parsed_index = match index_text.parse::<usize>() {
                Ok(value) => value,
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        -1,
                        "账户刷新失败",
                        &format!("无效账户索引：{err}"),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                    return;
                }
            };

            let mut accounts = match AccountService::list() {
                Ok(accounts) => accounts,
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "账户刷新失败",
                        &err.to_string(),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                    return;
                }
            };

            let Some(account) = accounts.get(parsed_index).cloned() else {
                write_account_refresh_task_status(
                    &status_path,
                    false,
                    parsed_index as i64,
                    "账户刷新失败",
                    "账户索引不存在。",
                    false,
                    "",
                    "",
                    "",
                    "",
                    "账户索引不存在。",
                );
                return;
            };

            match AccountService::refresh_account(&account).and_then(|updated| {
                AccountService::save(&updated)?;
                Ok(updated)
            }) {
                Ok(updated) => {
                    for item in &mut accounts {
                        if AccountService::identifier(item) == AccountService::identifier(&updated)
                        {
                            *item = updated.clone();
                        }
                    }

                    let accounts_json = accounts_public_json(&accounts);
                    let kind = display_account_kind(&updated.kind);
                    let avatar = avatar_url_for_account(&updated);

                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "账户刷新完成",
                        "账户登录状态和头像缓存已刷新。",
                        true,
                        &accounts_json,
                        &updated.username,
                        &kind,
                        &avatar,
                        "",
                    );
                }
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "账户刷新失败",
                        &err.to_string(),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                }
            }
        });
    }

    pub fn start_upload_skin(
        mut self: Pin<&mut Self>,
        index: QString,
        file_url: QString,
        model: QString,
    ) {
        let index_text = index.to_string();
        let file_url = file_url.to_string();
        let model = model.to_string();
        let status_path = account_refresh_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut()
                .set_output(QString::from("账户任务正在执行中。请等待当前任务完成。"));
            return;
        }

        write_account_refresh_task_status(
            &status_path,
            true,
            index_text.parse::<i64>().unwrap_or(-1),
            "正在上传皮肤",
            "正在后台刷新账户、上传皮肤并更新头像缓存。",
            false,
            "",
            "",
            "",
            "",
            "",
        );

        thread::spawn(move || {
            let parsed_index = match index_text.parse::<usize>() {
                Ok(value) => value,
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        -1,
                        "上传皮肤失败",
                        &format!("无效账户索引：{err}"),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                    return;
                }
            };

            let path = file_url_to_path(&file_url);
            let slim = model == "slim";

            let mut accounts = match AccountService::list() {
                Ok(accounts) => accounts,
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "上传皮肤失败",
                        &err.to_string(),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                    return;
                }
            };

            let Some(account) = accounts.get(parsed_index).cloned() else {
                write_account_refresh_task_status(
                    &status_path,
                    false,
                    parsed_index as i64,
                    "上传皮肤失败",
                    "账户索引不存在。",
                    false,
                    "",
                    "",
                    "",
                    "",
                    "账户索引不存在。",
                );
                return;
            };

            match AccountService::upload_skin_for_account(&account, &path, slim) {
                Ok(updated) => {
                    for item in &mut accounts {
                        if AccountService::identifier(item) == AccountService::identifier(&updated)
                        {
                            *item = updated.clone();
                        }
                    }

                    let accounts_json = accounts_public_json(&accounts);
                    let kind = display_account_kind(&updated.kind);
                    let avatar = avatar_url_for_account(&updated);

                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "上传皮肤完成",
                        "皮肤已上传或保存，账户头像已更新。",
                        true,
                        &accounts_json,
                        &updated.username,
                        &kind,
                        &avatar,
                        "",
                    );
                }
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "上传皮肤失败",
                        &err.to_string(),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                }
            }
        });
    }

    pub fn start_migrate_account(mut self: Pin<&mut Self>, index: QString, target: QString) {
        let index_text = index.to_string();
        let target = target.to_string();
        let status_path = account_refresh_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut()
                .set_output(QString::from("账户任务正在执行中。请等待当前任务完成。"));
            return;
        }

        write_account_refresh_task_status(
            &status_path,
            true,
            index_text.parse::<i64>().unwrap_or(-1),
            "正在迁移账户",
            "正在切换账户存储位置。",
            false,
            "",
            "",
            "",
            "",
            "",
        );

        thread::spawn(move || {
            let parsed_index = match index_text.parse::<usize>() {
                Ok(value) => value,
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        -1,
                        "账户迁移失败",
                        &format!("无效账户索引：{err}"),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                    return;
                }
            };

            let mut accounts = match AccountService::list() {
                Ok(accounts) => accounts,
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "账户迁移失败",
                        &err.to_string(),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                    return;
                }
            };

            let Some(account) = accounts.get(parsed_index).cloned() else {
                write_account_refresh_task_status(
                    &status_path,
                    false,
                    parsed_index as i64,
                    "账户迁移失败",
                    "账户索引不存在。",
                    false,
                    "",
                    "",
                    "",
                    "",
                    "账户索引不存在。",
                );
                return;
            };

            match AccountService::migrate_storage_for_account(&account, &target) {
                Ok(updated) => {
                    for item in &mut accounts {
                        if AccountService::identifier(item) == AccountService::identifier(&updated)
                        {
                            *item = updated.clone();
                        }
                    }

                    let accounts_json = accounts_public_json(&accounts);
                    let kind = display_account_kind(&updated.kind);
                    let avatar = avatar_url_for_account(&updated);

                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "账户迁移完成",
                        "账户存储位置已更新。",
                        true,
                        &accounts_json,
                        &updated.username,
                        &kind,
                        &avatar,
                        "",
                    );
                }
                Err(err) => {
                    write_account_refresh_task_status(
                        &status_path,
                        false,
                        parsed_index as i64,
                        "账户迁移失败",
                        &err.to_string(),
                        false,
                        "",
                        "",
                        "",
                        "",
                        &err.to_string(),
                    );
                }
            }
        });
    }

    pub fn start_cleanup_avatar_cache(mut self: Pin<&mut Self>) {
        let status_path = account_refresh_task_status_path();

        if task_status_is_active(&status_path) {
            self.as_mut()
                .set_output(QString::from("账户任务正在执行中。请等待当前任务完成。"));
            return;
        }

        write_account_refresh_task_status(
            &status_path,
            true,
            -1,
            "正在清理头像缓存",
            "正在删除过期头像缓存。",
            false,
            "",
            "",
            "",
            "",
            "",
        );

        thread::spawn(move || match AccountService::cleanup_avatar_cache(30) {
            Ok(count) => {
                let accounts = AccountService::list().unwrap_or_default();
                let accounts_json = accounts_public_json(&accounts);

                write_account_refresh_task_status(
                    &status_path,
                    false,
                    -1,
                    "头像缓存清理完成",
                    &format!("已清理 {count} 个过期头像缓存文件。"),
                    true,
                    &accounts_json,
                    "",
                    "",
                    "",
                    "",
                );
            }
            Err(err) => {
                write_account_refresh_task_status(
                    &status_path,
                    false,
                    -1,
                    "头像缓存清理失败",
                    &err.to_string(),
                    false,
                    "",
                    "",
                    "",
                    "",
                    &err.to_string(),
                );
            }
        });
    }

    pub fn poll_refresh_account_task(mut self: Pin<&mut Self>) -> QString {
        let path = account_refresh_task_status_path();
        let text = read_account_refresh_task_status_text(&path);

        if let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) {
            let active = value
                .get("active")
                .and_then(|value| value.as_bool())
                .unwrap_or(false);

            let title = value
                .get("title")
                .and_then(|value| value.as_str())
                .unwrap_or("账户刷新");

            let message = value
                .get("message")
                .and_then(|value| value.as_str())
                .unwrap_or_default();

            if let Some(accounts_json) = value.get("accountsJson").and_then(|value| value.as_str())
            {
                if !accounts_json.is_empty() {
                    self.as_mut()
                        .set_accounts_json(QString::from(accounts_json));
                }
            }

            if let Some(name) = value
                .get("currentAccountName")
                .and_then(|value| value.as_str())
            {
                if !name.is_empty() {
                    self.as_mut().set_current_account_name(QString::from(name));
                }
            }

            if let Some(kind) = value
                .get("currentAccountKind")
                .and_then(|value| value.as_str())
            {
                if !kind.is_empty() {
                    self.as_mut().set_current_account_kind(QString::from(kind));
                }
            }

            if let Some(avatar) = value
                .get("currentAccountAvatarUrl")
                .and_then(|value| value.as_str())
            {
                self.as_mut()
                    .set_current_account_avatar_url(QString::from(avatar));
            }

            if active
                || value
                    .get("success")
                    .and_then(|value| value.as_bool())
                    .unwrap_or(false)
            {
                self.as_mut()
                    .set_output(QString::from(&format!("{title}\n\n{message}")));
            }
        }

        QString::from(&text)
    }
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

fn read_pending_yggdrasil_login()
-> Result<launcher_core::YggdrasilPendingLogin, Box<dyn std::error::Error + Send + Sync + 'static>>
{
    let path = pending_yggdrasil_login_path();
    let text = fs::read_to_string(path)?;
    Ok(serde_json::from_str(&text)?)
}

fn clear_pending_yggdrasil_login() {
    let _ = fs::remove_file(pending_yggdrasil_login_path());
}

fn account_refresh_task_status_path() -> PathBuf {
    if let Some(value) = std::env::var_os("XDG_CACHE_HOME") {
        if !value.is_empty() {
            return PathBuf::from(value)
                .join("mc-launcher")
                .join("account-refresh-task.json");
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join(".cache")
            .join("mc-launcher")
            .join("account-refresh-task.json");
    }

    std::env::temp_dir()
        .join("mc-launcher")
        .join("account-refresh-task.json")
}

fn write_account_refresh_task_status(
    path: &Path,
    active: bool,
    index: i64,
    title: &str,
    message: &str,
    success: bool,
    accounts_json: &str,
    current_account_name: &str,
    current_account_kind: &str,
    current_account_avatar_url: &str,
    error: &str,
) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let payload = serde_json::json!({
        "active": active,
        "index": index,
        "title": title,
        "message": message,
        "success": success,
        "accountsJson": accounts_json,
        "currentAccountName": current_account_name,
        "currentAccountKind": current_account_kind,
        "currentAccountAvatarUrl": current_account_avatar_url,
        "error": error,
        "updatedAt": SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_millis())
            .unwrap_or(0),
    });

    let _ = fs::write(path, payload.to_string());
}

fn read_account_refresh_task_status_text(path: &Path) -> String {
    read_status_text(
        path,
        &serde_json::json!({
            "active": false,
            "index": -1,
            "title": "账户刷新",
            "message": "还没有账户刷新任务。",
            "success": false,
            "accountsJson": "",
            "currentAccountName": "",
            "currentAccountKind": "",
            "currentAccountAvatarUrl": "",
            "error": ""
        })
        .to_string(),
    )
}

fn refresh_accounts_property(mut qobject: Pin<&mut qobject::LauncherBackend>) {
    if let Ok(accounts) = AccountService::list() {
        qobject
            .as_mut()
            .set_accounts_json(QString::from(&accounts_public_json(&accounts)));

        if accounts.is_empty() {
            clear_current_account(qobject.as_mut());
        } else if let Ok(Some(account)) = AccountService::selected() {
            set_current_account(qobject.as_mut(), &account);
        }
    }
}

fn set_current_account(mut qobject: Pin<&mut qobject::LauncherBackend>, account: &AuthAccount) {
    let _ = AccountService::select_account(account);

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
    qobject.as_mut().set_current_account_name(QString::from(""));

    qobject.as_mut().set_current_account_kind(QString::from(""));

    qobject
        .as_mut()
        .set_current_account_avatar_url(QString::from(""));
}

fn file_url_to_path(value: &str) -> PathBuf {
    let value = value.trim();

    if let Some(rest) = value.strip_prefix("file://") {
        return PathBuf::from(percent_decode_file_url(rest));
    }

    PathBuf::from(value)
}

fn percent_decode_file_url(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;

    while i < bytes.len() {
        match bytes[i] {
            b'%' if i + 2 < bytes.len() => {
                let hi = (bytes[i + 1] as char).to_digit(16);
                let lo = (bytes[i + 2] as char).to_digit(16);

                if let (Some(hi), Some(lo)) = (hi, lo) {
                    out.push(((hi << 4) | lo) as u8);
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


fn yggdrasil_login_task_status_path() -> PathBuf {
    let mut path = std::env::temp_dir();
    path.push("mc-launcher-yggdrasil-login-task.json");
    path
}

fn read_yggdrasil_login_task_status_text(path: &Path) -> String {
    read_status_text(
        path,
        &serde_json::json!({
            "active": false,
            "title": "第三方账户登录",
            "message": "还没有第三方账户登录任务。",
            "success": false,
            "accountsJson": "",
            "pendingProfilesJson": "",
            "currentAccountName": "",
            "currentAccountKind": "",
            "currentAccountAvatarUrl": "",
            "output": "",
            "error": ""
        })
        .to_string(),
    )
}

fn write_yggdrasil_login_task_status(
    path: &Path,
    active: bool,
    title: &str,
    message: &str,
    success: bool,
    accounts_json: &str,
    pending_profiles_json: &str,
    current_account_name: &str,
    current_account_kind: &str,
    current_account_avatar_url: &str,
    output: &str,
    error: &str,
) {
    let payload = serde_json::json!({
        "active": active,
        "title": title,
        "message": message,
        "success": success,
        "accountsJson": accounts_json,
        "pendingProfilesJson": pending_profiles_json,
        "currentAccountName": current_account_name,
        "currentAccountKind": current_account_kind,
        "currentAccountAvatarUrl": current_account_avatar_url,
        "output": output,
        "error": error
    });

    let _ = fs::write(path, payload.to_string());
}
