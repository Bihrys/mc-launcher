pub struct AssetsRepository;
impl AssetsRepository { pub fn clear() -> Result<(), crate::InstanceError> { crate::clear_assets() } }
