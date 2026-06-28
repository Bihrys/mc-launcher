use crate::backend::qobject;
use core::pin::Pin;
use cxx_qt_lib::QString;

impl qobject::LauncherBackend {
    pub fn refresh_instances(mut self: Pin<&mut Self>) -> QString {
        match launcher_app::InstanceService::list_json() {
            Ok(json) => {
                self.as_mut().set_instance_list_json(QString::from(&json));

                if let Ok(value) = serde_json::from_str::<serde_json::Value>(&json) {
                    if let Some(selected) = value.get("selectedInstance").and_then(|value| value.as_str()) {
                        self.as_mut().set_selected_game_version(QString::from(selected));
                    }
                }

                QString::from(&json)
            }
            Err(err) => {
                let fallback = serde_json::json!({
                    "selectedInstance": "",
                    "minecraftRoot": "",
                    "profileRoot": "",
                    "instances": [],
                    "profiles": [],
                    "error": err.to_string()
                })
                .to_string();
                self.as_mut()
                    .set_instance_list_json(QString::from(&fallback));
                self.as_mut()
                    .set_output(QString::from(&format!("实例列表加载失败。\n\n{err}")));
                QString::from(&fallback)
            }
        }
    }

    pub fn refresh_instance_detail(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::detail_json(&version_id) {
            Ok(json) => {
                self.as_mut().set_instance_detail_json(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                let fallback = serde_json::json!({
                    "error": err.to_string(),
                    "summary": {
                        "id": version_id,
                        "title": version_id,
                        "tag": "",
                        "subtitle": "",
                        "iconName": "grass",
                        "selected": false
                    },
                    "folders": [],
                    "loaders": [],
                    "settings": {}
                })
                .to_string();
                self.as_mut()
                    .set_instance_detail_json(QString::from(&fallback));
                self.as_mut()
                    .set_output(QString::from(&format!("实例信息读取失败。\n\n{err}")));
                QString::from(&fallback)
            }
        }
    }

    pub fn refresh_instance_mods(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::mods_json(&version_id) {
            Ok(json) => {
                self.as_mut().set_instance_mods_json(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                let fallback = serde_json::json!({ "mods": [] }).to_string();
                self.as_mut()
                    .set_instance_mods_json(QString::from(&fallback));
                self.as_mut()
                    .set_output(QString::from(&format!("Mod 列表读取失败。\n\n{err}")));
                QString::from(&fallback)
            }
        }
    }

    pub fn set_instance_mod_enabled(
        mut self: Pin<&mut Self>,
        version_id: QString,
        file_name: QString,
        enabled: QString,
    ) {
        let version_id = version_id.to_string();
        let file_name = file_name.to_string();
        let enabled = matches!(
            enabled.to_string().trim().to_ascii_lowercase().as_str(),
            "true" | "1" | "yes" | "y"
        );

        match launcher_app::InstanceService::set_mod_enabled(&version_id, &file_name, enabled) {
            Ok(_) => {
                let _ = self.as_mut().refresh_instance_mods(QString::from(&version_id));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("切换 Mod 状态失败。\n\n{err}")));
            }
        }
    }

    pub fn delete_instance_mod(
        mut self: Pin<&mut Self>,
        version_id: QString,
        file_name: QString,
    ) {
        let version_id = version_id.to_string();
        let file_name = file_name.to_string();

        match launcher_app::InstanceService::delete_mod(&version_id, &file_name) {
            Ok(()) => {
                self.as_mut()
                    .set_output(QString::from(&format!("已删除 Mod：{file_name}")));
                let _ = self.as_mut().refresh_instance_mods(QString::from(&version_id));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("删除 Mod 失败。\n\n{err}")));
            }
        }
    }

    pub fn refresh_instance_resourcepacks(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::resourcepacks_json(&version_id) {
            Ok(json) => {
                self.as_mut()
                    .set_instance_resourcepacks_json(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                let fallback = serde_json::json!({ "resourcepacks": [] }).to_string();
                self.as_mut()
                    .set_instance_resourcepacks_json(QString::from(&fallback));
                self.as_mut()
                    .set_output(QString::from(&format!("资源包列表读取失败。\n\n{err}")));
                QString::from(&fallback)
            }
        }
    }

    pub fn set_instance_resourcepack_enabled(
        mut self: Pin<&mut Self>,
        version_id: QString,
        file_name: QString,
        enabled: QString,
    ) {
        let version_id = version_id.to_string();
        let file_name = file_name.to_string();
        let enabled = matches!(
            enabled.to_string().trim().to_ascii_lowercase().as_str(),
            "true" | "1" | "yes" | "y"
        );

        match launcher_app::InstanceService::set_resourcepack_enabled(&version_id, &file_name, enabled) {
            Ok(_) => {
                let _ = self
                    .as_mut()
                    .refresh_instance_resourcepacks(QString::from(&version_id));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("切换资源包状态失败。\n\n{err}")));
            }
        }
    }

    pub fn delete_instance_resourcepack(
        mut self: Pin<&mut Self>,
        version_id: QString,
        file_name: QString,
    ) {
        let version_id = version_id.to_string();
        let file_name = file_name.to_string();

        match launcher_app::InstanceService::delete_resourcepack(&version_id, &file_name) {
            Ok(()) => {
                self.as_mut()
                    .set_output(QString::from(&format!("已删除资源包：{file_name}")));
                let _ = self
                    .as_mut()
                    .refresh_instance_resourcepacks(QString::from(&version_id));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("删除资源包失败。\n\n{err}")));
            }
        }
    }

    pub fn refresh_instance_worlds(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::worlds_json(&version_id) {
            Ok(json) => {
                self.as_mut()
                    .set_instance_worlds_json(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                let fallback = serde_json::json!({ "worlds": [] }).to_string();
                self.as_mut()
                    .set_instance_worlds_json(QString::from(&fallback));
                self.as_mut()
                    .set_output(QString::from(&format!("世界列表读取失败。\n\n{err}")));
                QString::from(&fallback)
            }
        }
    }

    pub fn delete_instance_world(
        mut self: Pin<&mut Self>,
        version_id: QString,
        file_name: QString,
    ) {
        let version_id = version_id.to_string();
        let file_name = file_name.to_string();

        match launcher_app::InstanceService::delete_world(&version_id, &file_name) {
            Ok(()) => {
                self.as_mut()
                    .set_output(QString::from(&format!("已删除世界：{file_name}")));
                let _ = self
                    .as_mut()
                    .refresh_instance_worlds(QString::from(&version_id));
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("删除世界失败。\n\n{err}")));
            }
        }
    }

    pub fn select_instance(mut self: Pin<&mut Self>, version_id: QString) {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::select(&version_id) {
            Ok(id) => {
                self.as_mut().set_selected_game_version(QString::from(&id));
                self.as_mut().set_output(QString::from(&format!("已选择实例：{id}")));
                let _ = self.as_mut().refresh_instances();
                let _ = self.as_mut().refresh_installed_versions();
            }
            Err(err) => {
                self.as_mut()
                    .set_output(QString::from(&format!("选择实例失败。\n\n{err}")));
            }
        }
    }

    pub fn rename_instance(
        mut self: Pin<&mut Self>,
        version_id: QString,
        new_name: QString,
    ) -> QString {
        let version_id = version_id.to_string();
        let new_name = new_name.to_string();

        match launcher_app::InstanceService::rename(&version_id, &new_name) {
            Ok(id) => {
                self.as_mut().set_selected_game_version(QString::from(&id));
                self.as_mut().set_output(QString::from(&format!(
                    "实例已重命名。\n\n{} -> {}",
                    version_id, id
                )));
                let _ = self.as_mut().refresh_instances();
                self.as_mut().refresh_instance_detail(QString::from(&id))
            }
            Err(err) => {
                let text = format!("实例重命名失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn duplicate_instance(
        mut self: Pin<&mut Self>,
        version_id: QString,
        new_name: QString,
        copy_saves: QString,
    ) -> QString {
        let version_id = version_id.to_string();
        let new_name = new_name.to_string();
        let copy_saves = matches!(
            copy_saves.to_string().trim().to_ascii_lowercase().as_str(),
            "true" | "1" | "yes" | "y"
        );

        match launcher_app::InstanceService::duplicate(&version_id, &new_name, copy_saves) {
            Ok(id) => {
                self.as_mut().set_output(QString::from(&format!(
                    "实例已复制。\n\n{} -> {}",
                    version_id, id
                )));
                let _ = self.as_mut().refresh_instances();
                self.as_mut().refresh_instance_detail(QString::from(&id))
            }
            Err(err) => {
                let text = format!("实例复制失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn delete_instance(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::delete(&version_id) {
            Ok(()) => {
                self.as_mut()
                    .set_output(QString::from(&format!("实例已删除：{version_id}")));
                self.as_mut().set_instance_detail_json(QString::from(""));
                let json = self.as_mut().refresh_instances();
                let _ = self.as_mut().refresh_installed_versions();
                json
            }
            Err(err) => {
                let text = format!("实例删除失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn open_instance_folder(
        mut self: Pin<&mut Self>,
        version_id: QString,
        folder_key: QString,
    ) -> QString {
        let version_id = version_id.to_string();
        let folder_key = folder_key.to_string();
        let sub = folder_key_to_subdir(&folder_key);

        match launcher_app::InstanceService::open_folder(&version_id, Some(sub)) {
            Ok(path) => {
                let text = format!("已打开文件夹。\n\n{}", path.display());
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
            Err(err) => {
                let text = format!("打开文件夹失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn generate_instance_launch_command(
        mut self: Pin<&mut Self>,
        version_id: QString,
    ) -> QString {
        let version_id = version_id.to_string();

        match launcher_core::generate_launch_command_json(&version_id) {
            Ok(json) => {
                self.as_mut().set_output(QString::from(&json));
                QString::from(&json)
            }
            Err(err) => {
                let text = format!("生成启动脚本失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn clean_instance(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::clean(&version_id) {
            Ok(count) => {
                let text = format!("清理完成。\n\n已删除 {count} 个日志/缓存目录或文件。");
                self.as_mut().set_output(QString::from(&text));
                let _ = self.as_mut().refresh_instance_detail(QString::from(&version_id));
                QString::from(&text)
            }
            Err(err) => {
                let text = format!("清理失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn clear_instance_assets(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::clear_assets() {
            Ok(()) => {
                let text = "已删除全局 assets 目录。重新启动或修复游戏时会重新下载。".to_string();
                self.as_mut().set_output(QString::from(&text));
                let _ = self.as_mut().refresh_instance_detail(QString::from(&version_id));
                QString::from(&text)
            }
            Err(err) => {
                let text = format!("删除 assets 失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn clear_instance_libraries(mut self: Pin<&mut Self>, version_id: QString) -> QString {
        let version_id = version_id.to_string();

        match launcher_app::InstanceService::clear_libraries() {
            Ok(()) => {
                let text = "已删除全局 libraries 目录。重新启动或修复游戏时会重新下载。".to_string();
                self.as_mut().set_output(QString::from(&text));
                let _ = self.as_mut().refresh_instance_detail(QString::from(&version_id));
                QString::from(&text)
            }
            Err(err) => {
                let text = format!("删除 libraries 失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }

    pub fn save_instance_settings(
        mut self: Pin<&mut Self>,
        version_id: QString,
        settings_json: QString,
    ) -> QString {
        let version_id = version_id.to_string();
        let settings_json = settings_json.to_string();

        match launcher_app::InstanceService::save_settings_json(&version_id, &settings_json) {
            Ok(json) => {
                self.as_mut().set_instance_detail_json(QString::from(&json));
                self.as_mut().set_output(QString::from("实例设置已保存。"));
                QString::from(&json)
            }
            Err(err) => {
                let text = format!("保存实例设置失败。\n\n{err}");
                self.as_mut().set_output(QString::from(&text));
                QString::from(&text)
            }
        }
    }
}

fn folder_key_to_subdir(key: &str) -> &str {
    match key {
        "game" => "",
        "mods" => "mods",
        "resourcepacks" => "resourcepacks",
        "saves" => "saves",
        "shaderpacks" => "shaderpacks",
        "screenshots" => "screenshots",
        "config" => "config",
        "logs" => "logs",
        "crash-reports" => "crash-reports",
        "schematics" => "schematics",
        other => other,
    }
}
