use std::{
    collections::HashSet,
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct JavaRuntime {
    pub executable: PathBuf,
    pub version: Option<String>,
    pub major: Option<u32>,
    pub vendor_hint: Option<String>,
}

pub fn detect_java_runtimes() -> Vec<JavaRuntime> {
    let mut candidates = Vec::new();

    if let Ok(java_home) = env::var("JAVA_HOME") {
        candidates.push(PathBuf::from(java_home).join("bin/java"));
    }

    if let Some(path_java) = find_executable_in_path("java") {
        candidates.push(path_java);
    }

    candidates.push(PathBuf::from("/usr/bin/java"));

    scan_jvm_dir("/usr/lib/jvm", &mut candidates);
    scan_jvm_dir("/usr/java", &mut candidates);
    scan_jvm_dir("/opt/java", &mut candidates);

    let mut seen = HashSet::new();
    let mut runtimes = Vec::new();

    for candidate in candidates {
        let candidate = normalize_path(candidate);

        if !candidate.is_file() {
            continue;
        }

        let key = candidate.to_string_lossy().to_string();
        if !seen.insert(key) {
            continue;
        }

        if let Some(runtime) = probe_java(&candidate) {
            runtimes.push(runtime);
        }
    }

    runtimes.sort_by(|a, b| {
        b.major
            .unwrap_or(0)
            .cmp(&a.major.unwrap_or(0))
            .then_with(|| a.executable.cmp(&b.executable))
    });

    runtimes
}

fn scan_jvm_dir(root: &str, candidates: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(root) else {
        return;
    };

    for entry in entries.flatten() {
        let path = entry.path();

        if path.is_dir() {
            candidates.push(path.join("bin/java"));
        }
    }
}

fn find_executable_in_path(name: &str) -> Option<PathBuf> {
    let path_var = env::var_os("PATH")?;

    for dir in env::split_paths(&path_var) {
        let candidate = dir.join(name);

        if candidate.is_file() {
            return Some(candidate);
        }
    }

    None
}

fn normalize_path(path: PathBuf) -> PathBuf {
    fs::canonicalize(&path).unwrap_or(path)
}

fn probe_java(path: &Path) -> Option<JavaRuntime> {
    let output = Command::new(path).arg("-version").output().ok()?;

    let mut text = String::new();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    text.push_str(&String::from_utf8_lossy(&output.stdout));

    let version = parse_java_version(&text);
    let major = version.as_deref().and_then(parse_java_major);
    let vendor_hint = parse_vendor_hint(&text);

    Some(JavaRuntime {
        executable: path.to_path_buf(),
        version,
        major,
        vendor_hint,
    })
}

fn parse_java_version(text: &str) -> Option<String> {
    for line in text.lines() {
        let Some(start) = line.find('"') else {
            continue;
        };

        let rest = &line[start + 1..];
        let Some(end) = rest.find('"') else {
            continue;
        };

        return Some(rest[..end].to_string());
    }

    None
}

fn parse_java_major(version: &str) -> Option<u32> {
    let mut parts = version.split(['.', '_', '-', '+']);

    let first = parts.next()?;

    if first == "1" {
        parts.next()?.parse().ok()
    } else {
        first.parse().ok()
    }
}

fn parse_vendor_hint(text: &str) -> Option<String> {
    let first_line = text.lines().next()?.trim();

    if first_line.is_empty() {
        None
    } else {
        Some(first_line.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_modern_java_major() {
        assert_eq!(parse_java_major("17.0.10"), Some(17));
        assert_eq!(parse_java_major("21.0.2"), Some(21));
        assert_eq!(parse_java_major("26.0.1"), Some(26));
    }

    #[test]
    fn parse_legacy_java_major() {
        assert_eq!(parse_java_major("1.8.0_402"), Some(8));
    }

    #[test]
    fn parse_version_from_output() {
        let text = r#"openjdk version "21.0.2" 2024-01-16"#;
        assert_eq!(parse_java_version(text), Some("21.0.2".to_string()));
    }
}
