# HMCL 下载模块结构化重构

本次重构以用户提供的 HMCL 源码为行为参照，目标是把原先集中在
`qml/features/download/HmclDownloadPage.qml` 的单文件实现拆成与 HMCL 下载向导相近的层级，并消除 UI 线程同步网络请求。

## 文件映射

| HMCL Java 结构 | Qt/QML + C++ 对应实现 |
|---|---|
| `ui/download/DownloadPage.java` | `qml/features/download/HmclDownloadPage.qml`、`DownloadSidebar.qml`、`DownloadPageStack.qml` |
| `ui/download/VersionsPage.java` | `qml/features/download/VersionsPage.qml`、`DownloadVersionCell.qml` |
| `ui/download/AbstractInstallersPage.java` | `qml/features/download/InstallersPage.qml`、`DownloadInstallerCard.qml` |
| `ui/download/InstallersPage.java` | `DownloadPageController.qml` 中的安装器选择、名称保持与安装提交逻辑 |
| `ui/animation/TransitionPane.java` | `qml/Hmcl/animation/TransitionPane.qml` |
| `ui/animation/ContainerAnimations.java` | `qml/Hmcl/animation/ContainerAnimations.qml` |
| `download/DownloadProvider.java` | `src/download/hmcl/DownloadProvider.*` |
| 游戏/加载器版本列表任务 | `src/download/hmcl/VersionListService.*` + `LauncherBackend` 的 QtConcurrent 任务 |
| 游戏安装任务链 | `src/download/GameInstaller.*`、`Downloader.*`、`LoaderInstaller.*` |

## 当前实现行为

- 下载页侧栏保持 HMCL 的“游戏 / 内容”分类和 200 px 宽度。
- 游戏版本页采用搜索、版本类型过滤、刷新、加载/失败/成功三态切换。
- 支持 `regex:` 前缀搜索，与 HMCL 的版本搜索逻辑对齐。
- 点击游戏版本后进入安装器卡片页；再点击 Forge、NeoForge、Fabric、Quilt 后进入各自版本页。
- 前进和后退采用 HMCL `FORWARD/BACKWARD` 的 20% 横向位移、前后半程淡入淡出和 400 ms 时长。
- 从加载器版本页返回时回到安装器页，不越级跳回游戏版本列表。
- 用户手工修改版本名称后，切换加载器不再自动覆盖名称。
- 版本名称允许 Linux 文件系统可用的中文和空格，并拒绝危险路径/JAR 字符。
- 游戏清单和加载器元数据运行在后台线程；请求序列号防止旧响应覆盖新请求。
- 自动下载源按 Mojang 官方优先、BMCLAPI 回退；BMCLAPI 模式则镜像优先、官方回退。
- 网络请求失败、超时、下载重试和候选源切换会写入详细日志。
- 不再用硬编码假版本掩盖网络失败。

## 尚未实现的范围

以下内容仍不是 HMCL 的完整功能移植，界面中会保持禁用或占位状态：

- OptiFine、Fabric API、Quilt API、LiteLoader、Cleanroom、Legacy Fabric 的完整安装任务；
- 整合包、Mod、资源包、光影包、世界的远程检索和下载后端；
- HMCL 全部加载器兼容性矩阵、原生补丁支持状态提示和完整本地化；
- HMCL Java 任务图的所有重试、校验和恢复策略。

这些项目不能仅靠样式补齐，需要继续移植相应仓库、版本列表和安装任务模型。

## 构建

Arch Linux / fish：

```fish
cd ~/Projects/mc-launcher
rm -rf build-cpp

cmake -S . -B build-cpp -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_PREFIX_PATH=/usr/lib/cmake \
    -DQt6_DIR=/usr/lib/cmake/Qt6

cmake --build build-cpp -j(nproc)
./scripts/run-with-logs.sh
```

Qt Concurrent 已作为必需组件加入 `CMakeLists.txt`。

## 许可提示

HMCL 采用 GNU GPL v3。当前实现明确以 HMCL 源码和行为为移植参照。若分发该派生实现，应核查并履行 GPL v3 的源代码、许可证和版权声明义务。
