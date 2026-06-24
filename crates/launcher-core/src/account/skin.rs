use super::model::{Account, AccountError, SkinModel};
use std::path::Path;

pub struct AccountSkinService;

impl AccountSkinService {
    pub fn validate_skin_file(path: &Path) -> Result<(), AccountError> {
        let image = image::open(path)?;
        let width = image.width();
        let height = image.height();

        if width != 64 || (height != 32 && height != 64) {
            return Err(simple_error(format!(
                "皮肤图片尺寸必须是 64x32 或 64x64，当前是 {width}x{height}。"
            )));
        }

        Ok(())
    }

    pub fn upload<M: Into<SkinModel>>(
        account: &Account,
        skin_file: &Path,
        model: M,
    ) -> Result<Account, AccountError> {
        let model = model.into();
        Self::validate_skin_file(skin_file)?;
        crate::auth::upload_account_skin(account, skin_file, model.is_slim())
    }
}

fn simple_error(message: impl Into<String>) -> AccountError {
    Box::new(std::io::Error::new(
        std::io::ErrorKind::Other,
        message.into(),
    ))
}
