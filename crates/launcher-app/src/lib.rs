//! Application layer between launcher-core and UI frontends.
//!
//! The purpose of this crate is the same boundary HMCL keeps between
//! HMCLCore and HMCL UI pages: UI frontends talk to view models/services,
//! and this layer translates those requests into core use cases.

pub mod app_context;
pub mod command;
pub mod dto;
pub mod navigation;
pub mod profile_manager;
pub mod service;
pub mod state;
pub mod task_center;

pub use app_context::AppContext;
pub use service::{AccountService, DownloadService, InstanceService, JavaService, LaunchService, SettingsService};
