pub struct AccountService;

impl AccountService {
    pub fn list_json() -> String {
        match launcher_core::load_accounts() {
            Ok(accounts) => serde_json::to_string(&accounts).unwrap_or_else(|_| "[]".to_string()),
            Err(_) => "[]".to_string(),
        }
    }
}
