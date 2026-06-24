use super::model::{Account, AccountError};

pub struct AccountRepository;

impl AccountRepository {
    pub fn list() -> Result<Vec<Account>, AccountError> {
        crate::auth::load_accounts()
    }

    pub fn save(account: &Account) -> Result<std::path::PathBuf, AccountError> {
        crate::auth::save_account(account)
    }

    pub fn selected() -> Result<Option<Account>, AccountError> {
        crate::auth::selected_account()
    }

    pub fn select(account: &Account) -> Result<(), AccountError> {
        crate::auth::select_account(account)
    }

    pub fn select_identifier(identifier: &str) -> Result<(), AccountError> {
        crate::auth::select_account_identifier(identifier)
    }

    pub fn identifier(account: &Account) -> String {
        crate::auth::account_identifier(account)
    }

    pub fn find_by_identifier(identifier: &str) -> Result<Option<Account>, AccountError> {
        Ok(Self::list()?
            .into_iter()
            .find(|account| Self::identifier(account) == identifier))
    }

    pub fn delete(identifier: &str) -> Result<Vec<Account>, AccountError> {
        let account = Self::find_by_identifier(identifier)?
            .ok_or_else(|| simple_error("没有找到要删除的账户。"))?;

        crate::auth::delete_account(&account.kind, &account.uuid, account.server_url.as_deref())
    }

    pub fn delete_parts(
        kind: &str,
        uuid: &str,
        server_url: Option<&str>,
    ) -> Result<Vec<Account>, AccountError> {
        crate::auth::delete_account(kind, uuid, server_url)
    }
}

fn simple_error(message: impl Into<String>) -> AccountError {
    Box::new(std::io::Error::new(
        std::io::ErrorKind::Other,
        message.into(),
    ))
}
