pub mod auth;
pub mod avatar;
pub mod download;
pub mod game_download;
pub mod java;
pub mod launch;
pub mod task;
pub mod java_download;
pub mod version_manager;

pub use auth::{
    AuthAccount,
    YggdrasilLoginResult,
    YggdrasilPendingLogin,
    YggdrasilProfileChoice,
    delete_account,
    load_accounts,
    login_microsoft_browser,
    login_offline,
    login_yggdrasil,
    login_yggdrasil_start,
    complete_yggdrasil_login,
    select_account,
    select_account_identifier,
    selected_account,
    account_identifier,
    save_account,
};
pub use game_download::{
    InstallResult,
    fetch_download_catalog_json,
    install_game_version,
    install_game_version_with_manager,
};
pub use java::{JavaRuntime, detect_java_runtimes};
pub use java_download::{JavaDownloadResult, download_java_runtime};

pub struct LauncherInfo {
    pub name: &'static str,
    pub version: &'static str,
    pub platform: &'static str,
}

pub fn launcher_info() -> LauncherInfo {
    LauncherInfo {
        name: "mc-launcher",
        version: env!("CARGO_PKG_VERSION"),
        platform: std::env::consts::OS,
    }
}


pub use launch::{
    LaunchOptions,
    LaunchResult,
    generate_launch_command_json,
    launch_game,
};

pub use version_manager::{
    InstalledVersion,
    delete_version,
    installed_versions,
    installed_versions_json,
    select_version,
    selected_version,
};


pub use avatar::{
    account_avatar_url,
    yggdrasil_profile_avatar_url,
};
