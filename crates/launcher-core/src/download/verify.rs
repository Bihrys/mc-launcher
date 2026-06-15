use crate::download::DownloadError;
use sha1::{Digest, Sha1};
use std::fs::File;
use std::io::Read;
use std::path::Path;

pub fn is_valid_file(
    path: &Path,
    expected_size: Option<u64>,
    expected_sha1: Option<&str>,
) -> Result<bool, DownloadError> {
    if !path.exists() {
        return Ok(false);
    }

    let metadata = path.metadata()?;

    if let Some(size) = expected_size {
        if metadata.len() != size {
            return Ok(false);
        }
    }

    if let Some(sha1) = expected_sha1 {
        if !sha1.trim().is_empty() {
            let actual = sha1_file(path)?;

            if !actual.eq_ignore_ascii_case(sha1) {
                return Ok(false);
            }
        }
    }

    Ok(true)
}

fn sha1_file(path: &Path) -> Result<String, DownloadError> {
    let mut file = File::open(path)?;
    let mut hasher = Sha1::new();
    let mut buffer = [0_u8; 64 * 1024];

    loop {
        let read = file.read(&mut buffer)?;

        if read == 0 {
            break;
        }

        hasher.update(&buffer[..read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}
