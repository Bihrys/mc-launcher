# 运行与崩溃日志

程序启动后会自动创建以下日志：

- `~/.local/share/mc-launcher-qt-cpp/logs/latest.log`：当前一次运行的完整日志，启动时覆盖。
- `~/.local/share/mc-launcher-qt-cpp/logs/session-<时间>-pid<进程号>-<会话ID>.log`：按会话永久保存的日志，默认保留最近 30 份。
- `~/.local/share/mc-launcher-qt-cpp/logs/crash-last.log`：最近一次原生致命信号及调用栈。
- `~/.local/share/mc-launcher-qt-cpp/logs/last-run-state.json`：判断上次是否正常退出。

日志覆盖：

1. 程序启动、QML 加载、窗口显示/隐藏/关闭和应用状态变化。
2. 鼠标按下、释放、双击、滚轮、拖动及点击位置对应的 Qt Quick 控件路径。
3. 键盘按键、快捷键、焦点变化和输入法提交长度。
4. 页面跳转、返回、设置分区、主题、背景、账户、下载、实例和启动流程的语义事件。
5. 所有 `LauncherBackend` 操作的开始、结束、参数摘要和耗时。
6. 后端 JSON 状态变化、下载与启动任务状态变化。
7. Qt/QML 的 debug、warning、critical、fatal 消息及源码位置。
8. `std::terminate`、`SIGSEGV`、`SIGABRT`、`SIGBUS`、`SIGFPE`、`SIGILL`。

## 复现崩溃

建议使用 Debug 构建：

```bash
cd ~/Projects/mc-launcher
rm -rf build-cpp
cmake -S . -B build-cpp -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_PREFIX_PATH=/usr/lib/cmake \
  -DQt6_DIR=/usr/lib/cmake/Qt6
cmake --build build-cpp -j"$(nproc)"
./build-cpp/mc-launcher-qt-cpp
```

崩溃后首先查看：

```bash
tail -n 300 ~/.local/share/mc-launcher-qt-cpp/logs/latest.log
cat ~/.local/share/mc-launcher-qt-cpp/logs/crash-last.log
cat ~/.local/share/mc-launcher-qt-cpp/logs/last-run-state.json
```

日志中的典型定位顺序是：

```text
ui.pointer press/release
ui.navigation 或 ui.<功能> 语义事件
backend <方法>.begin
backend.state property_changed
Qt/QML warning 或 fatal
crash-last.log 调用栈
```

若 `crash-last.log` 只有地址，可在未删除相同 Debug 可执行文件的前提下执行：

```bash
addr2line -Cfipe ./build-cpp/mc-launcher-qt-cpp 0x地址1 0x地址2
```

## 隐私处理

日志不会记录输入框正文，只记录按键和输入长度。密码、访问令牌、刷新令牌、Authorization、Bearer、OAuth code 以及启动命令中的 `--accessToken` 等字段会自动替换为 `<redacted>`。

## 终端级日志与崩溃资料打包

应用自身日志无法覆盖“动态库加载失败”或“进入 `main()` 之前就退出”的情况。需要完整复现时，从项目根目录运行：

```bash
./scripts/run-with-logs.sh ./build-cpp/mc-launcher-qt-cpp
```

需要同时打开 Qt 插件、QML 导入和场景图诊断时：

```bash
./scripts/run-with-logs.sh --verbose-qt ./build-cpp/mc-launcher-qt-cpp
```

崩溃后将最新应用日志、原生崩溃日志、终端捕获和系统信息打包：

```bash
./scripts/collect-crash-logs.sh
```

脚本会输出生成的 `mc-launcher-crash-<时间>.tar.gz` 路径。
