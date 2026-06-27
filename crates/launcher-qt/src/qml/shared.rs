//! `qml` 层各 ListModel 共享的行结构、过滤逻辑与角色常量。

use launcher_app::dto::{InstanceListItem, ProfileListItem};

// Qt::UserRole == 256，自定义角色从这里开始递增。
pub(crate) const ROLE_INSTANCE_ID: i32 = 256;
pub(crate) const ROLE_TITLE: i32 = 257;
pub(crate) const ROLE_SUBTITLE: i32 = 258;
pub(crate) const ROLE_TAG: i32 = 259;
pub(crate) const ROLE_ICON_NAME: i32 = 260;
pub(crate) const ROLE_SELECTED: i32 = 261;
pub(crate) const ROLE_CAN_UPDATE: i32 = 262;
pub(crate) const ROLE_GAME_VERSION: i32 = 263;
pub(crate) const ROLE_LOADER_SUMMARY: i32 = 264;

pub(crate) const ROLE_PROFILE_ID: i32 = 256;
pub(crate) const ROLE_PROFILE_NAME: i32 = 257;
pub(crate) const ROLE_PROFILE_PATH: i32 = 258;
pub(crate) const ROLE_PROFILE_SELECTED: i32 = 259;

#[derive(Debug, Clone, Default)]
pub(crate) struct InstanceRow {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub tag: String,
    pub icon_name: String,
    pub selected: bool,
    pub can_update: bool,
    pub game_version: String,
    pub loader_summary: String,
}

impl InstanceRow {
    pub(crate) fn from_item(item: &InstanceListItem) -> Self {
        Self {
            id: item.id.clone(),
            title: item.title.clone(),
            subtitle: item.subtitle.clone(),
            tag: item.tag.clone(),
            icon_name: if item.icon_name.is_empty() {
                "grass".to_string()
            } else {
                item.icon_name.clone()
            },
            selected: item.selected,
            can_update: item.can_update,
            game_version: item.game_version.clone(),
            loader_summary: item.loader_summary.clone(),
        }
    }
}

#[derive(Debug, Clone, Default)]
pub(crate) struct ProfileRow {
    pub id: String,
    pub name: String,
    pub path: String,
    pub selected: bool,
}

impl ProfileRow {
    pub(crate) fn from_item(item: &ProfileListItem) -> Self {
        Self {
            id: item.id.clone(),
            name: item.name.clone(),
            path: item.path.display().to_string(),
            selected: item.selected,
        }
    }
}

/// 实现 HMCL `GameListSkin` 的搜索过滤规则：
/// - 空 -> 全部；
/// - `regex:` 前缀 -> 正则匹配 id（本项目暂无 regex 依赖，降级为去前缀后的子串匹配，TODO）；
/// - 否则 -> 大小写不敏感子串匹配 id/title/subtitle。
pub(crate) fn filter_rows(all: &[InstanceRow], search: &str) -> Vec<InstanceRow> {
    let query = search.trim();
    if query.is_empty() {
        return all.to_vec();
    }
    let needle = query
        .strip_prefix("regex:")
        .unwrap_or(query)
        .trim()
        .to_lowercase();
    if needle.is_empty() {
        return all.to_vec();
    }
    all.iter()
        .filter(|row| {
            row.id.to_lowercase().contains(&needle)
                || row.title.to_lowercase().contains(&needle)
                || row.subtitle.to_lowercase().contains(&needle)
        })
        .cloned()
        .collect()
}

/// 把 `Result` 折叠成 UI 提示：成功返回空串，失败返回错误文本。
pub(crate) fn ok_message<T, E: std::fmt::Display>(result: Result<T, E>) -> String {
    match result {
        Ok(_) => String::new(),
        Err(err) => err.to_string(),
    }
}
