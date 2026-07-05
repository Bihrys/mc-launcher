# HMCL-Qt (Rust + cxx-qt 0.8.1) 开发进度

> 生成时间: 2026-06-28
> 技术栈: Rust (4-crate workspace) + Qt/QML (cxx-qt 0.8.1)
> 参考对象: HMCL Java 版 (源码在 HMCL-main/)

---

## 架构概览

```
launcher-core    — 游戏逻辑层 (实例管理/Java检测/下载/addon解析/启动命令生成)
launcher-app     — 服务/DTO层 (在 core 和 Qt bridge 之间做薄封装)
launcher-qt      — Qt bridge (backend.rs 属性+invokable) + QML UI
launcher-cli     — CLI (未开发)
```

---

## 已完成页面 & 功能 (可视化体验)

### 1. 主页 (HmclMainPage.qml) — 178行
- 实例快速切换列表
- 启动按钮 (带可见性选项: keep/hide/close)
- 版本信息气泡展示

### 2. 账号页 (HmclAccountPage.qml) — 1944行
- 离线登录 (含头像预览)
- 微软登录 (浏览器 OAuth)
- Yggdrasil/外置登录 (第三方认证服务器)
  - 认证服务器管理 (添加/删除)
  - 多角色选择
- 账号切换/删除/刷新
- 皮肤上传
- 账号迁移 (toggle)
- 头像缓存清理

### 3. 下载页 (HmclDownloadPage.qml) — 2223行
- 版本目录浏览 (支持切换下载源)
- 异步目录刷新 + 轮询
- 版本筛选/搜索
- 安装器元数据拉取 (Forge/Fabric/Quilt/NeoForge/OptiFine)
- 加载器版本选择
- 实际下载 + 进度轮询 + 取消
- 安装完成后自动刷新本地版本列表

### 4. Java 管理页 (HmclJavaPage.qml) — 520行
- 本机 Java 运行时检测 (路径/版本/vendor 展示)
- Java 下载 (Adoptium/Zulu/GraalVM 等多发行版 + major 选择)
- 检测结果实时展示列表 (major badge + 版本 + 路径)

### 5. 设置页 (HmclSettingsPage.qml) — 1585行
- 左侧抽屉导航 (全局游戏设置 / Java管理 / 启动器 通用/外观/下载 / 帮助)
- 游戏设置区: 最小/最大内存、窗口宽高、全屏、Java路径、启动器可见性、游戏目录
- Java设置区: 自动选择Java、路径、JVM参数、检测/下载
- 更新设置: 更新通道(stable/dev)、测试版、自动更新对话框
- 语言设置
- 设置实际持久化 (读写 settings.json)

### 6. 实例详情页 (HmclVersionPage.qml) — 1861行
- Tab式布局: 设置 / 安装器 / Mod / 资源包 / 世界 / 结构
- **实例管理操作**: 重命名、复制、删除、清理(日志/缓存)、删除assets、删除libraries
- **启动命令生成**
- **设置Tab**: 内存/窗口/Java等per-instance设置编辑 + 保存
- **安装器Tab**: 已安装加载器列表展示
- **Mod Tab** (真后端):
  - jar/zip 文件扫描 (识别 Fabric/Quilt/Forge/NeoForge 的元数据)
  - Mod名、版本、loader类型 badge 展示
  - 启用/禁用切换 (文件名 .disabled 后缀重命名)
  - 删除
  - 搜索/筛选
  - 刷新 + 打开文件夹
- **资源包 Tab** (真后端):
  - zip + 目录资源包扫描
  - pack.mcmeta 解析 (description + pack_format)
  - 启用/禁用切换
  - 删除
  - 搜索/筛选 + 打开文件夹
- **世界 Tab** (后端已完成, QML正在接线):
  - level.dat NBT 解析 (LevelName, LastPlayed, Version.Name)
  - 删除
- 结构 Tab: 仅打开文件夹 (placeholder)

### 7. 实例列表页 (HmclGameListPage.qml)
- 实例网格/列表展示
- 选择、右键菜单
- Profile 切换面板

### 8. 任务中心 (TaskCenterPane.qml)
- 下载/启动任务状态展示

---

## UI 组件库 (qml/components/)

| 组件 | 用途 |
|------|------|
| TitleBar | 窗口标题栏 (最小化/最大化/关闭) |
| Sidebar | 主侧边导航 |
| HmclNavigator | 页面路由控制 |
| HmclSvgIcon | SVG图标渲染 (HMCL图标集) |
| SplitLaunchButton | 启动按钮 (带下拉) |
| HmclRipple | Material风格水波纹 |
| HmclAnimatedPage | 页面切换动画 |
| BackPageShell | 返回按钮包装 |
| SectionTitle | 区块标题 |

---

## 后端能力 (launcher-core)

| 模块 | 状态 | 说明 |
|------|------|------|
| instance_manager | 完成 | 实例CRUD、详情、文件夹、设置、清理 |
| addon/mod_file | 完成 | Mod扫描+元数据解析+enable/disable/delete |
| addon/resourcepack | 完成 | 资源包扫描+pack.mcmeta解析+enable/disable/delete |
| addon/world | 完成 | 世界目录扫描+level.dat NBT解析+delete |
| addon/datapack | 空壳 | `pub struct DataPack;` |
| addon/shaderpack | 空壳 | `pub struct ShaderPack;` |
| java 检测 | 完成 | 多路径探测本机Java运行时 |
| java 下载 | 完成 | 多发行版异步下载+解压 |
| download | 完成 | 版本目录+安装器元数据+实际下载 |
| launch | 完成 | 启动命令生成+异步启动+任务轮询 |
| settings | 完成 | 全局/per-instance设置持久化 |
| account | 完成 | 离线/微软/Yggdrasil 登录+管理 |

---

## 待开发清单

### 高优先 (功能缺口)

| 任务 | 说明 | 难度 |
|------|------|------|
| Worlds Tab QML 接线 | 后端已完成, QML WorldsTab 组件未写 | 低 |
| ShaderPack Tab | addon/shaderpack.rs 空壳, 类似 resourcepack 模式 | 中 |
| DataPack 管理 | addon/datapack.rs 空壳, 需嵌套在 world 内 | 中 |
| 多游戏目录 (Profile) 支持 | 当前硬编码 "default" profile | 高 |
| 自动更新检查 | 设置页有UI但后端未接 | 中 |
| Mod 在线搜索/下载 (CurseForge/Modrinth) | HMCL核心功能, 当前仅本地管理 | 高 |
| 主题切换 (深色/浅色) | 设置页有外观入口 | 中 |
| 国际化 (i18n) | 当前硬编码中文 | 中 |

### 中优先 (体验对齐)

| 任务 | 说明 |
|------|------|
| 世界导入/导出 zip | HMCL支持, 当前仅list+delete |
| 世界重命名/复制 | HMCL支持 |
| Mod 依赖检测 | HMCL会提示缺失依赖 |
| 版本隔离 vs 非隔离 切换 | 游戏目录配置 |
| 实例图标自定义 | 当前使用 grass.png 默认图标 |
| 启动日志查看器 | HMCL有实时日志窗口 |
| 崩溃分析器 | HMCL会分析crash-report给出建议 |

### 低优先 (锦上添花)

| 任务 | 说明 |
|------|------|
| 游戏内截图管理 | screenshots文件夹浏览 |
| 服务器列表编辑 | servers.dat 解析 |
| 拖拽安装 mod/资源包 | DnD 到窗口自动安装 |
| 启动统计/游戏时长 | 记录每次启动时长 |

---

## 当前构建验证

```bash
# 编译 (通过)
cargo build -p launcher-qt

# 运行验证 (offscreen, 无QML错误)
QT_QPA_PLATFORM=offscreen timeout 8 ./target/debug/launcher-qt
```

---

## 给下次对话的上下文提示

1. **当前断点**: Worlds Tab QML 组件未写 (后端 `instance_worlds_json` + `deleteInstanceWorld` 已就绪, backend.rs 属性 `instanceWorldsJson` 已声明, `reloadWorlds()` JS 函数已加入 HmclVersionPage.qml 但 WorldsTab component 未定义)
2. **接线模式**: core parser → instance_manager.rs pub fn → lib.rs export → app service passthrough → backend.rs property+invokable → backend_instance.rs impl → QML JSON.parse via Connections
3. **cxx-qt 0.8.1 语法**: `#[qproperty(QString, snake_name, cxx_name = "camelName")]`, struct field 同名, `#[qinvokable] #[cxx_name = ".."]`
4. **QML 模式**: `pragma ComponentBehavior: Bound`, 内联 `component` 定义, `Connections { function onXChanged() {...} }` 解析 JSON
5. **验证命令**: 先 `cargo build -p launcher-qt` 再 `QT_QPA_PLATFORM=offscreen timeout 8 ./target/debug/launcher-qt 2>&1 | grep -iE "error|qml|fail"`
6. **HMCL源码参考**: `/home/Bihrys/Projects/mc-launcher/HMCL-main/`
