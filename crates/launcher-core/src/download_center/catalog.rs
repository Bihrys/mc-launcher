use super::model::{DownloadCenterError, DownloadSourceKind};

pub struct DownloadCatalogService;

impl DownloadCatalogService {
    pub fn fetch_json(source: DownloadSourceKind) -> Result<String, DownloadCenterError> {
        crate::game_download::fetch_download_catalog_json(source.as_raw())
    }
}
