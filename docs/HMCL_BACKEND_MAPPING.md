# HMCL 后端到 Qt/C++ 重构映射

本文件记录第一阶段映射关系。目标不是把 Java 源码直接粘贴/逐字翻译，而是按 HMCL 的模块边界建立 C++ 等价框架，再逐块替换占位实现。

## 顶层模块映射

| HMCL/HMCLCore 包 | 职责 | C++ 对应目录 | 当前状态 |
|---|---|---|---|
| `org.jackhuang.hmcl.setting` | 启动器设置、全局配置、属性绑定 | `src/settings` | 已建 `LauncherSettings`，支持加载、保存、更新、外观选项、系统内存 |
| `org.jackhuang.hmcl.auth.*` | 离线、Microsoft、Yggdrasil/authlib-injector 登录 | `src/account` | 已建 `AccountService`；离线账户可保存，Microsoft/Yggdrasil 先占位 |
| `org.jackhuang.hmcl.game` | 版本、游戏目录、实例元数据 | `src/game` | 已建 `InstanceService`；扫描 `.minecraft/versions`，支持详情、文件夹、实例设置 |
| `org.jackhuang.hmcl.download.*` | 版本列表、下载源、安装器、文件校验 | `src/download` | 已建 `DownloadService`；可取 Mojang manifest，安装先创建版本骨架 |
| `org.jackhuang.hmcl.java` / `download.java` | Java 检测与下载 | `src/java` | 已建 `JavaService`；支持系统 Java 检测，下载占位 |
| `org.jackhuang.hmcl.launch` | 启动命令、进程、日志、可见性策略 | `src/launch` | 已建 `LaunchService`；生成状态与命令，占位未真正启动进程 |
| `org.jackhuang.hmcl.task` | Task 图、进度、取消、监听器 | 后续 `src/task` | 当前用 JSON 状态兼容前端；后续改 C++ `TaskModel` + signals |
| `org.jackhuang.hmcl.util.platform` | 平台路径、打开文件夹、系统检测 | `src/core/LauncherPaths` | 已建 Linux/XDG 路径层 |

## Qt 前端桥接

| 当前 QML 需要 | C++ 对应 |
|---|---|
| `LauncherBackend` | `src/bridge/LauncherBackend.*` |
| `GameListModel` | `src/models/GameListModel.*` |
| `ProfileListModel` | `src/models/ProfileListModel.*` |
| `qrc:/qt/qml/com/bihrys/launcher/qml/...` | CMake 自动生成 `launcher_qml.qrc` |

## 后续逐块翻译顺序

1. `task`：先补 HMCL Task 生命周期，否则下载/登录/启动都会变成假异步。
2. `download/game`：把 Mojang manifest、版本 JSON、assets、libraries 下载与校验完整接入。
3. `download/fabric|quilt|forge|neoforge|optifine`：逐个翻译 loader metadata resolver 与安装 plan。
4. `auth/microsoft`、`auth/yggdrasil`：替换当前占位账户逻辑。
5. `launch`：补全 classpath、assets index、natives、JVM 参数、日志窗口与进程管理。
6. `modpack`、`addon`：最后迁移整合包、Modrinth/CurseForge 等内容生态。
