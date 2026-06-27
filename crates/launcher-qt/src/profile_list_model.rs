//! 游戏目录（Profile）列表的真实 ListModel。
//!
//! 当前 core 只有单个默认游戏目录，多目录的增删切换是后续切片；这里实现成
//! 真正的 `QAbstractListModel`，让 Profile 面板与实例列表共用同一套
//! role-based 模式（无 `JSON.parse`），为将来的多目录管理打好基础。
//!
//! 与 `game_list_models.rs` 同级放在 `src/` 根（cxx-qt-build 要求 bridge 同目录）。

use crate::qml::shared::{
    ProfileRow, ROLE_PROFILE_ID, ROLE_PROFILE_NAME, ROLE_PROFILE_PATH, ROLE_PROFILE_SELECTED,
};

#[cxx_qt::bridge]
pub mod profile_model {
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
        #[namespace = "launcher_qt_models"]
        type ProfileListModel = super::ProfileListModelRust;

        #[qinvokable]
        fn refresh(self: Pin<&mut ProfileListModel>);
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        #[cxx_override]
        fn data(self: &ProfileListModel, index: &QModelIndex, role: i32) -> QVariant;

        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "rowCount"]
        fn row_count(self: &ProfileListModel, parent: &QModelIndex) -> i32;

        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "roleNames"]
        fn role_names(self: &ProfileListModel) -> QHash_i32_QByteArray;
    }

    extern "RustQt" {
        #[inherit]
        #[cxx_name = "beginResetModel"]
        unsafe fn begin_reset_model(self: Pin<&mut ProfileListModel>);

        #[inherit]
        #[cxx_name = "endResetModel"]
        unsafe fn end_reset_model(self: Pin<&mut ProfileListModel>);
    }
}

#[derive(Default)]
pub struct ProfileListModelRust {
    count: i32,
    rows: Vec<ProfileRow>,
}

use core::pin::Pin;
use cxx_qt::CxxQtType;
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QModelIndex, QString, QVariant};

impl profile_model::ProfileListModel {
    pub fn refresh(mut self: Pin<&mut Self>) {
        let dto = launcher_app::InstanceService::list().unwrap_or_default();
        let rows: Vec<ProfileRow> = dto.profiles.iter().map(ProfileRow::from_item).collect();
        let count = rows.len() as i32;

        unsafe { self.as_mut().begin_reset_model() };
        self.as_mut().rust_mut().get_mut().rows = rows;
        unsafe { self.as_mut().end_reset_model() };

        self.as_mut().set_count(count);
    }

    pub fn data(&self, index: &QModelIndex, role: i32) -> QVariant {
        let Some(row) = self.rust().rows.get(index.row() as usize) else {
            return QVariant::default();
        };
        match role {
            ROLE_PROFILE_ID => QVariant::from(&QString::from(&row.id)),
            ROLE_PROFILE_NAME => QVariant::from(&QString::from(&row.name)),
            ROLE_PROFILE_PATH => QVariant::from(&QString::from(&row.path)),
            ROLE_PROFILE_SELECTED => QVariant::from(&row.selected),
            _ => QVariant::default(),
        }
    }

    pub fn row_count(&self, _parent: &QModelIndex) -> i32 {
        self.rust().rows.len() as i32
    }

    pub fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut roles = QHash::<QHashPair_i32_QByteArray>::default();
        roles.insert(ROLE_PROFILE_ID, QByteArray::from("profileId"));
        roles.insert(ROLE_PROFILE_NAME, QByteArray::from("profileName"));
        roles.insert(ROLE_PROFILE_PATH, QByteArray::from("profilePath"));
        roles.insert(ROLE_PROFILE_SELECTED, QByteArray::from("selected"));
        roles
    }
}
