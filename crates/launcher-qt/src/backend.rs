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
        #[qproperty(QString, current_account_name, cxx_name = "currentAccountName")]
        #[qproperty(QString, current_account_kind, cxx_name = "currentAccountKind")]
        #[qproperty(
            QString,
            current_account_avatar_url,
            cxx_name = "currentAccountAvatarUrl"
        )]
        #[qproperty(QString, accounts_json, cxx_name = "accountsJson")]
        #[qproperty(
            QString,
            pending_yggdrasil_profiles_json,
            cxx_name = "pendingYggdrasilProfilesJson"
        )]
        #[qproperty(QString, auth_servers_json, cxx_name = "authServersJson")]
        #[qproperty(QString, download_catalog_json, cxx_name = "downloadCatalogJson")]
        #[qproperty(QString, download_task_json, cxx_name = "downloadTaskJson")]
        #[qproperty(QString, installed_versions_json, cxx_name = "installedVersionsJson")]
        #[qproperty(QString, instance_list_json, cxx_name = "instanceListJson")]
        #[qproperty(QString, instance_detail_json, cxx_name = "instanceDetailJson")]
        #[qproperty(QString, selected_game_version, cxx_name = "selectedGameVersion")]
        #[qproperty(QString, launch_task_json, cxx_name = "launchTaskJson")]
        #[qproperty(QString, launcher_settings_json, cxx_name = "launcherSettingsJson")]
        #[qproperty(QString, detected_java_json, cxx_name = "detectedJavaJson")]
        #[namespace = "launcher_backend"]
        type LauncherBackend = super::LauncherBackendRust;

        #[qinvokable]
        #[cxx_name = "detectJava"]
        fn detect_java(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "downloadJava"]
        fn download_java(
            self: Pin<&mut LauncherBackend>,
            distribution: QString,
            major: QString,
            package_type: QString,
        );

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
        #[cxx_name = "pollYggdrasilLoginTask"]
        fn poll_yggdrasil_login_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "loginMicrosoftBrowser"]
        fn login_microsoft_browser(self: Pin<&mut LauncherBackend>, client_id: QString);

        #[qinvokable]
        #[cxx_name = "selectYggdrasilProfile"]
        fn select_yggdrasil_profile(self: Pin<&mut LauncherBackend>, index: QString);

        #[qinvokable]
        #[cxx_name = "refreshAccounts"]
        fn refresh_accounts(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "refreshAuthServers"]
        fn refresh_auth_servers(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "addAuthServer"]
        fn add_auth_server(self: Pin<&mut LauncherBackend>, name: QString, url: QString)
        -> QString;

        #[qinvokable]
        #[cxx_name = "deleteAuthServer"]
        fn delete_auth_server(self: Pin<&mut LauncherBackend>, index: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "offlineAvatarPreview"]
        fn offline_avatar_preview(self: Pin<&mut LauncherBackend>, username: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "switchAccount"]
        fn switch_account(self: Pin<&mut LauncherBackend>, index: QString);

        #[qinvokable]
        #[cxx_name = "switchAccountFast"]
        fn switch_account_fast(
            self: Pin<&mut LauncherBackend>,
            index: QString,
            username: QString,
            display_kind: QString,
            avatar_url: QString,
        );

        #[qinvokable]
        #[cxx_name = "switchAccountByIdentifier"]
        fn switch_account_by_identifier(
            self: Pin<&mut LauncherBackend>,
            identifier: QString,
            username: QString,
            display_kind: QString,
            avatar_url: QString,
        );

        #[qinvokable]
        #[cxx_name = "deleteAccount"]
        fn delete_account(self: Pin<&mut LauncherBackend>, index: QString);

        #[qinvokable]
        #[cxx_name = "startRefreshAccount"]
        fn start_refresh_account(self: Pin<&mut LauncherBackend>, index: QString);

        #[qinvokable]
        #[cxx_name = "startUploadSkin"]
        fn start_upload_skin(
            self: Pin<&mut LauncherBackend>,
            index: QString,
            file_url: QString,
            model: QString,
        );

        #[qinvokable]
        #[cxx_name = "startMigrateAccount"]
        fn start_migrate_account(self: Pin<&mut LauncherBackend>, index: QString, target: QString);

        #[qinvokable]
        #[cxx_name = "startCleanupAvatarCache"]
        fn start_cleanup_avatar_cache(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "pollRefreshAccountTask"]
        fn poll_refresh_account_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "refreshDownloadCatalog"]
        fn refresh_download_catalog(self: Pin<&mut LauncherBackend>, source: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "startRefreshDownloadCatalog"]
        fn start_refresh_download_catalog(self: Pin<&mut LauncherBackend>, source: QString);

        #[qinvokable]
        #[cxx_name = "pollDownloadCatalogTask"]
        fn poll_download_catalog_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "startFetchInstallerMetadata"]
        fn start_fetch_installer_metadata(
            self: Pin<&mut LauncherBackend>,
            source: QString,
            game_version: QString,
        );

        #[qinvokable]
        #[cxx_name = "startFetchLoaderMetadata"]
        fn start_fetch_loader_metadata(
            self: Pin<&mut LauncherBackend>,
            source: QString,
            game_version: QString,
            loader_kind: QString,
        );

        #[qinvokable]
        #[cxx_name = "pollInstallerMetadataTask"]
        fn poll_installer_metadata_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "installGameVersion"]
        fn install_game_version(
            self: Pin<&mut LauncherBackend>,
            source: QString,
            game_version: QString,
            loader_kind: QString,
            loader_version: QString,
        );

        #[qinvokable]
        #[cxx_name = "pollDownloadTask"]
        fn poll_download_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "cancelDownloadTask"]
        fn cancel_download_task(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "refreshInstalledVersions"]
        fn refresh_installed_versions(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "refreshInstances"]
        fn refresh_instances(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "refreshInstanceDetail"]
        fn refresh_instance_detail(self: Pin<&mut LauncherBackend>, version_id: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "selectInstance"]
        fn select_instance(self: Pin<&mut LauncherBackend>, version_id: QString);

        #[qinvokable]
        #[cxx_name = "renameInstance"]
        fn rename_instance(
            self: Pin<&mut LauncherBackend>,
            version_id: QString,
            new_name: QString,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "duplicateInstance"]
        fn duplicate_instance(
            self: Pin<&mut LauncherBackend>,
            version_id: QString,
            new_name: QString,
            copy_saves: QString,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "deleteInstance"]
        fn delete_instance(self: Pin<&mut LauncherBackend>, version_id: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "openInstanceFolder"]
        fn open_instance_folder(
            self: Pin<&mut LauncherBackend>,
            version_id: QString,
            folder_key: QString,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "generateInstanceLaunchCommand"]
        fn generate_instance_launch_command(
            self: Pin<&mut LauncherBackend>,
            version_id: QString,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "cleanInstance"]
        fn clean_instance(self: Pin<&mut LauncherBackend>, version_id: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "clearInstanceAssets"]
        fn clear_instance_assets(self: Pin<&mut LauncherBackend>, version_id: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "clearInstanceLibraries"]
        fn clear_instance_libraries(self: Pin<&mut LauncherBackend>, version_id: QString) -> QString;

        #[qinvokable]
        #[cxx_name = "saveInstanceSettings"]
        fn save_instance_settings(
            self: Pin<&mut LauncherBackend>,
            version_id: QString,
            settings_json: QString,
        ) -> QString;

        #[qinvokable]
        #[cxx_name = "selectGameVersion"]
        fn select_game_version(self: Pin<&mut LauncherBackend>, version_id: QString);

        #[qinvokable]
        #[cxx_name = "deleteGameVersion"]
        fn delete_game_version(self: Pin<&mut LauncherBackend>, version_id: QString);

        #[qinvokable]
        #[cxx_name = "launchSelectedVersion"]
        fn launch_selected_version(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "startLaunchSelectedVersion"]
        fn start_launch_selected_version(self: Pin<&mut LauncherBackend>, visibility: QString);

        #[qinvokable]
        #[cxx_name = "cancelLaunchTask"]
        fn cancel_launch_task(self: Pin<&mut LauncherBackend>);

        #[qinvokable]
        #[cxx_name = "pollLaunchTask"]
        fn poll_launch_task(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "refreshLauncherSettings"]
        fn refresh_launcher_settings(self: Pin<&mut LauncherBackend>) -> QString;

        #[qinvokable]
        #[cxx_name = "updateLauncherSetting"]
        fn update_launcher_setting(self: Pin<&mut LauncherBackend>, key: QString, value: QString);

        #[qinvokable]
        #[cxx_name = "generateLaunchCommand"]
        fn generate_launch_command(self: Pin<&mut LauncherBackend>, version_id: QString)
        -> QString;
    }
}

use cxx_qt_lib::QString;

#[derive(Default)]
pub struct LauncherBackendRust {
    output: QString,
    current_account_name: QString,
    current_account_kind: QString,
    current_account_avatar_url: QString,
    accounts_json: QString,
    pending_yggdrasil_profiles_json: QString,
    auth_servers_json: QString,
    download_catalog_json: QString,
    download_task_json: QString,
    installed_versions_json: QString,
    instance_list_json: QString,
    instance_detail_json: QString,
    selected_game_version: QString,
    launch_task_json: QString,
    launcher_settings_json: QString,
    detected_java_json: QString,
}
