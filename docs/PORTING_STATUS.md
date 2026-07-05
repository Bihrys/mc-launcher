# C++ 重构状态

## 已完成

- 建立 `Qt Quick/QML + C++ + CMake` 项目。
- 保留当前已经接近 HMCL 的 QML 前端和资源路径。
- 注册 `LauncherBackend`、`GameListModel`、`ProfileListModel` 到 `com.bihrys.launcher`。
- 按 HMCL 后端边界拆出 `settings/account/game/download/java/launch/core`。
- 用 C++ 属性和 `Q_INVOKABLE` 衔接现有 QML，避免 Rust/cxx-qt bridge。
- 支持基础设置持久化、外观背景切换、账户列表、离线账户、版本目录扫描、下载页版本列表、实例详情页基础数据。

## 明确未完成

- 未逐行翻译 HMCL 805 个 Java 文件；本阶段是可运行框架与前端桥接层。
- Microsoft/Yggdrasil 真实登录未接入；当前是占位账户。
- Minecraft 完整下载安装链路未接入；当前安装只创建版本骨架。
- 启动游戏未真正执行完整 HMCL Launch pipeline。
- Task 图、依赖调度、校验、重试、镜像源策略尚未迁移。

## 原因

HMCL 是 GPLv3 项目，若逐行翻译 Java 实现为 C++，该 C++ 项目很可能构成派生作品，分发时需要遵守 GPLv3。这里先建立等价模块框架，后续可以在明确许可策略后逐模块翻译。
