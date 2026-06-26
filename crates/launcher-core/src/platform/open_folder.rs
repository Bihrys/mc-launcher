use std::{path::Path, process::Command};

pub fn open_folder(path: &Path) -> std::io::Result<()> {
    let mut command = match std::env::consts::OS {
        "linux" => { let mut c = Command::new("xdg-open"); c.arg(path); c }
        "macos" => { let mut c = Command::new("open"); c.arg(path); c }
        "windows" => { let mut c = Command::new("explorer"); c.arg(path); c }
        _ => return Ok(()),
    };
    command.spawn().map(|_| ())
}
