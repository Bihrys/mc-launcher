use super::model::{
    DownloadCatalog, DownloadCenterError, DownloadSourceKind, ForgeRoot, GameEntry,
    InstallerEntry, LoaderEntry, MetaLoaderVersion, MojangManifest, NeoForgeApiResult,
};
use super::resolver::DownloadResolver;
use reqwest::blocking::Client;

pub struct DownloadCatalogService;

impl DownloadCatalogService {
    pub fn fetch_json(source: DownloadSourceKind) -> Result<String, DownloadCenterError> {
        Ok(serde_json::to_string(&Self::fetch(source)?)?)
    }

    pub fn fetch(source: DownloadSourceKind) -> Result<DownloadCatalog, DownloadCenterError> {
        let client = DownloadResolver::http_client()?;
        let mut warnings = Vec::new();

        let manifest: MojangManifest =
            DownloadResolver::get_json(&client, &DownloadResolver::manifest_url(source))?;

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
            Ok(value) => value,
            Err(err) => {
                warnings.push(format!("Forge 列表获取失败：{err}"));
                Vec::new()
            }
        };

        let neoforge_installers = match Self::fetch_neoforge_installers(&client, source) {
            Ok(value) => value,
            Err(err) => {
                warnings.push(format!("NeoForge 列表获取失败：{err}"));
                Vec::new()
            }
        };

        Ok(DownloadCatalog {
            source: source.as_raw().to_string(),
            latest_release: manifest.latest.release,
            latest_snapshot: manifest.latest.snapshot,
            game_versions,
            fabric_loaders,
            quilt_loaders,
            forge_installers,
            neoforge_installers,
            warnings,
        })
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
        let webpath = root
            .webpath
            .unwrap_or_else(|| "https://maven.minecraftforge.net/net/minecraftforge/forge/".to_string());

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
