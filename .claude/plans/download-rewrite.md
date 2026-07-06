# Download System Rewrite Plan - HMCL一致

## Context
当前下载系统是平坦的单进度条模型，缺少HMCL的分阶段任务层次显示、动画过渡、ETA计算等功能。需要重写为与HMCL一致的层次化任务系统+像素级UI复刻。

## Phase 1: Backend - 层次化任务模型

**目标**: 把平坦的JSON状态对象替换为HMCL风格的stages数组

**修改文件**:
- `src/download/GameInstaller.h/cpp` — 添加stages数组，每个阶段有独立计数和状态
- `src/download/Downloader.h/cpp` — 添加per-stage回调支持
- `src/bridge/LauncherBackend.cpp` — 序列化完整stages给QML

**新状态结构**:
```json
{
  "active": true,
  "stages": [
    {"id": "game", "title": "安装 Minecraft 1.21", "status": "succeeded", "count": 1, "total": 1},
    {"id": "libraries", "title": "下载依赖库", "status": "running", "count": 23, "total": 45},
    {"id": "assets", "title": "下载资源文件", "status": "waiting", "count": 0, "total": 0}
  ],
  "currentTasks": [
    {"name": "lwjgl-3.3.3.jar", "progress": 0.67},
    {"name": "netty-4.1.97.jar", "progress": 0.12}
  ],
  "percent": 34,
  "speed": 5242880,
  "speedText": "5.0 MB/s",
  "eta": 45,
  "totalFiles": 312,
  "finishedFiles": 89,
  "status": "downloading"
}
```

## Phase 2: UI - TaskExecutorDialogPane

**目标**: 替换当前的DownloadDialogCard为HMCL风格的层次化任务列表

**新建文件**:
- `qml/features/download/TaskExecutorDialogPane.qml` — 500x300 dialog，包含:
  - 顶部: 14px粗体标题
  - 中间: TaskListPane (ScrollView)
    - StageNode: 状态图标(14px) + 标题 + "X/Y"计数
    - ProgressNode: 左缩进26px + 文件名 + 进度条
  - 底部: 速度标签(左) + 取消按钮(右)

**修改文件**:
- `qml/features/download/HmclDownloadPage.qml` — 替换DownloadDialogCard为新组件

## Phase 3: 动画系统完善

**修改文件**:
- `qml/Hmcl/animation/Motion.qml` — 添加完整MD3 duration tokens
- `qml/Hmcl/animation/ContainerAnimations.qml` — 添加FORWARD/BACKWARD/NAVIGATION动画函数
- `qml/Hmcl/style/HmclTokens.qml` — 补全timing tokens

**页面切换动画**:
- VersionsPage → InstallersPage: FORWARD (旧页左移淡出，新页右侧滑入)
- InstallersPage → VersionsPage: BACKWARD (反向)
- 利用已有的 `HmclSectionTransition.qml` TransitionPane

## Phase 4: 版本列表/安装器页面UI对齐

**修改文件**:
- `qml/features/download/HmclDownloadPage.qml` — 内联组件重构:
  - VersionsPagePane: 使用TransitionPane切换加载/内容/失败状态
  - InstallerItemCard: 对齐HMCL尺寸和阴影
  - 页面间过渡使用ContainerAnimations

## 实施顺序
1. Phase 1 (backend) → Phase 2 (dialog UI) → Phase 3 (animations) → Phase 4 (polish)
2. 每阶段完成后编译验证

## 验证方式
- `cmake --build build-cpp` 编译通过
- 运行应用，触发下载，观察新dialog显示stages
- 页面切换有SLIDE_UP_FADE_IN过渡动画
