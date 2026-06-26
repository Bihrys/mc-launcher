use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct GameDirectory { pub root: PathBuf }
impl GameDirectory { pub fn versions_dir(&self) -> PathBuf { self.root.join("versions") } }
