#include "launch/LaunchService.h"

#include <QJsonArray>
#include <QProcess>
#include <QStringList>

QJsonObject LaunchService::idle() const {
    return QJsonObject{{"id", ""}, {"active", false}, {"percent", 0}, {"title", "空闲"}, {"message", "还没有启动任务。"}, {"status", "idle"}, {"visibility", "hide"}, {"gameStarted", false}, {"shouldHide", false}, {"shouldClose", false}, {"shouldReopen", false}, {"pid", 0}, {"canCancel", false}, {"cancelled", false}, {"speedText", "请耐心等待"}, {"currentStage", ""}, {"stages", QJsonArray{}}, {"tasks", QJsonArray{}}};
}

QJsonObject LaunchService::launch(const QString &versionId, const QString &visibility, const QString &commandLine) {
    QJsonArray stages;
    stages.append(QJsonObject{{"key", "check"}, {"title", "检查游戏完整性"}, {"finished", true}, {"active", false}});
    stages.append(QJsonObject{{"key", "command"}, {"title", "生成启动命令"}, {"finished", true}, {"active", false}});

    if (versionId.trimmed().isEmpty()) {
        stages.append(QJsonObject{{"key", "failed"}, {"title", "启动失败"}, {"finished", false}, {"active", false}});
        return QJsonObject{{"id", "cpp-launch-empty"}, {"active", false}, {"percent", 100}, {"title", "未选择游戏版本"}, {"message", "当前没有选中的游戏版本。请先安装或选择一个版本。"}, {"status", "failed"}, {"visibility", visibility}, {"gameStarted", false}, {"shouldHide", false}, {"shouldClose", false}, {"shouldReopen", false}, {"pid", 0}, {"canCancel", false}, {"cancelled", false}, {"speedText", "失败"}, {"currentStage", "failed"}, {"stages", stages}, {"tasks", QJsonArray{}}};
    }

    if (commandLine.trimmed().isEmpty() || commandLine.trimmed().startsWith("echo ")) {
        QString message = QString("版本 ") + versionId + QString(" 无法生成启动命令。");
        if (commandLine.trimmed().startsWith("echo ")) {
            message = commandLine.trimmed().mid(5).trimmed();
            if (message.startsWith("'") && message.endsWith("'") && message.size() >= 2) message = message.mid(1, message.size() - 2);
            message.replace("'\\''", "'");
        }
        stages.append(QJsonObject{{"key", "failed"}, {"title", "启动失败"}, {"finished", false}, {"active", false}});
        return QJsonObject{{"id", "cpp-launch-command-empty"}, {"active", false}, {"percent", 100}, {"title", "无法启动游戏"}, {"message", message}, {"status", "failed"}, {"visibility", visibility}, {"gameStarted", false}, {"shouldHide", false}, {"shouldClose", false}, {"shouldReopen", false}, {"pid", 0}, {"canCancel", false}, {"cancelled", false}, {"speedText", "失败"}, {"currentStage", "failed"}, {"stages", stages}, {"tasks", QJsonArray{}}};
    }

    qint64 pid = 0;
    const bool started = QProcess::startDetached("/bin/sh", QStringList{"-lc", commandLine}, QString(), &pid);

    stages.append(QJsonObject{{"key", started ? "done" : "failed"}, {"title", started ? "已提交启动进程" : "启动失败"}, {"finished", started}, {"active", false}});

    return QJsonObject{
        {"id", QString("cpp-launch-") + versionId},
        {"active", false},
        {"percent", 100},
        {"title", started ? "游戏进程已启动" : "启动进程创建失败"},
        {"message", started ? QString("已按当前版本 JSON 生成命令并拉起进程：") + versionId : QString("无法拉起 /bin/sh 或 Java 进程。命令：") + commandLine},
        {"status", started ? "gameStarted" : "failed"},
        {"visibility", visibility},
        {"gameStarted", started},
        {"shouldHide", started && visibility == "hide"},
        {"shouldClose", started && visibility == "close"},
        {"shouldReopen", false},
        {"pid", static_cast<double>(pid)},
        {"canCancel", false},
        {"cancelled", false},
        {"speedText", started ? "已启动" : "失败"},
        {"currentStage", started ? "done" : "failed"},
        {"commandLine", commandLine},
        {"stages", stages},
        {"tasks", QJsonArray{}}
    };
}

QJsonObject LaunchService::cancelled() const {
    QJsonObject out = idle();
    out["status"] = "cancelled";
    out["cancelled"] = true;
    out["message"] = "启动任务已取消。";
    return out;
}
