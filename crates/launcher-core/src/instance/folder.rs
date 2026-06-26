use crate::instance::model::InstanceError;
use std::path::PathBuf;

pub struct InstanceFolderService;

impl InstanceFolderService {
    pub fn open(id: &str, sub: &str) -> Result<PathBuf, InstanceError> {
        crate::instance_manager::open_instance_folder(id, sub)
    }
}
