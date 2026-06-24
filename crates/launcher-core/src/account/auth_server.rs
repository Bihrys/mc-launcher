use super::model::{AccountError, AuthServer};

pub struct AuthServerRepository;

impl AuthServerRepository {
    pub fn list() -> Result<Vec<AuthServer>, AccountError> {
        crate::auth::load_auth_servers()
    }

    pub fn save(servers: &[AuthServer]) -> Result<(), AccountError> {
        crate::auth::save_auth_servers(servers)
    }

    pub fn add(name: &str, url: &str) -> Result<Vec<AuthServer>, AccountError> {
        crate::auth::add_auth_server(name, url)
    }

    pub fn remove(index: usize) -> Result<Vec<AuthServer>, AccountError> {
        crate::auth::delete_auth_server(index)
    }
}
