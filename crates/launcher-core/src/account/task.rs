use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AccountTaskKind {
    Refresh,
    UploadSkin,
    MigrateStorage,
    CleanupAvatarCache,
}

impl AccountTaskKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Refresh => "account.refresh",
            Self::UploadSkin => "account.uploadSkin",
            Self::MigrateStorage => "account.migrateStorage",
            Self::CleanupAvatarCache => "account.cleanupAvatarCache",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountTaskStatus {
    pub active: bool,
    pub index: i64,
    pub kind: String,
    pub title: String,
    pub message: String,
    pub success: bool,
    pub accounts_json: String,
    pub current_account_name: String,
    pub current_account_kind: String,
    pub current_account_avatar_url: String,
    pub error: String,
}

impl AccountTaskStatus {
    pub fn idle() -> Self {
        Self {
            active: false,
            index: -1,
            kind: String::new(),
            title: "账户任务".to_string(),
            message: "还没有账户任务。".to_string(),
            success: false,
            accounts_json: String::new(),
            current_account_name: String::new(),
            current_account_kind: String::new(),
            current_account_avatar_url: String::new(),
            error: String::new(),
        }
    }
}
