pub mod account;
pub mod auth;
pub mod avatar;
pub mod download;
pub mod download_center;
pub mod game_download;
pub mod java;
pub mod java_download;
pub mod launch;
pub mod task;
pub mod version_manager;

pub use account::{
    Account, AccountAvatarService, AccountError, AccountKind, AccountRepository, AccountService,
    AccountSkinService, AccountTaskKind, AccountTaskStatus, AuthServerRepository, SkinModel,
    StorageScope,
};

pub use auth::{
    AuthAccount, AuthServer, YggdrasilLoginResult, YggdrasilPendingLogin, YggdrasilProfileChoice,
    account_identifier, add_auth_server, cleanup_avatar_cache, complete_yggdrasil_login,
    delete_account, delete_auth_server, load_accounts, load_auth_servers, login_microsoft_browser,
    login_offline, login_yggdrasil, login_yggdrasil_start, migrate_account_storage,
    refresh_account, save_account, save_auth_servers, select_account, select_account_identifier,
    selected_account, upload_account_skin,
};
pub use download_center::{DownloadCatalogService, DownloadCenterTaskKind, DownloadService, DownloadSourceKind, DownloadTab, GameInstallerService, LoaderKind};

pub use game_download::{
    InstallResult, fetch_download_catalog_json, install_game_version,
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

pub use launch::{LaunchOptions, LaunchResult, generate_launch_command_json, launch_game};

pub use version_manager::{
    InstalledVersion, delete_version, installed_versions, installed_versions_json, select_version,
    selected_version,
};

pub use avatar::{account_avatar_url, offline_default_avatar_url, yggdrasil_profile_avatar_url};
