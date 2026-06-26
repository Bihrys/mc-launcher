pub struct JavaService;

impl JavaService {
    pub fn detect() -> Vec<launcher_core::JavaRuntime> { launcher_core::detect_java_runtimes() }
}
