pub mod java;

pub use java::{JavaRuntime, detect_java_runtimes};

pub struct LauncherInfo {
    pub name: &'static str,
    pub version: &'static str,
    pub platform: &'static str,
}

pub fn launcher_info() -> LauncherInfo {
    LauncherInfo {
        name: "mc-launcher",
        version: env!("CARGO_PKG_VERSION"),
        platform: std::env::consts::OS,
    }
}
