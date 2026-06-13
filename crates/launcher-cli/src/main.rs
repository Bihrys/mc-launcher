use launcher_core::{detect_java_runtimes, launcher_info};

fn main() {
    let info = launcher_info();

    println!("{} {}", info.name, info.version);
    println!("platform: {}", info.platform);
    println!();

    let runtimes = detect_java_runtimes();

    if runtimes.is_empty() {
        println!("No Java runtime found.");
        return;
    }

    println!("Detected Java runtimes:");

    for runtime in runtimes {
        let version = runtime.version.as_deref().unwrap_or("unknown");
        let major = runtime
            .major
            .map(|major| major.to_string())
            .unwrap_or_else(|| "unknown".to_string());

        println!("- {}", runtime.executable.display());
        println!("  version: {}", version);
        println!("  major: {}", major);

        if let Some(vendor) = runtime.vendor_hint {
            println!("  vendor: {}", vendor);
        }
    }
}
