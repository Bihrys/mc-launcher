pub struct LibrariesRepository;
impl LibrariesRepository { pub fn clear() -> Result<(), crate::InstanceError> { crate::clear_libraries() } }
