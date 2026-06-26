use crate::task_center::TaskCenter;

pub struct DownloadService;

impl DownloadService {
    pub fn catalog_json(source: &str) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        launcher_core::fetch_download_catalog_json(source)
    }

    pub fn refresh_catalog_task(center: &TaskCenter, source: impl Into<String>) -> String {
        let source = source.into();
        center.spawn_closure("刷新版本列表", move |ctx| {
            ctx.message("正在获取 Minecraft 版本列表...");
            ctx.set_total(100);
            ctx.set_progress(15);
            let json = launcher_core::download_center::DownloadService::fetch_catalog_json(&source)?;
            ctx.set_progress(100);
            ctx.set_property("catalogJson", json);
            Ok(())
        })
    }
}
