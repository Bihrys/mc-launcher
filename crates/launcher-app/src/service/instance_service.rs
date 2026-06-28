use crate::dto::{InstanceDetailDto, InstanceFolderDto, InstanceListDto, InstanceListItem, InstanceLoaderDto, ProfileListItem};
use std::path::PathBuf;

pub struct InstanceService;

impl InstanceService {
    pub fn list() -> Result<InstanceListDto, launcher_core::InstanceError> {
        let selected = launcher_core::selected_version().unwrap_or_default();
        let instances = launcher_core::instance::InstanceService::list()?
            .into_iter()
            .map(|summary| InstanceListItem {
                id: summary.id,
                title: summary.title,
                subtitle: summary.subtitle,
                tag: summary.tag,
                icon_name: summary.icon_name,
                selected: summary.selected,
                can_update: false,
                game_version: summary.game_version,
                loader_summary: summary.loader_summary,
                path: summary.path,
            })
            .collect::<Vec<_>>();

        let raw = serde_json::from_str::<serde_json::Value>(&launcher_core::instance::InstanceService::list_json()?)
            .unwrap_or_default();
        let minecraft_root = raw.get("minecraftRoot").and_then(|v| v.as_str()).map(PathBuf::from).unwrap_or_default();
        let profile_root = raw.get("profileRoot").and_then(|v| v.as_str()).map(PathBuf::from).unwrap_or_default();

        Ok(InstanceListDto {
            selected_instance: selected,
            minecraft_root: minecraft_root.clone(),
            profile_root,
            profiles: vec![ProfileListItem {
                id: "default".to_string(),
                name: "默认游戏目录".to_string(),
                path: minecraft_root,
                selected: true,
            }],
            instances,
        })
    }

    pub fn list_json() -> Result<String, launcher_core::InstanceError> {
        Ok(serde_json::to_string(&Self::list()?)?)
    }

    pub fn detail(version_id: &str) -> Result<InstanceDetailDto, launcher_core::InstanceError> {
        let detail = launcher_core::instance::InstanceService::detail(version_id)?;
        Ok(InstanceDetailDto {
            id: detail.summary.id,
            title: detail.summary.title,
            subtitle: detail.summary.subtitle,
            icon_name: detail.summary.icon_name,
            game_version: detail.summary.game_version,
            loader_summary: detail.summary.loader_summary,
            folders: detail.folders.into_iter().map(|folder| InstanceFolderDto {
                folder_key: folder.key,
                title: folder.title,
                path: folder.path,
                exists: folder.exists,
                item_count: folder.item_count,
            }).collect(),
            loaders: detail.loaders.into_iter().map(|loader| InstanceLoaderDto {
                kind: loader.kind,
                version: loader.version,
            }).collect(),
            has_client_jar: detail.has_client_jar,
            has_version_json: detail.has_version_json,
            main_class: detail.main_class,
            inherits_from: detail.inherits_from,
        })
    }

    pub fn detail_json(version_id: &str) -> Result<String, launcher_core::InstanceError> {
        // Compatibility JSON shape consumed by current QML. It keeps the old core detail until VersionPage is fully VM-bound.
        launcher_core::instance::InstanceService::detail_json(version_id)
    }

    pub fn select(version_id: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::instance::InstanceService::select(version_id) }
    pub fn rename(version_id: &str, new_name: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::instance::InstanceService::rename(version_id, new_name) }
    pub fn duplicate(version_id: &str, new_name: &str, copy_saves: bool) -> Result<String, launcher_core::InstanceError> { launcher_core::instance::InstanceService::duplicate(version_id, new_name, copy_saves) }
    pub fn delete(version_id: &str) -> Result<(), launcher_core::InstanceError> { launcher_core::instance::InstanceService::delete(version_id) }
    pub fn open_folder(version_id: &str, sub_dir: Option<&str>) -> Result<PathBuf, launcher_core::InstanceError> {
        launcher_core::instance::InstanceService::open_folder(version_id, sub_dir.unwrap_or(""))
    }
    pub fn clean(version_id: &str) -> Result<usize, launcher_core::InstanceError> {
        launcher_core::instance::InstanceService::clean(version_id).map(|count| count as usize)
    }
    pub fn clear_assets() -> Result<(), launcher_core::InstanceError> { launcher_core::instance::InstanceService::clear_assets() }
    pub fn clear_libraries() -> Result<(), launcher_core::InstanceError> { launcher_core::instance::InstanceService::clear_libraries() }
    pub fn save_settings_json(version_id: &str, settings_json: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::instance::InstanceService::save_settings_json(version_id, settings_json) }

    pub fn mods_json(version_id: &str) -> Result<String, launcher_core::InstanceError> { launcher_core::instance_mods_json(version_id) }
    pub fn set_mod_enabled(version_id: &str, file_name: &str, enabled: bool) -> Result<String, launcher_core::InstanceError> { launcher_core::set_instance_mod_enabled(version_id, file_name, enabled) }
    pub fn delete_mod(version_id: &str, file_name: &str) -> Result<(), launcher_core::InstanceError> { launcher_core::delete_instance_mod(version_id, file_name) }
}
