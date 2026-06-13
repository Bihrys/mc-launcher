#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");

        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, output)]
        #[namespace = "launcher_backend"]
        type LauncherBackend = super::LauncherBackendRust;

        #[qinvokable]
        #[cxx_name = "detectJava"]
        fn detect_java(self: Pin<&mut LauncherBackend>);
    }
}

use core::pin::Pin;

use cxx_qt_lib::QString;

#[derive(Default)]
pub struct LauncherBackendRust {
    output: QString,
}

impl qobject::LauncherBackend {
    pub fn detect_java(self: Pin<&mut Self>) {
        let runtimes = launcher_core::detect_java_runtimes();

        let text = if runtimes.is_empty() {
            "No Java runtime found.".to_string()
        } else {
            let mut text = String::from("Detected Java runtimes:\n\n");

            for runtime in runtimes {
                let version = runtime.version.as_deref().unwrap_or("unknown");
                let major = runtime
                    .major
                    .map(|major| major.to_string())
                    .unwrap_or_else(|| "unknown".to_string());

                text.push_str(&format!("- {}\n", runtime.executable.display()));
                text.push_str(&format!("  version: {version}\n"));
                text.push_str(&format!("  major: {major}\n"));

                if let Some(vendor) = runtime.vendor_hint {
                    text.push_str(&format!("  vendor: {vendor}\n"));
                }

                text.push('\n');
            }

            text
        };

        self.set_output(QString::from(&text));
    }
}
