use crate::backend::qobject;
use core::pin::Pin;
use cxx_qt_lib::QString;

impl qobject::LauncherBackend {
    pub fn detect_java(mut self: Pin<&mut Self>) {
        let runtimes = launcher_core::detect_java_runtimes();

        let items: Vec<serde_json::Value> = runtimes
            .iter()
            .map(|runtime| {
                serde_json::json!({
                    "path": runtime.executable.display().to_string(),
                    "version": runtime.version.clone().unwrap_or_default(),
                    "major": runtime.major.map(|m| m.to_string()).unwrap_or_default(),
                    "vendor": runtime.vendor_hint.clone().unwrap_or_default(),
                })
            })
            .collect();

        let json = serde_json::json!({ "runtimes": items }).to_string();
        self.as_mut().set_detected_java_json(QString::from(&json));

        let text = if runtimes.is_empty() {
            "未检测到本机 Java 运行时。".to_string()
        } else {
            format!("已检测到 {} 个 Java 运行时。", runtimes.len())
        };

        self.as_mut().set_output(QString::from(&text));
    }

    pub fn download_java(
        mut self: Pin<&mut Self>,
        distribution: QString,
        major: QString,
        package_type: QString,
    ) {
        let distribution = distribution.to_string();
        let package_type = package_type.to_string();
        let major_text = major.to_string();

        let major = match major_text.trim().parse::<u32>() {
            Ok(major) => major,
            Err(err) => {
                self.as_mut().set_output(QString::from(&format!(
                    "Java 下载失败：无效 Java 版本 `{major_text}`\n\n{err}"
                )));
                return;
            }
        };

        self.as_mut().set_output(QString::from(&format!(
            "准备下载 Java...\n\n发行版: {distribution}\n版本: Java {major}\n包类型: {package_type}\n"
        )));

        match launcher_core::download_java_runtime(&distribution, major, &package_type) {
            Ok(result) => {
                let text = format!(
                    "Java 下载完成。\n\n发行版: {}\n包类型: {}\nJava 大版本: {}\nJava 版本: {}\n发行版版本: {}\n文件名: {}\n\n压缩包:\n{}\n\n安装目录:\n{}\n\nJava 可执行文件:\n{}\n",
                    result.distribution,
                    result.package_type,
                    result.major,
                    result.java_version,
                    result.distribution_version,
                    result.file_name,
                    result.archive_path.display(),
                    result.install_dir.display(),
                    result.java_binary.display(),
                );

                self.as_mut().set_output(QString::from(&text));
            }
            Err(err) => {
                let text = format!(
                    "Java 下载失败。\n\n发行版: {distribution}\n版本: Java {major}\n包类型: {package_type}\n\n{err}"
                );

                self.as_mut().set_output(QString::from(&text));
            }
        }
    }
}
