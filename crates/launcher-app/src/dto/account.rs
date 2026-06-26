use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AccountItem {
    pub identifier: String,
    pub username: String,
    pub kind: String,
    pub avatar_url: String,
}
