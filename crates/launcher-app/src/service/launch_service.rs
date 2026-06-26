pub struct LaunchService;

impl LaunchService {
    pub fn command_json(version_id: &str) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        launcher_core::generate_launch_command_json(version_id)
    }
}
