//! 版本/实例列表的真实 ViewModel + ListModel（对齐 HMCL 的 GameListPage）。
//!
//! 这是项目里第一个真正的 cxx-qt `QAbstractListModel`，作为后续所有列表
//! （下载版本、账户、Mod、世界等）迁移的样板：
//!
//! ```text
//! QML  ->  GameListModel (QAbstractListModel, 本文件)
//!      ->  launcher_app::InstanceService (DTO)
//!      ->  launcher_core::instance::InstanceService -> instance_manager
//! ```
//!
//! 设计要点：
//! - 全量 `beginResetModel`/`endResetModel` 刷新（实例数量小、变更不频繁，
//!   等价于 HMCL 的 ObservableList 重载，免去逐行 insert/remove 索引簿记）。
//! - qproperty 只用 `count/loading/isEmpty`（i32/bool），让 Rust 结构保持
//!   `Unpin`，从而可用安全的 `rust_mut().get_mut()`；`searchText/selectedId`
//!   作为普通 String 字段存储。
//! - QML delegate 通过角色读取（`required property string title` 等），
//!   彻底去掉 `JSON.parse`。

use super::shared::{
    InstanceRow, ROLE_CAN_UPDATE, ROLE_GAME_VERSION, ROLE_ICON_NAME, ROLE_INSTANCE_ID,
    ROLE_LOADER_SUMMARY, ROLE_SELECTED, ROLE_SUBTITLE, ROLE_TAG, ROLE_TITLE, filter_rows,
    ok_message,
};

#[cxx_qt::bridge]
pub mod game_model {
    extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qbytearray.h");
        type QByteArray = cxx_qt_lib::QByteArray;
        include!("cxx-qt-lib/qvariant.h");
        type QVariant = cxx_qt_lib::QVariant;
        include!("cxx-qt-lib/qmodelindex.h");
        type QModelIndex = cxx_qt_lib::QModelIndex;
        include!("cxx-qt-lib/qhash_i32_QByteArray.h");
        type QHash_i32_QByteArray = cxx_qt_lib::QHash<cxx_qt_lib::QHashPair_i32_QByteArray>;

        include!(<QtCore/QAbstractListModel>);
        type QAbstractListModel;
    }

    extern "RustQt" {
        #[qobject]
        #[base = QAbstractListModel]
        #[qml_element]
        #[qproperty(i32, count)]
        #[qproperty(bool, loading)]
        #[qproperty(bool, is_empty, cxx_name = "isEmpty")]
        #[namespace = "launcher_qt_models"]
        type GameListModel = super::GameListModelRust;

        #[qinvokable]
        fn refresh(self: Pin<&mut GameListModel>);

        #[qinvokable]
        #[cxx_name = "setSearch"]
        fn set_search(self: Pin<&mut GameListModel>, text: QString);

        #[qinvokable]
        #[cxx_name = "selectInstance"]
        fn select_instance(self: Pin<&mut GameListModel>, id: QString);

        #[qinvokable]
        #[cxx_name = "renameInstance"]
        fn rename_instance(
            self: Pin<&mut GameListModel>,
            id: QString,
            new_name: QString,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "duplicateInstance"]
        fn duplicate_instance(
            self: Pin<&mut GameListModel>,
            id: QString,
            new_name: QString,
            copy_saves: bool,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "removeInstance"]
        fn remove_instance(self: Pin<&mut GameListModel>, id: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "openFolder"]
        fn open_folder(self: Pin<&mut GameListModel>, id: QString) -> QString;
    }

    // QAbstractListModel 虚函数重写。
    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_override]
        fn data(self: &GameListModel, index: &QModelIndex, role: i32) -> QVariant;

        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "rowCount"]
        fn row_count(self: &GameListModel, parent: &QModelIndex) -> i32;

        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "roleNames"]
        fn role_names(self: &GameListModel) -> QHash_i32_QByteArray;
    }

    // 继承自基类的 protected 方法（用于全量刷新）。
    extern "RustQt" {
        #[inherit]
        #[cxx_name = "beginResetModel"]
        unsafe fn begin_reset_model(self: Pin<&mut GameListModel>);

        #[inherit]
        #[cxx_name = "endResetModel"]
        unsafe fn end_reset_model(self: Pin<&mut GameListModel>);
    }
}

#[derive(Default)]
pub struct GameListModelRust {
    count: i32,
    loading: bool,
    is_empty: bool,
    all_rows: Vec<InstanceRow>,
    view_rows: Vec<InstanceRow>,
    search_text: String,
    selected_id: String,
}

use core::pin::Pin;
use cxx_qt::CxxQtType;
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QModelIndex, QString, QVariant};

impl game_model::GameListModel {
    /// 从 InstanceService 重新加载列表并按当前搜索词过滤，全量 reset 模型。
    pub fn refresh(mut self: Pin<&mut Self>) {
        let dto = launcher_app::InstanceService::list().unwrap_or_default();
        let all: Vec<InstanceRow> = dto.instances.iter().map(InstanceRow::from_item).collect();
        let search = self.as_ref().rust().search_text.clone();
        let view = filter_rows(&all, &search);
        let count = view.len() as i32;
        let selected = dto.selected_instance;

        unsafe { self.as_mut().begin_reset_model() };
        {
            let model = self.as_mut().rust_mut().get_mut();
            model.all_rows = all;
            model.view_rows = view;
            model.selected_id = selected;
        }
        unsafe { self.as_mut().end_reset_model() };

        self.as_mut().set_count(count);
        self.as_mut().set_is_empty(count == 0);
        self.as_mut().set_loading(false);
    }

    /// 更新搜索词并重算可见行（不重新读盘）。
    pub fn set_search(mut self: Pin<&mut Self>, text: QString) {
        let search = String::from(&text);
        let view = filter_rows(&self.as_ref().rust().all_rows, &search);
        let count = view.len() as i32;

        unsafe { self.as_mut().begin_reset_model() };
        {
            let model = self.as_mut().rust_mut().get_mut();
            model.search_text = search;
            model.view_rows = view;
        }
        unsafe { self.as_mut().end_reset_model() };

        self.as_mut().set_count(count);
        self.as_mut().set_is_empty(count == 0);
    }

    /// 设为当前实例并刷新（对齐 HMCL `Profiles.setSelectedInstance`）。
    pub fn select_instance(mut self: Pin<&mut Self>, id: QString) {
        let _ = launcher_app::InstanceService::select(&String::from(&id));
        self.refresh();
    }

    pub fn rename_instance(mut self: Pin<&mut Self>, id: QString, new_name: QString) -> QString {
        let message = ok_message(launcher_app::InstanceService::rename(
            &String::from(&id),
            &String::from(&new_name),
        ));
        self.as_mut().refresh();
        QString::from(&message)
    }

    pub fn duplicate_instance(
        mut self: Pin<&mut Self>,
        id: QString,
        new_name: QString,
        copy_saves: bool,
    ) -> QString {
        let message = ok_message(launcher_app::InstanceService::duplicate(
            &String::from(&id),
            &String::from(&new_name),
            copy_saves,
        ));
        self.as_mut().refresh();
        QString::from(&message)
    }

    pub fn remove_instance(mut self: Pin<&mut Self>, id: QString) -> QString {
        let message = ok_message(launcher_app::InstanceService::delete(&String::from(&id)));
        self.as_mut().refresh();
        QString::from(&message)
    }

    pub fn open_folder(self: Pin<&mut Self>, id: QString) -> QString {
        match launcher_app::InstanceService::open_folder(&String::from(&id), None) {
            Ok(path) => QString::from(&path.display().to_string()),
            Err(err) => QString::from(&err.to_string()),
        }
    }

    pub fn data(&self, index: &QModelIndex, role: i32) -> QVariant {
        let Some(row) = self.rust().view_rows.get(index.row() as usize) else {
            return QVariant::default();
        };
        match role {
            ROLE_INSTANCE_ID => QVariant::from(&QString::from(&row.id)),
            ROLE_TITLE => QVariant::from(&QString::from(&row.title)),
            ROLE_SUBTITLE => QVariant::from(&QString::from(&row.subtitle)),
            ROLE_TAG => QVariant::from(&QString::from(&row.tag)),
            ROLE_ICON_NAME => QVariant::from(&QString::from(&row.icon_name)),
            ROLE_SELECTED => QVariant::from(&row.selected),
            ROLE_CAN_UPDATE => QVariant::from(&row.can_update),
            ROLE_GAME_VERSION => QVariant::from(&QString::from(&row.game_version)),
            ROLE_LOADER_SUMMARY => QVariant::from(&QString::from(&row.loader_summary)),
            _ => QVariant::default(),
        }
    }

    pub fn row_count(&self, _parent: &QModelIndex) -> i32 {
        self.rust().view_rows.len() as i32
    }

    pub fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut roles = QHash::<QHashPair_i32_QByteArray>::default();
        roles.insert(ROLE_INSTANCE_ID, QByteArray::from("instanceId"));
        roles.insert(ROLE_TITLE, QByteArray::from("title"));
        roles.insert(ROLE_SUBTITLE, QByteArray::from("subtitle"));
        roles.insert(ROLE_TAG, QByteArray::from("tag"));
        roles.insert(ROLE_ICON_NAME, QByteArray::from("iconName"));
        roles.insert(ROLE_SELECTED, QByteArray::from("selected"));
        roles.insert(ROLE_CAN_UPDATE, QByteArray::from("canUpdate"));
        roles.insert(ROLE_GAME_VERSION, QByteArray::from("gameVersion"));
        roles.insert(ROLE_LOADER_SUMMARY, QByteArray::from("loaderSummary"));
        roles
    }
}
