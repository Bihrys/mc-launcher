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
