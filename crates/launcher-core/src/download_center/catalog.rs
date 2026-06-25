use super::model::{
    DownloadCatalog, DownloadCenterError, DownloadSourceKind, ForgeRoot, GameEntry, InstallerEntry,
    LoaderEntry, MetaLoaderVersion, MojangManifest, NeoForgeApiResult,
};
use super::repository::DownloadRepository;
use super::resolver::DownloadResolver;
use reqwest::blocking::Client;
use std::fs;
use std::path::Path;
use std::time::{Duration, SystemTime};

pub struct DownloadCatalogService;

impl DownloadCatalogService {
    pub fn fetch_json(source: DownloadSourceKind) -> Result<String, DownloadCenterError> {
        Ok(serde_json::to_string(&Self::fetch(source)?)?)
    }

    pub fn fetch_installer_metadata_json(
        source: DownloadSourceKind,
        game_version: &str,
    ) -> Result<String, DownloadCenterError> {
        let client = DownloadResolver::http_client()?;
        let mut warnings = Vec::new();

        let fabric_loaders = match Self::fetch_meta_loaders(
            &client,
            source,
            "https://meta.fabricmc.net/v2/versions/loader",
        ) {
            Ok(value) => value,
            Err(err) => {
                warnings.push(format!("Fabric loader 列表获取失败：{err}"));
                Vec::new()
            }
        };

        let quilt_loaders = match Self::fetch_meta_loaders(
            &client,
            source,
            "https://meta.quiltmc.org/v3/versions/loader",
        ) {
            Ok(value) => value,
            Err(err) => {
                warnings.push(format!("Quilt loader 列表获取失败：{err}"));
                Vec::new()
            }
        };

        let forge_installers = match Self::fetch_forge_installers(&client, source) {
            Ok(value) => value
                .into_iter()
                .filter(|item| item.game_version == game_version)
                .collect::<Vec<_>>(),
            Err(err) => {
                warnings.push(format!("Forge installer 列表获取失败：{err}"));
                Vec::new()
            }
        };

        let neoforge_installers = match Self::fetch_neoforge_installers(&client, source) {
            Ok(value) => value
                .into_iter()
                .filter(|item| item.game_version == game_version)
                .collect::<Vec<_>>(),
            Err(err) => {
                warnings.push(format!("NeoForge installer 列表获取失败：{err}"));
                Vec::new()
            }
        };

        Ok(serde_json::json!({
            "gameVersion": game_version,
            "fabricLoaders": fabric_loaders,
            "quiltLoaders": quilt_loaders,
            "forgeInstallers": forge_installers,
            "neoforgeInstallers": neoforge_installers,
            "warnings": warnings
        })
        .to_string())
    }

    pub fn fetch(source: DownloadSourceKind) -> Result<DownloadCatalog, DownloadCenterError> {
        // HMCL 的 VersionsPage 只刷新 Minecraft manifest。
        // Fabric / Quilt / Forge / NeoForge 属于点版本后的安装器向导，不允许阻塞版本列表。
        let (manifest, used_source, mut warnings) = Self::fetch_manifest_hmcl_style(source)?;

        let game_versions = manifest
            .versions
            .iter()
            .map(|version| GameEntry {
                id: version.id.clone(),
                version_type: version.version_type.clone(),
                release_time: version.release_time.clone(),
                url: DownloadResolver::inject_url(source, &version.url),
            })
            .collect::<Vec<_>>();

        if used_source != source.as_raw() {
            warnings.push(format!(
                "版本列表使用 {used_source} 源返回。原请求源：{}。",
                source.as_raw()
            ));
        }

        Ok(DownloadCatalog {
            source: used_source,
            latest_release: manifest.latest.release,
            latest_snapshot: manifest.latest.snapshot,
            game_versions,
            fabric_loaders: Vec::new(),
            quilt_loaders: Vec::new(),
            forge_installers: Vec::new(),
            neoforge_installers: Vec::new(),
            warnings,
        })
    }

    fn fetch_manifest_hmcl_style(
        source: DownloadSourceKind,
    ) -> Result<(MojangManifest, String, Vec<String>), DownloadCenterError> {
        let candidates = Self::manifest_candidates(source);
        let cache_root = DownloadRepository::cache_root()?
            .join("download_center")
            .join("version_manifest");

        fs::create_dir_all(&cache_root)?;

        let mut warnings = Vec::new();

        // 对齐 HMCL FetchTask：优先使用新鲜缓存，避免每次进下载页都等网络。
        for (label, _) in &candidates {
            let cache_path = cache_root.join(format!("{label}.json"));

            if let Some(text) =
                Self::read_cached_manifest(&cache_path, Some(Duration::from_secs(6 * 60 * 60)))
            {
                match serde_json::from_str::<MojangManifest>(&text) {
                    Ok(manifest) => return Ok((manifest, label.clone(), warnings)),
                    Err(err) => warnings.push(format!("忽略损坏的版本列表缓存 {label}: {err}")),
                }
            }
        }

        // 版本 manifest 必须短超时。不能像大文件下载一样等几十秒。
        let client = Client::builder()
            .user_agent("mc-launcher/0.1 hmcl-multiple-source-version-list")
            .connect_timeout(Duration::from_secs(3))
            .timeout(Duration::from_secs(8))
            .build()?;

        for (label, url) in &candidates {
            match client
                .get(url)
                .send()
                .and_then(|response| response.error_for_status())
                .and_then(|response| response.text())
            {
                Ok(text) => match serde_json::from_str::<MojangManifest>(&text) {
                    Ok(manifest) => {
                        let cache_path = cache_root.join(format!("{label}.json"));
                        let _ = fs::write(cache_path, text);
                        return Ok((manifest, label.clone(), warnings));
                    }
                    Err(err) => warnings.push(format!("版本列表解析失败 {label}: {err}")),
                },
                Err(err) => warnings.push(format!("版本列表请求失败 {label}: {err}")),
            }
        }

        // 所有网络源失败时，退回旧缓存。HMCL 日志里的 Using cached file 就是这个思路。
        for (label, _) in &candidates {
            let cache_path = cache_root.join(format!("{label}.json"));

            if let Some(text) = Self::read_cached_manifest(&cache_path, None) {
                match serde_json::from_str::<MojangManifest>(&text) {
                    Ok(manifest) => {
                        warnings.push(format!("网络不可用，已使用过期缓存：{label}"));
                        return Ok((manifest, label.clone(), warnings));
                    }
                    Err(err) => warnings.push(format!("过期缓存不可用 {label}: {err}")),
                }
            }
        }

        Err(simple_error(format!(
            "版本列表获取失败。已尝试源：{}。{}",
            candidates
                .iter()
                .map(|(label, _)| label.as_str())
                .collect::<Vec<_>>()
                .join(", "),
            warnings.join("；")
        )))
    }

    fn manifest_candidates(source: DownloadSourceKind) -> Vec<(String, String)> {
        let official = (
            "official".to_string(),
            "https://piston-meta.mojang.com/mc/game/version_manifest.json".to_string(),
        );

        let bmcl = (
            "bmcl".to_string(),
            "https://bmclapi2.bangbang93.com/mc/game/version_manifest.json".to_string(),
        );

        match source {
            // 选官方时仍保留 BMCLAPI fallback，避免官方源不可达时无限转圈。
            DownloadSourceKind::Official => vec![official, bmcl],
            DownloadSourceKind::Bmcl | DownloadSourceKind::Mirror => vec![bmcl, official],
            DownloadSourceKind::Balanced => vec![bmcl, official],
        }
    }

    fn read_cached_manifest(path: &Path, max_age: Option<Duration>) -> Option<String> {
        if let Some(max_age) = max_age {
            let modified = fs::metadata(path).ok()?.modified().ok()?;
            let age = SystemTime::now().duration_since(modified).ok()?;

            if age > max_age {
                return None;
            }
        }

        fs::read_to_string(path).ok()
    }

    fn fetch_meta_loaders(
        client: &Client,
        source: DownloadSourceKind,
        url: &str,
    ) -> Result<Vec<LoaderEntry>, DownloadCenterError> {
        let url = DownloadResolver::inject_url(source, url);
        let values: Vec<MetaLoaderVersion> = DownloadResolver::get_json(client, &url)?;

        Ok(values
            .into_iter()
            .map(|item| LoaderEntry {
                version: item.version,
                stable: item.stable.unwrap_or(false),
            })
            .collect())
    }

    fn fetch_forge_installers(
        client: &Client,
        source: DownloadSourceKind,
    ) -> Result<Vec<InstallerEntry>, DownloadCenterError> {
        let url = DownloadResolver::inject_url(source, "https://hmcl.glavo.site/metadata/forge/");
        let root: ForgeRoot = DownloadResolver::get_json(client, &url)?;

        let artifact = root.artifact.unwrap_or_else(|| "forge".to_string());
        let webpath = root.webpath.unwrap_or_else(|| {
            "https://maven.minecraftforge.net/net/minecraftforge/forge/".to_string()
        });

        let mcversion = root.mcversion.unwrap_or_default();
        let number = root.number.unwrap_or_default();
        let mut out = Vec::new();

        for (game_version, builds) in mcversion {
            let game_version = if game_version == "1.7.10_pre4" {
                "1.7.10-pre4".to_string()
            } else {
                game_version
            };

            for build in builds {
                let Some(version) = number.get(&build.to_string()) else {
                    continue;
                };

                let Some(loader_version) = version.version.as_ref() else {
                    continue;
                };

                let Some(files) = version.files.as_ref() else {
                    continue;
                };

                let mut installer_url = None;

                for file in files {
                    if file.len() < 2 || file[1] != "installer" {
                        continue;
                    }

                    let ext = &file[0];
                    let branch = version.branch.as_deref().unwrap_or_default();
                    let mc = version.mcversion.as_deref().unwrap_or(&game_version);

                    let classifier = if branch.is_empty() {
                        format!("{mc}-{loader_version}")
                    } else {
                        format!("{mc}-{loader_version}-{branch}")
                    };

                    let file_name = format!("{artifact}-{classifier}-installer.{ext}");
                    installer_url = Some(format!("{webpath}{classifier}/{file_name}"));
                    break;
                }

                if let Some(url) = installer_url {
                    out.push(InstallerEntry {
                        game_version: game_version.clone(),
                        loader_version: loader_version.clone(),
                        url: DownloadResolver::inject_url(source, &url),
                        release_time: version.modified.map(|value| value.to_string()),
                    });
                }
            }
        }

        out.sort_by(|a, b| {
            b.game_version
                .cmp(&a.game_version)
                .then_with(|| b.loader_version.cmp(&a.loader_version))
        });

        Ok(out)
    }

    fn fetch_neoforge_installers(
        client: &Client,
        source: DownloadSourceKind,
    ) -> Result<Vec<InstallerEntry>, DownloadCenterError> {
        let old_url = DownloadResolver::inject_url(
            source,
            "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/forge",
        );
        let new_url = DownloadResolver::inject_url(
            source,
            "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge",
        );

        let mut out = Vec::new();

        if let Ok(old_result) = DownloadResolver::get_json::<NeoForgeApiResult>(client, &old_url) {
            for version in old_result.versions {
                out.push(InstallerEntry {
                    game_version: "1.20.1".to_string(),
                    loader_version: DownloadResolver::normalize_neoforge_version(&version),
                    url: DownloadResolver::inject_url(source, &format!(
                        "https://maven.neoforged.net/releases/net/neoforged/forge/{version}/forge-{version}-installer.jar"
                    )),
                    release_time: None,
                });
            }
        }

        let new_result: NeoForgeApiResult = DownloadResolver::get_json(client, &new_url)?;

        for version in new_result.versions {
            let Some(game_version) = DownloadResolver::neoforge_game_version(&version) else {
                continue;
            };

            out.push(InstallerEntry {
                game_version,
                loader_version: DownloadResolver::normalize_neoforge_version(&version),
                url: DownloadResolver::inject_url(source, &format!(
                    "https://maven.neoforged.net/releases/net/neoforged/neoforge/{version}/neoforge-{version}-installer.jar"
                )),
                release_time: None,
            });
        }

        out.sort_by(|a, b| {
            b.game_version
                .cmp(&a.game_version)
                .then_with(|| b.loader_version.cmp(&a.loader_version))
        });

        Ok(out)
    }
}

fn simple_error(message: impl Into<String>) -> DownloadCenterError {
    Box::new(std::io::Error::other(message.into()))
}
