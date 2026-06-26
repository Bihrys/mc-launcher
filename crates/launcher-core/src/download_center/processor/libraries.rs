use super::super::model::{DownloadCenterError, DownloadSourceKind};
use super::super::repository::DownloadRepository;
use super::super::resolver::DownloadResolver;
use crate::download::{DownloadFile, DownloadManager};
use reqwest::blocking::Client;
use serde_json::Value;
use std::fs;
use std::path::Path;

pub struct LibraryResolver;

impl LibraryResolver {
    pub fn collect_libraries_from_version_json(
        source: DownloadSourceKind,
        root: &Path,
        version_json: &Value,
    ) -> Result<Vec<DownloadFile>, DownloadCenterError> {
        let libraries = match version_json.get("libraries").and_then(Value::as_array) {
            Some(value) => value,
            None => return Ok(Vec::new()),
        };

        let mut files = Vec::new();

        for lib in libraries {
            if let Some(artifact) = lib.get("downloads").and_then(|value| value.get("artifact")) {
                if let Some(file) = Self::library_artifact_to_file(source, root, artifact) {
                    files.push(file);
                }
            } else if let Some(name) = lib.get("name").and_then(Value::as_str) {
                let base_url = lib
                    .get("url")
                    .and_then(Value::as_str)
                    .unwrap_or("https://libraries.minecraft.net/");

                if let Some(file) = Self::library_from_name_to_file(source, root, base_url, name) {
                    files.push(file);
                }
            }

            let native_key = match std::env::consts::OS {
                "linux" => "linux",
                "macos" => "osx",
                "windows" => "windows",
                _ => "",
            };

            if native_key.is_empty() {
                continue;
            }

            let Some(classifier_name) = lib
                .get("natives")
                .and_then(|value| value.get(native_key))
                .and_then(Value::as_str)
            else {
                continue;
            };

            let classifier_name = classifier_name.replace(
                "${arch}",
                if cfg!(target_pointer_width = "64") {
                    "64"
                } else {
                    "32"
                },
            );

            if let Some(classifier) = lib
                .get("downloads")
                .and_then(|value| value.get("classifiers"))
                .and_then(|value| value.get(&classifier_name))
            {
                if let Some(file) = Self::library_artifact_to_file(source, root, classifier) {
                    files.push(file);
                }
            }
        }

        Ok(files)
    }

    pub fn collect_assets_from_version_json(
        manager: &DownloadManager,
        source: DownloadSourceKind,
        client: &Client,
        root: &Path,
        version_json: &Value,
    ) -> Result<Vec<DownloadFile>, DownloadCenterError> {
        let Some(asset_index) = version_json.get("assetIndex") else {
            return Ok(Vec::new());
        };

        let Some(asset_id) = asset_index.get("id").and_then(Value::as_str) else {
            return Ok(Vec::new());
        };

        let Some(asset_index_url) = asset_index.get("url").and_then(Value::as_str) else {
            return Ok(Vec::new());
        };

        let asset_index_urls = DownloadResolver::inject_url_candidates(source, asset_index_url);
        let asset_json: Value =
            DownloadResolver::get_json_from_candidates(client, &asset_index_urls)?;

        let index_path = root
            .join("assets")
            .join("indexes")
            .join(format!("{asset_id}.json"));

        DownloadRepository::ensure_parent(&index_path)?;
        fs::write(&index_path, serde_json::to_string_pretty(&asset_json)?)?;
        manager.track_created_file(index_path.clone())?;

        let mut files = Vec::new();

        let Some(objects) = asset_json.get("objects").and_then(Value::as_object) else {
            return Ok(files);
        };

        for object in objects.values() {
            let Some(hash) = object.get("hash").and_then(Value::as_str) else {
                continue;
            };

            if hash.len() < 2 {
                continue;
            }

            let prefix = &hash[0..2];
            let target = root.join("assets").join("objects").join(prefix).join(hash);
            let size = object.get("size").and_then(Value::as_u64);

            files.push(DownloadFile::with_candidates(
                DownloadResolver::asset_object_candidates(source, prefix, hash),
                target,
                size,
                Some(hash.to_string()),
            ));
        }

        Ok(files)
    }

    pub fn download_file_from_artifact(
        source: DownloadSourceKind,
        url: &str,
        target: &Path,
        artifact: &Value,
    ) -> DownloadFile {
        DownloadFile::with_candidates(
            DownloadResolver::inject_url_candidates(source, url),
            target.to_path_buf(),
            artifact.get("size").and_then(Value::as_u64),
            artifact
                .get("sha1")
                .and_then(Value::as_str)
                .map(ToString::to_string),
        )
    }

    pub fn library_artifact_to_file(
        source: DownloadSourceKind,
        root: &Path,
        artifact: &Value,
    ) -> Option<DownloadFile> {
        let path = artifact.get("path").and_then(Value::as_str)?;
        let url = artifact.get("url").and_then(Value::as_str)?;

        if url.is_empty() {
            return None;
        }

        Some(Self::download_file_from_artifact(
            source,
            url,
            &root.join("libraries").join(path),
            artifact,
        ))
    }

    pub fn library_from_name_to_file(
        source: DownloadSourceKind,
        root: &Path,
        base_url: &str,
        descriptor: &str,
    ) -> Option<DownloadFile> {
        let path = DownloadResolver::maven_path(descriptor)?;

        let base_url = if base_url.ends_with('/') {
            base_url.to_string()
        } else {
            format!("{base_url}/")
        };

        Some(DownloadFile::with_candidates(
            DownloadResolver::inject_url_candidates(source, &(base_url + &path)),
            root.join("libraries").join(path),
            None,
            None,
        ))
    }
}
