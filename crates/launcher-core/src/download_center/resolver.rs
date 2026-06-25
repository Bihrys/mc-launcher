use super::model::{DownloadCenterError, DownloadSourceKind};
use reqwest::blocking::Client;
use serde::de::DeserializeOwned;
use std::time::Duration;

pub struct DownloadResolver;

impl DownloadResolver {
    pub fn manifest_url(source: DownloadSourceKind) -> String {
        match source {
            DownloadSourceKind::Official => {
                "https://piston-meta.mojang.com/mc/game/version_manifest.json".to_string()
            }
            DownloadSourceKind::Bmcl | DownloadSourceKind::Balanced | DownloadSourceKind::Mirror => {
                "https://bmclapi2.bangbang93.com/mc/game/version_manifest.json".to_string()
            }
        }
    }

    pub fn inject_url(source: DownloadSourceKind, url: &str) -> String {
        match source {
            DownloadSourceKind::Official => url.to_string(),
            DownloadSourceKind::Bmcl | DownloadSourceKind::Balanced | DownloadSourceKind::Mirror => {
                Self::inject_bmcl_url(url)
            }
        }
    }

    pub fn inject_url_candidates(source: DownloadSourceKind, url: &str) -> Vec<String> {
        match source {
            DownloadSourceKind::Official => vec![url.to_string()],
            DownloadSourceKind::Bmcl | DownloadSourceKind::Mirror => {
                Self::unique_urls(vec![Self::inject_bmcl_url(url)])
            }
            DownloadSourceKind::Balanced => Self::unique_urls(vec![
                Self::inject_bmcl_url(url),
                url.to_string(),
            ]),
        }
    }

    pub fn asset_object_candidates(source: DownloadSourceKind, prefix: &str, hash: &str) -> Vec<String> {
        let official = format!("https://resources.download.minecraft.net/{prefix}/{hash}");
        let bmcl = format!("https://bmclapi2.bangbang93.com/assets/{prefix}/{hash}");

        match source {
            DownloadSourceKind::Official => vec![official],
            DownloadSourceKind::Bmcl | DownloadSourceKind::Mirror => vec![bmcl],
            DownloadSourceKind::Balanced => Self::unique_urls(vec![bmcl, official]),
        }
    }

    pub fn inject_bmcl_url(url: &str) -> String {
        let replacements = [
            ("https://launchermeta.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://piston-meta.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://piston-data.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://launcher.mojang.com", "https://bmclapi2.bangbang93.com"),
            ("https://libraries.minecraft.net", "https://bmclapi2.bangbang93.com/libraries"),
            ("https://maven.minecraftforge.net", "https://bmclapi2.bangbang93.com/maven"),
            ("https://files.minecraftforge.net/maven", "https://bmclapi2.bangbang93.com/maven"),
            ("http://files.minecraftforge.net/maven", "https://bmclapi2.bangbang93.com/maven"),
            ("https://maven.neoforged.net/releases", "https://bmclapi2.bangbang93.com/maven"),
            ("https://meta.fabricmc.net", "https://bmclapi2.bangbang93.com/fabric-meta"),
            ("https://maven.fabricmc.net", "https://bmclapi2.bangbang93.com/maven"),
            ("https://hmcl.glavo.site/metadata/forge", "https://bmclapi2.bangbang93.com/maven/net/minecraftforge/forge/json"),
            ("https://api.modrinth.com", "https://mod.mcimirror.top/modrinth"),
            ("https://cdn.modrinth.com", "https://mod.mcimirror.top"),
            ("https://edge.forgecdn.net", "https://mod.mcimirror.top/curseforge"),
            ("https://mediafilez.forgecdn.net", "https://mod.mcimirror.top/curseforge"),
        ];

        for (from, to) in replacements {
            if let Some(rest) = url.strip_prefix(from) {
                return format!("{to}{rest}");
            }
        }

        url.to_string()
    }

    pub fn unique_urls(urls: Vec<String>) -> Vec<String> {
        let mut out = Vec::new();

        for url in urls {
            if !url.is_empty() && !out.iter().any(|existing| existing == &url) {
                out.push(url);
            }
        }

        out
    }

    pub fn maven_path(descriptor: &str) -> Option<String> {
        let mut parts = descriptor.split(':').collect::<Vec<_>>();

        if parts.len() < 3 {
            return None;
        }

        let mut ext = "jar".to_string();

        if let Some(last) = parts.last_mut() {
            if let Some((before, after)) = last.split_once('@') {
                *last = before;
                ext = after.to_string();
            }
        }

        let group = parts[0].replace('.', "/");
        let artifact = parts[1];
        let version = parts[2];

        let file_name = if parts.len() >= 4 {
            let classifier = parts[3];
            format!("{artifact}-{version}-{classifier}.{ext}")
        } else {
            format!("{artifact}-{version}.{ext}")
        };

        Some(format!("{group}/{artifact}/{version}/{file_name}"))
    }

    pub fn normalize_neoforge_version(version: &str) -> String {
        version.strip_prefix("1.20.1-").unwrap_or(version).to_string()
    }

    pub fn neoforge_game_version(version: &str) -> Option<String> {
        let si1 = version.find('.')?;
        let si2 = version[si1 + 1..].find('.').map(|v| v + si1 + 1)?;
        let major = version[..si1].parse::<i32>().ok()?;

        if major == 0 {
            return Some(version[si1 + 1..si2].to_string());
        }

        if major >= 26 {
            let si3 = version[si2 + 1..].find('.').map(|v| v + si2 + 1)?;
            let patch = version[si2 + 1..si3].parse::<i32>().ok()?;

            let ver = if patch == 0 {
                version[..si2].to_string()
            } else {
                version[..si3].to_string()
            };

            if let Some(separator) = version.find('+') {
                Some(format!("{ver}-{}", &version[separator + 1..]))
            } else {
                Some(ver)
            }
        } else {
            let minor = version[si1 + 1..si2].parse::<i32>().ok()?;

            if minor == 0 {
                Some(format!("1.{}", &version[..si1]))
            } else {
                Some(format!("1.{}", &version[..si2]))
            }
        }
    }

    pub fn file_name_from_url(url: &str) -> String {
        url.rsplit('/')
            .next()
            .filter(|value| !value.is_empty())
            .unwrap_or("download.bin")
            .to_string()
    }

    pub fn http_client() -> Result<Client, DownloadCenterError> {
        Ok(Client::builder()
            .user_agent("mc-launcher/0.1 hmcl-download-center")
            .connect_timeout(Duration::from_secs(10))
            .timeout(Duration::from_secs(45))
            .build()?)
    }

    pub fn get_json<T: DeserializeOwned>(client: &Client, url: &str) -> Result<T, DownloadCenterError> {
        Ok(client.get(url).send()?.error_for_status()?.json()?)
    }
}

pub(crate) fn simple_error(message: impl Into<String>) -> DownloadCenterError {
    Box::new(std::io::Error::other(message.into()))
}
