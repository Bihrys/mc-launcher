#include "launch/LaunchService.h"

#include <QJsonArray>

QJsonObject LaunchService::idle() const {
    return QJsonObject{{"id", ""}, {"active", false}, {"percent", 0}, {"title", "空闲"}, {"message", "还没有启动任务。"}, {"status", "idle"}, {"visibility", "hide"}, {"gameStarted", false}, {"shouldHide", false}, {"shouldClose", false}, {"shouldReopen", false}, {"pid", 0}, {"canCancel", false}, {"cancelled", false}, {"speedText", "请耐心等待"}, {"currentStage", ""}, {"stages", QJsonArray{}}, {"tasks", QJsonArray{}}};
}

QJsonObject LaunchService::launch(const QString &versionId, const QString &visibility) {
    QJsonArray stages;
    stages.append(QJsonObject{{"key", "check"}, {"title", "检查游戏完整性"}, {"finished", true}, {"active", false}});
    stages.append(QJsonObject{{"key", "command"}, {"title", "生成启动命令"}, {"finished", true}, {"active", false}});
    stages.append(QJsonObject{{"key", "done"}, {"title", "完成"}, {"finished", true}, {"active", false}});
    return QJsonObject{{"id", "cpp-launch-1"}, {"active", false}, {"percent", 100}, {"title", "启动流程已生成"}, {"message", "C++ 重构骨架尚未真正拉起 Minecraft 进程：" + versionId}, {"status", "finished"}, {"visibility", visibility}, {"gameStarted", false}, {"shouldHide", false}, {"shouldClose", false}, {"shouldReopen", false}, {"pid", 0}, {"canCancel", false}, {"cancelled", false}, {"speedText", "完成"}, {"currentStage", "done"}, {"stages", stages}, {"tasks", QJsonArray{}}};
}

QJsonObject LaunchService::cancelled() const {
    QJsonObject out = idle();
    out["status"] = "cancelled";
    out["cancelled"] = true;
    out["message"] = "启动任务已取消。";
    return out;
}
