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
        #[namespace = "launcher_backend"]
        type LauncherBackend = super::LauncherBackendRust;

        #[qinvokable]
        #[cxx_name = "detectJava"]
        fn detect_java(self: Pin<&mut LauncherBackend>);

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
        #[cxx_name = "requestMicrosoftDeviceCode"]
        fn request_microsoft_device_code(
            self: Pin<&mut LauncherBackend>,
            client_id: QString,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "completeMicrosoftDeviceLogin"]
        fn complete_microsoft_device_login(
            self: Pin<&mut LauncherBackend>,
            client_id: QString,
            device_code: QString,
        );
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;

#[derive(Default)]
pub struct LauncherBackendRust {
    output: QString,
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

    pub fn login_offline(mut self: Pin<&mut Self>, username: QString) {
        match launcher_core::login_offline(&username.to_string()).and_then(|account| {
            let path = launcher_core::save_account(&account)?;

            Ok((account, path))
        }) {
            Ok((account, path)) => {
                self.as_mut().set_output(QString::from(&format!(
                    "离线登录完成。\n\n用户名: {}\nUUID: {}\n账户文件:\n{}",
                    account.username,
                    account.uuid,
                    path.display()
                )));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("离线登录失败。\n\n{err}")));
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

        match launcher_core::login_yggdrasil(&server_url, &username, &password).and_then(|account| {
            let path = launcher_core::save_account(&account)?;

            Ok((account, path))
        }) {
            Ok((account, path)) => {
                self.as_mut().set_output(QString::from(&format!(
                    "第三方服务器登录完成。\n\n服务器: {}\n角色名: {}\nUUID: {}\n账户文件:\n{}",
                    account.server_url.as_deref().unwrap_or("unknown"),
                    account.username,
                    account.uuid,
                    path.display()
                )));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("第三方服务器登录失败。\n\n{err}")));
            }
        }
    }

    pub fn request_microsoft_device_code(
        mut self: Pin<&mut Self>,
        client_id: QString,
    ) -> QString {
        match launcher_core::request_microsoft_device_code(&client_id.to_string()) {
            Ok(code) => {
                let output = format!(
                    "微软设备码已生成。\n\n验证码: {}\n授权地址: {}\n过期时间: {} 秒\n\n请在浏览器打开授权地址并输入验证码。授权完成后回到启动器点击“检查授权并登录”。",
                    code.user_code,
                    code.verification_uri,
                    code.expires_in
                );

                self.as_mut().set_output(QString::from(&output));

                let payload = serde_json::json!({
                    "ok": true,
                    "deviceCode": code.device_code,
                    "userCode": code.user_code,
                    "verificationUri": code.verification_uri,
                    "expiresIn": code.expires_in,
                    "interval": code.interval,
                    "message": code.message
                });

                QString::from(&payload.to_string())
            }
            Err(err) => {
                self.as_mut().set_output(QString::from(&format!(
                    "微软设备码请求失败。\n\n{err}"
                )));

                QString::from(&serde_json::json!({
                    "ok": false,
                    "error": err.to_string()
                }).to_string())
            }
        }
    }

    pub fn complete_microsoft_device_login(
        mut self: Pin<&mut Self>,
        client_id: QString,
        device_code: QString,
    ) {
        self.as_mut().set_output(QString::from(
            "正在检查微软授权并登录 Minecraft Services...",
        ));

        match launcher_core::complete_microsoft_device_login(
            &client_id.to_string(),
            &device_code.to_string(),
        )
        .and_then(|account| {
            let path = launcher_core::save_account(&account)?;

            Ok((account, path))
        }) {
            Ok((account, path)) => {
                self.as_mut().set_output(QString::from(&format!(
                    "微软登录完成。\n\n角色名: {}\nUUID: {}\n{}\n\n账户文件:\n{}",
                    account.username,
                    account.uuid,
                    account.note.unwrap_or_default(),
                    path.display()
                )));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("微软登录未完成或失败。\n\n{err}")));
            }
        }
    }
}
