# HMCL download C++ port notes

本补丁浏览并按目录映射了 `HMCLCore/src/main/java/org/jackhuang/hmcl/download`。

## 已接入到运行链路

- `DownloadProvider` / `MojangDownloadProvider` / `BMCLAPIDownloadProvider`
  - C++ 对应：`src/download/hmcl/DownloadProvider.*`
  - 支持 Mojang 官方源和 BMCLAPI URL 替换候选源。
- `GameInstallTask` 相关原版安装链路
  - C++ 对应：`src/download/GameInstaller.cpp`、`src/download/Downloader.cpp`
  - 已把 version manifest、version JSON、client jar、libraries、assets 的 URL 候选源接入。
- `FabricVersionList` / `QuiltVersionList`
  - C++ 对应：`src/download/hmcl/VersionListService.*`
  - 下载页不再使用硬编码版本，改为请求 Fabric / Quilt metadata API。
- `ForgeBMCLVersionList` / `NeoForgeOfficialVersionList`
  - C++ 对应：`src/download/hmcl/VersionListService.*`
  - 下载页可显示 Forge / NeoForge 的远端版本列表。
- `FabricInstallTask` / `QuiltInstallTask`
  - C++ 对应：`src/download/hmcl/LoaderInstaller.*`
  - 安装逻辑：先安装原版，再拉取 loader metadata，生成继承原版的子版本 JSON，下载 loader libraries，复制原版 client jar 到子版本目录。

## 明确未宣称完成的部分

Forge / NeoForge / OptiFine / LiteLoader 的“可启动安装”没有在本补丁中冒充完成。

原因：HMCL 的 Forge / NeoForge 新版安装并不是 HMCL 自己实现 processor，而是读取 installer JAR 的 `install_profile.json`，再执行 Forge/NeoForge 提供的 processor JAR。用户要求“纯 C++ 重写 processor 逻辑”，这不是简单翻译 HMCL Java 文件，而是要重新实现 Forge 工具链中的 binary patch、jar split/merge、mapping/remap 等逻辑。本补丁保留了目录、版本列表与调度失败边界，避免生成损坏实例。

下一步应新增：

- `src/download/hmcl/forge/ForgeInstallTask.cpp`
- `src/download/hmcl/forge/ForgeOldInstallTask.cpp`
- `src/download/hmcl/forge/ForgeNewInstallTask.cpp`
- `src/download/hmcl/neoforge/NeoForgeInstallTask.cpp`
- `src/download/hmcl/processor/BinaryPatcher.cpp`
- `src/download/hmcl/processor/JarProcessor.cpp`
- `src/download/hmcl/processor/SpecialSourceRemapper.cpp`

并引入 ZIP、LZMA、classfile/remapper 相关实现或库。

## 2026-07-06 patch: HMCL-style task details and Forge installer bridge

- 下载弹窗不再只有一条进度条：现在显示当前文件、文件数量、已下载大小、总大小、实时速度和百分比。
- 弹窗使用已移植的 HMCL `SpinnerPane` 和 `HmclRipple`，加入遮罩淡入、卡片缩放和进度条缓动。
- `Downloader` 增加 `QNetworkReply::downloadProgress` 对接，下载速度不再等到单个文件完成后才跳变。
- 减少 `QNetworkReply` 在关闭状态下 `readAll()/abort()` 产生的 `QIODevice::read/write device not open` 警告。
- Forge / NeoForge 不再直接返回“未完成”：下载 installer JAR 后调用安装器 CLI 执行 client 安装，行为对齐 HMCL 使用 Forge/NeoForge installer/processor 的方向。此实现优先保证可用性；后续若要完全不调用 Java，需要继续重写 Forge binarypatcher、jarsplitter、mapping remapper 等 processor 本体。
