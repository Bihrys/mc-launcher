use super::super::catalog::DownloadCatalogService;
use super::super::model::{DownloadCenterError, DownloadSourceKind, InstallResult};
use super::super::processor::ForgeProcessor;
use super::super::repository::DownloadRepository;
use super::super::resolver::{DownloadResolver, simple_error};
use super::minecraft::MinecraftInstaller;
use crate::download::{DownloadFile, DownloadManager};
use std::fs;

pub struct NeoForgeInstaller;

impl NeoForgeInstaller {
    pub fn install(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        game_version: &str,
        loader_version: &str,
    ) -> Result<InstallResult, DownloadCenterError> {
        if loader_version.is_empty() {
            return Err(simple_error("没有选择 NeoForge 版本。"));
        }

        manager.set_message(format!(
            "正在安装 NeoForge 前置原版文件：Minecraft {game_version}"
        ))?;
        let base = MinecraftInstaller::install(manager, source, game_version)?;

        manager.set_message("正在查找 NeoForge installer...")?;

        let installer = DownloadCatalogService::fetch_neoforge_installers_for_game(source, game_version)?
            .into_iter()
            .find(|item| item.loader_version == loader_version)
            .ok_or_else(|| simple_error(format!(
                "没有找到 NeoForge installer：Minecraft {game_version}, NeoForge {loader_version}"
            )))?;

        let cache_dir = DownloadRepository::cache_root()?
            .join("installers")
            .join("neoforge");
        fs::create_dir_all(&cache_dir)?;

        let file_name = DownloadResolver::file_name_from_url(&installer.url);
        let target = cache_dir.join(file_name);

        manager.download_files(vec![DownloadFile::with_candidates(
            DownloadResolver::inject_url_candidates(source, &installer.url),
            target.clone(),
            None,
            None,
        )])?;

        let mut result = ForgeProcessor::install_installer(
            manager,
            source,
            "neoforge",
            game_version,
            loader_version,
            &target,
            &base.version_id,
        )?;

        result.downloaded_files += base.downloaded_files;
        result.message = format!(
            "NeoForge 已安装。已先安装原版 {game_version}，再下载 NeoForge installer、写入版本 JSON、下载 libraries 并执行 processor。"
        );

        Ok(result)
    }
}
