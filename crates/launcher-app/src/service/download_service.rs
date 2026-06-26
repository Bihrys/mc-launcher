pub struct DownloadService;

impl DownloadService {
    pub fn catalog_json(source: &str) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        launcher_core::fetch_download_catalog_json(source)
    }
}
