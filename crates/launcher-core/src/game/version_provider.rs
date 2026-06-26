pub trait VersionProvider {
    fn list_versions(&self) -> Result<String, Box<dyn std::error::Error + Send + Sync>>;
}
