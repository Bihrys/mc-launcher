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

## 当前状态

这一版完成的是“可启动的 C++/QML 项目骨架 + 当前 QML 前端对接层”。后端按 HMCL 模块边界拆分，但没有逐行复制 HMCL Java 代码。若后续直接翻译 HMCL 具体实现，需要遵守 HMCL 的 GPLv3 许可要求。

## Detailed operation and crash logging

The launcher now records UI interactions, navigation, backend calls, task state transitions, Qt/QML warnings, clean/unclean shutdown state, and native crash backtraces. See `docs/LOGGING.md`.
