# mc-launcher-qt-cpp

Qt Quick/QML + C++

## 构建

```bash
sudo apt install qt6-base-dev qt6-declarative-dev qt6-quickcontrols2-dev cmake ninja-build
cd mc-launcher-qt-cpp
cmake -S . -B build -G Ninja
cmake --build build
./build/mc-launcher-qt-cpp
```

## 安装器选择页与实时 FPS 修复

下载向导的版本页、安装器选择页和加载器版本页改为持久页面实例，不再通过下载模块内部的动态 Loader 销毁重建。标题栏新增基于 `QQuickWindow::frameSwapped` 的实时 FPS 显示。详见 `docs/DOWNLOAD_INSTALLER_PAGE_AND_FPS_FIX.md`。

## 本次 HMCL 对齐修复

- 移植 Forge / NeoForge / Fabric / Quilt 安装器冲突矩阵；不兼容卡片保持可见但不可点击。
- 版本列表来源与文件下载来源分开设置，并实际传入元数据请求和安装下载任务。
- 修复自动下载源：大陆中文环境镜像优先，其他环境官方优先，失败时回退。
- 按 HMCL/JFoenix 像素规格修正设置页单选圆：14 px 外圈、2 px 描边、8 px 内点、30 px 普通行。
- 修复默认、经典、自定义、网络、纯色背景的即时切换和内置壁纸回退。
- 对仅保存配置、尚未接入运行逻辑的设置显示并禁用“待开发”。
- 完整审计见 `docs/SETTINGS_IMPLEMENTATION_AUDIT.md`。
