use super::model::{Account, AccountError};

pub struct AccountAvatarService;

impl AccountAvatarService {
    pub fn account_avatar_url(
        account: &Account,
        size: u32,
    ) -> Result<Option<String>, AccountError> {
        crate::avatar::account_avatar_url(account, size)
    }

    pub fn offline_default_avatar_url(username: &str, size: u32) -> Result<String, AccountError> {
        crate::avatar::offline_default_avatar_url(username, size)
    }

    pub fn yggdrasil_profile_avatar_url(
        server_url: &str,
        uuid: &str,
        size: u32,
    ) -> Result<Option<String>, AccountError> {
        crate::avatar::yggdrasil_profile_avatar_url(server_url, uuid, size)
    }

    pub fn cleanup_cache(max_age_days: u64) -> Result<usize, AccountError> {
        crate::auth::cleanup_avatar_cache(max_age_days)
    }
}
