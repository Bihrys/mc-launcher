use serde::{Deserialize, Serialize};

pub type Account = crate::auth::AuthAccount;
pub type AccountError = crate::auth::AuthError;
pub type AuthServer = crate::auth::AuthServer;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccountKind {
    Offline,
    Microsoft,
    Yggdrasil,
    Unknown(String),
}

impl AccountKind {
    pub fn from_raw(value: &str) -> Self {
        match value {
            "offline" => Self::Offline,
            "microsoft" => Self::Microsoft,
            "yggdrasil" => Self::Yggdrasil,
            other => Self::Unknown(other.to_string()),
        }
    }

    pub fn as_raw(&self) -> &str {
        match self {
            Self::Offline => "offline",
            Self::Microsoft => "microsoft",
            Self::Yggdrasil => "yggdrasil",
            Self::Unknown(value) => value.as_str(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum StorageScope {
    Global,
    Portable,
}

impl StorageScope {
    pub fn from_raw(value: Option<&str>) -> Self {
        match value {
            Some("portable") => Self::Portable,
            _ => Self::Global,
        }
    }

    pub fn as_raw(self) -> &'static str {
        match self {
            Self::Global => "global",
            Self::Portable => "portable",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SkinModel {
    Classic,
    Slim,
}

impl SkinModel {
    pub fn from_raw(value: &str) -> Self {
        match value {
            "slim" => Self::Slim,
            _ => Self::Classic,
        }
    }

    pub fn as_raw(self) -> &'static str {
        match self {
            Self::Classic => "classic",
            Self::Slim => "slim",
        }
    }

    pub fn is_slim(self) -> bool {
        self == Self::Slim
    }
}

impl From<bool> for SkinModel {
    fn from(value: bool) -> Self {
        if value { Self::Slim } else { Self::Classic }
    }
}

impl From<&str> for SkinModel {
    fn from(value: &str) -> Self {
        Self::from_raw(value)
    }
}

impl From<String> for SkinModel {
    fn from(value: String) -> Self {
        Self::from_raw(&value)
    }
}
