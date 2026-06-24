use super::auth_server::AuthServerRepository;
use super::avatar::AccountAvatarService;
use super::model::{Account, AccountError, AuthServer, SkinModel, StorageScope};
use super::repository::AccountRepository;
use super::skin::AccountSkinService;
use std::path::Path;

pub struct AccountService;

impl AccountService {
    pub fn list() -> Result<Vec<Account>, AccountError> {
        AccountRepository::list()
    }

    pub fn selected() -> Result<Option<Account>, AccountError> {
        AccountRepository::selected()
    }

    pub fn save(account: &Account) -> Result<std::path::PathBuf, AccountError> {
        AccountRepository::save(account)
    }

    pub fn identifier(account: &Account) -> String {
        AccountRepository::identifier(account)
    }

    pub fn select(identifier: &str) -> Result<(), AccountError> {
        AccountRepository::select_identifier(identifier)
    }

    pub fn select_account(account: &Account) -> Result<(), AccountError> {
        AccountRepository::select(account)
    }

    pub fn delete(identifier: &str) -> Result<Vec<Account>, AccountError> {
        AccountRepository::delete(identifier)
    }

    pub fn delete_account_parts(
        kind: &str,
        uuid: &str,
        server_url: Option<&str>,
    ) -> Result<Vec<Account>, AccountError> {
        AccountRepository::delete_parts(kind, uuid, server_url)
    }

    pub fn refresh(identifier: &str) -> Result<Account, AccountError> {
        let account = AccountRepository::find_by_identifier(identifier)?
            .ok_or_else(|| simple_error("没有找到要刷新的账户。"))?;

        let updated = crate::auth::refresh_account(&account)?;
        AccountRepository::save(&updated)?;
        Ok(updated)
    }

    pub fn refresh_account(account: &Account) -> Result<Account, AccountError> {
        crate::auth::refresh_account(account)
    }

    pub fn upload_skin<M: Into<SkinModel>>(
        identifier: &str,
        skin_file: &Path,
        model: M,
    ) -> Result<Account, AccountError> {
        let account = AccountRepository::find_by_identifier(identifier)?
            .ok_or_else(|| simple_error("没有找到要上传皮肤的账户。"))?;

        AccountSkinService::upload(&account, skin_file, model)
    }

    pub fn upload_skin_for_account<M: Into<SkinModel>>(
        account: &Account,
        skin_file: &Path,
        model: M,
    ) -> Result<Account, AccountError> {
        AccountSkinService::upload(account, skin_file, model)
    }

    pub fn migrate_storage(
        identifier: &str,
        target: StorageScope,
    ) -> Result<Account, AccountError> {
        let account = AccountRepository::find_by_identifier(identifier)?
            .ok_or_else(|| simple_error("没有找到要迁移的账户。"))?;

        crate::auth::migrate_account_storage(&account, target.as_raw())
    }

    pub fn migrate_storage_for_account(
        account: &Account,
        target: &str,
    ) -> Result<Account, AccountError> {
        crate::auth::migrate_account_storage(account, target)
    }

    pub fn list_auth_servers() -> Result<Vec<AuthServer>, AccountError> {
        AuthServerRepository::list()
    }

    pub fn save_auth_servers(servers: &[AuthServer]) -> Result<(), AccountError> {
        AuthServerRepository::save(servers)
    }

    pub fn add_auth_server(name: &str, url: &str) -> Result<Vec<AuthServer>, AccountError> {
        AuthServerRepository::add(name, url)
    }

    pub fn remove_auth_server_by_index(index: usize) -> Result<Vec<AuthServer>, AccountError> {
        AuthServerRepository::remove(index)
    }

    pub fn cleanup_avatar_cache(max_age_days: u64) -> Result<usize, AccountError> {
        AccountAvatarService::cleanup_cache(max_age_days)
    }

    pub fn avatar_url(account: &Account, size: u32) -> Result<Option<String>, AccountError> {
        AccountAvatarService::account_avatar_url(account, size)
    }

    pub fn offline_avatar_preview(username: &str, size: u32) -> Result<String, AccountError> {
        AccountAvatarService::offline_default_avatar_url(username, size)
    }

    pub fn yggdrasil_profile_avatar_url(
        server_url: &str,
        uuid: &str,
        size: u32,
    ) -> Result<Option<String>, AccountError> {
        AccountAvatarService::yggdrasil_profile_avatar_url(server_url, uuid, size)
    }

    // 协议入口统一挂到 AccountService，Qt 后端不再散调 auth.rs。
    pub fn login_offline(username: &str) -> Result<Account, AccountError> {
        crate::auth::login_offline(username)
    }

    pub fn login_microsoft_browser(client_id: &str) -> Result<Account, AccountError> {
        crate::auth::login_microsoft_browser(client_id)
    }

    pub fn login_yggdrasil(
        server_url: &str,
        login_username: &str,
        password: &str,
    ) -> Result<Account, AccountError> {
        crate::auth::login_yggdrasil(server_url, login_username, password)
    }

    pub fn login_yggdrasil_start(
        server_url: &str,
        login_username: &str,
        password: &str,
    ) -> Result<crate::auth::YggdrasilLoginResult, AccountError> {
        crate::auth::login_yggdrasil_start(server_url, login_username, password)
    }

    pub fn complete_yggdrasil_login(
        pending: &crate::auth::YggdrasilPendingLogin,
        profile_index: usize,
    ) -> Result<Account, AccountError> {
        crate::auth::complete_yggdrasil_login(pending, profile_index)
    }
}

fn simple_error(message: impl Into<String>) -> AccountError {
    Box::new(std::io::Error::new(
        std::io::ErrorKind::Other,
        message.into(),
    ))
}
