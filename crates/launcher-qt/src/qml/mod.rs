//! `qml` 层各 ListModel 共享的行结构、过滤逻辑与角色常量。
//!
//! 真正的 cxx-qt bridge（`game_list_models.rs` / `profile_list_model.rs`）按
//! cxx-qt-build 的要求与 `backend.rs` 同级放在 `src/` 根；本模块只放它们共享的
//! 普通 Rust 代码。
pub mod shared;
