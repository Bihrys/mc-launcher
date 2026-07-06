# HMCL download 目录移植映射


来源：`HMCLCore/src/main/java/org/jackhuang/hmcl/download`。

说明：本补丁按 HMCL download 的目录层级在 `src/download/hmcl/` 下保留对应目录；已编译接入的核心代码集中在 `DownloadProvider`、`VersionListService`、`LoaderInstaller`，并与现有 `GameInstaller` / `DownloadService` / QML 调用链对接。

| HMCL Java 文件 | C++ 对应位置 | 当前状态 |
|---|---|---|
| `AbstractDependencyManager.java` | `src/download/hmcl/AbstractDependencyManager.h` | 结构已映射 |
| `ArtifactMalformedException.java` | `src/download/hmcl/ArtifactMalformedException.h` | 结构已映射 |
| `AutoDownloadProvider.java` | `src/download/hmcl/DownloadProvider.h/.cpp` | 已接入 C++ URL 注入和候选源 |
| `BMCLAPIDownloadProvider.java` | `src/download/hmcl/DownloadProvider.h/.cpp` | 已接入 C++ URL 注入和候选源 |
| `DefaultCacheRepository.java` | `src/download/hmcl/DefaultCacheRepository.h` | 结构已映射 |
| `DefaultDependencyManager.java` | `src/download/hmcl/DefaultDependencyManager.h` | 结构已映射 |
| `DefaultGameBuilder.java` | `src/download/hmcl/DefaultGameBuilder.h` | 结构已映射 |
| `DependencyManager.java` | `src/download/hmcl/DependencyManager.h` | 结构已映射 |
| `DownloadProvider.java` | `src/download/hmcl/DownloadProvider.h/.cpp` | 已接入 C++ URL 注入和候选源 |
| `DownloadProviderWrapper.java` | `src/download/hmcl/DownloadProviderWrapper.h` | 结构已映射 |
| `GameBuilder.java` | `src/download/hmcl/GameBuilder.h` | 结构已映射 |
| `LibraryAnalyzer.java` | `src/download/hmcl/LibraryAnalyzer.h` | 结构已映射 |
| `MaintainTask.java` | `src/download/hmcl/MaintainTask.h` | 结构已映射 |
| `MojangDownloadProvider.java` | `src/download/hmcl/DownloadProvider.h/.cpp` | 已接入 C++ URL 注入和候选源 |
| `MultipleSourceVersionList.java` | `src/download/hmcl/MultipleSourceVersionList.h` | 结构已映射 |
| `RemoteVersion.java` | `src/download/hmcl/RemoteVersion.h` | 结构已映射 |
| `UnsupportedInstallationException.java` | `src/download/hmcl/UnsupportedInstallationException.h` | 结构已映射 |
| `VersionList.java` | `src/download/hmcl/VersionList.h` | 结构已映射 |
| `VersionMismatchException.java` | `src/download/hmcl/VersionMismatchException.h` | 结构已映射 |
| `cleanroom/CleanroomInstallTask.java` | `src/download/hmcl/cleanroom/CleanroomInstallTask.h` | 结构已映射 |
| `cleanroom/CleanroomRemoteVersion.java` | `src/download/hmcl/cleanroom/CleanroomRemoteVersion.h` | 结构已映射 |
| `cleanroom/CleanroomVersionList.java` | `src/download/hmcl/cleanroom/CleanroomVersionList.h` | 结构已映射 |
| `fabric/FabricAPIInstallTask.java` | `src/download/hmcl/fabric/FabricAPIInstallTask.h` | 结构已映射 |
| `fabric/FabricAPIRemoteVersion.java` | `src/download/hmcl/fabric/FabricAPIRemoteVersion.h` | 结构已映射 |
| `fabric/FabricAPIVersionList.java` | `src/download/hmcl/fabric/FabricAPIVersionList.h` | 结构已映射 |
| `fabric/FabricInstallTask.java` | `src/download/hmcl/LoaderInstaller.cpp + VersionListService.cpp` | Fabric 元数据和安装已接入 |
| `fabric/FabricRemoteVersion.java` | `src/download/hmcl/LoaderInstaller.cpp + VersionListService.cpp` | Fabric 元数据和安装已接入 |
| `fabric/FabricVersionList.java` | `src/download/hmcl/LoaderInstaller.cpp + VersionListService.cpp` | Fabric 元数据和安装已接入 |
| `forge/ForgeBMCLVersionList.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeInstall.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeInstallProfile.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeInstallTask.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeNewInstallProfile.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeNewInstallTask.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeOldInstallTask.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeRemoteVersion.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeVersion.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeVersionList.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `forge/ForgeVersionRoot.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | Forge 版本列表已接入，installer/processor 流程保留失败边界 |
| `game/GameAssetDownloadTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `game/GameAssetIndexDownloadTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `game/GameDownloadTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `game/GameInstallTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `game/GameLibrariesTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `game/GameRemoteLatestVersions.java` | `src/download/hmcl/game/GameRemoteLatestVersions.h` | 结构已映射 |
| `game/GameRemoteVersion.java` | `src/download/hmcl/game/GameRemoteVersion.h` | 结构已映射 |
| `game/GameRemoteVersionInfo.java` | `src/download/hmcl/game/GameRemoteVersionInfo.h` | 结构已映射 |
| `game/GameRemoteVersions.java` | `src/download/hmcl/game/GameRemoteVersions.h` | 结构已映射 |
| `game/GameVerificationFixTask.java` | `src/download/hmcl/game/GameVerificationFixTask.h` | 结构已映射 |
| `game/GameVersionList.java` | `src/download/hmcl/game/GameVersionList.h` | 结构已映射 |
| `game/LibraryDownloadException.java` | `src/download/hmcl/game/LibraryDownloadException.h` | 结构已映射 |
| `game/LibraryDownloadTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `game/VersionJsonDownloadTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `game/VersionJsonSaveTask.java` | `src/download/GameInstaller.cpp + src/download/Downloader.cpp` | 原版安装链路已接入，URL 候选源已接入 |
| `java/JavaDistribution.java` | `src/download/hmcl/java/JavaDistribution.h` | 结构已映射 |
| `java/JavaPackageType.java` | `src/download/hmcl/java/JavaPackageType.h` | 结构已映射 |
| `java/JavaRemoteVersion.java` | `src/download/hmcl/java/JavaRemoteVersion.h` | 结构已映射 |
| `java/disco/DiscoFetchJavaListTask.java` | `src/download/hmcl/java/disco/DiscoFetchJavaListTask.h` | 结构已映射 |
| `java/disco/DiscoJavaDistribution.java` | `src/download/hmcl/java/disco/DiscoJavaDistribution.h` | 结构已映射 |
| `java/disco/DiscoJavaRemoteVersion.java` | `src/download/hmcl/java/disco/DiscoJavaRemoteVersion.h` | 结构已映射 |
| `java/disco/DiscoRemoteFileInfo.java` | `src/download/hmcl/java/disco/DiscoRemoteFileInfo.h` | 结构已映射 |
| `java/disco/DiscoResult.java` | `src/download/hmcl/java/disco/DiscoResult.h` | 结构已映射 |
| `java/mojang/MojangJavaDistribution.java` | `src/download/hmcl/java/mojang/MojangJavaDistribution.h` | 结构已映射 |
| `java/mojang/MojangJavaDownloadTask.java` | `src/download/hmcl/java/mojang/MojangJavaDownloadTask.h` | 结构已映射 |
| `java/mojang/MojangJavaDownloads.java` | `src/download/hmcl/java/mojang/MojangJavaDownloads.h` | 结构已映射 |
| `java/mojang/MojangJavaRemoteFiles.java` | `src/download/hmcl/java/mojang/MojangJavaRemoteFiles.h` | 结构已映射 |
| `java/mojang/MojangJavaRemoteVersion.java` | `src/download/hmcl/java/mojang/MojangJavaRemoteVersion.h` | 结构已映射 |
| `legacyfabric/LegacyFabricAPIInstallTask.java` | `src/download/hmcl/legacyfabric/LegacyFabricAPIInstallTask.h` | 结构已映射 |
| `legacyfabric/LegacyFabricAPIRemoteVersion.java` | `src/download/hmcl/legacyfabric/LegacyFabricAPIRemoteVersion.h` | 结构已映射 |
| `legacyfabric/LegacyFabricAPIVersionList.java` | `src/download/hmcl/legacyfabric/LegacyFabricAPIVersionList.h` | 结构已映射 |
| `legacyfabric/LegacyFabricInstallTask.java` | `src/download/hmcl/legacyfabric/LegacyFabricInstallTask.h` | 结构已映射 |
| `legacyfabric/LegacyFabricRemoteVersion.java` | `src/download/hmcl/legacyfabric/LegacyFabricRemoteVersion.h` | 结构已映射 |
| `legacyfabric/LegacyFabricVersionList.java` | `src/download/hmcl/legacyfabric/LegacyFabricVersionList.h` | 结构已映射 |
| `liteloader/LiteLoaderBMCLVersionList.java` | `src/download/hmcl/liteloader/LiteLoaderBMCLVersionList.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderBranch.java` | `src/download/hmcl/liteloader/LiteLoaderBranch.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderGameVersions.java` | `src/download/hmcl/liteloader/LiteLoaderGameVersions.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderInstallTask.java` | `src/download/hmcl/liteloader/LiteLoaderInstallTask.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderRemoteVersion.java` | `src/download/hmcl/liteloader/LiteLoaderRemoteVersion.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderRepository.java` | `src/download/hmcl/liteloader/LiteLoaderRepository.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderVersion.java` | `src/download/hmcl/liteloader/LiteLoaderVersion.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderVersionList.java` | `src/download/hmcl/liteloader/LiteLoaderVersionList.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderVersionsMeta.java` | `src/download/hmcl/liteloader/LiteLoaderVersionsMeta.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `liteloader/LiteLoaderVersionsRoot.java` | `src/download/hmcl/liteloader/LiteLoaderVersionsRoot.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `neoforge/NeoForgeBMCLVersionList.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | NeoForge 版本列表已接入，installer/processor 流程保留失败边界 |
| `neoforge/NeoForgeInstallTask.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | NeoForge 版本列表已接入，installer/processor 流程保留失败边界 |
| `neoforge/NeoForgeOfficialVersionList.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | NeoForge 版本列表已接入，installer/processor 流程保留失败边界 |
| `neoforge/NeoForgeOldInstallTask.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | NeoForge 版本列表已接入，installer/processor 流程保留失败边界 |
| `neoforge/NeoForgeRemoteVersion.java` | `src/download/hmcl/VersionListService.cpp + LoaderInstaller.cpp` | NeoForge 版本列表已接入，installer/processor 流程保留失败边界 |
| `optifine/OptiFineBMCLVersionList.java` | `src/download/hmcl/optifine/OptiFineBMCLVersionList.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `optifine/OptiFineInstallTask.java` | `src/download/hmcl/optifine/OptiFineInstallTask.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `optifine/OptiFineRemoteVersion.java` | `src/download/hmcl/optifine/OptiFineRemoteVersion.h` | 当前 QML 未开放/后续扩展，结构目录已保留 |
| `quilt/QuiltAPIInstallTask.java` | `src/download/hmcl/quilt/QuiltAPIInstallTask.h` | 结构已映射 |
| `quilt/QuiltAPIRemoteVersion.java` | `src/download/hmcl/quilt/QuiltAPIRemoteVersion.h` | 结构已映射 |
| `quilt/QuiltAPIVersionList.java` | `src/download/hmcl/quilt/QuiltAPIVersionList.h` | 结构已映射 |
| `quilt/QuiltInstallTask.java` | `src/download/hmcl/LoaderInstaller.cpp + VersionListService.cpp` | Quilt 元数据和安装已接入 |
| `quilt/QuiltRemoteVersion.java` | `src/download/hmcl/LoaderInstaller.cpp + VersionListService.cpp` | Quilt 元数据和安装已接入 |
| `quilt/QuiltVersionList.java` | `src/download/hmcl/LoaderInstaller.cpp + VersionListService.cpp` | Quilt 元数据和安装已接入 |