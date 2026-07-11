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
