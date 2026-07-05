#include "java/JavaService.h"

#include <QFileInfo>
#include <QJsonArray>
#include <QProcess>
#include <QRegularExpression>
#include <QStringList>

QJsonObject JavaService::detect() {
    QJsonArray runtimes;
    QStringList candidates = {"java", "/usr/bin/java", "/usr/lib/jvm/default/bin/java"};
    for (const QString &exe : candidates) {
        QProcess p;
        p.start(exe, {"-version"});
        if (!p.waitForFinished(2000)) continue;
        QString text = QString::fromUtf8(p.readAllStandardError() + p.readAllStandardOutput());
        if (text.isEmpty()) continue;
        QString version = "unknown";
        QRegularExpression re("version \\\"([^\\\"]+)\\\"");
        auto m = re.match(text);
        if (m.hasMatch()) version = m.captured(1);
        int major = 0;
        if (version.startsWith("1.")) major = version.mid(2,1).toInt(); else major = version.section('.', 0, 0).toInt();
        QString path = exe == "java" ? "java" : QFileInfo(exe).absoluteFilePath();
        bool exists = exe == "java" || QFileInfo::exists(exe);
        if (exists) runtimes.append(QJsonObject{{"executable", path}, {"path", path}, {"version", version}, {"major", major}, {"vendor", "system"}, {"vendorHint", "system"}});
    }
    return QJsonObject{{"runtimes", runtimes}, {"count", runtimes.size()}};
}

QString JavaService::downloadPlaceholder(const QString &distribution, const QString &major, const QString &packageType) {
    return QString("Java 下载接口已迁移到 C++ 占位层。\n\n发行版: %1\n版本: Java %2\n包类型: %3\n\n后续应按 HMCL JavaDownloadTask / JavaRepositoryProvider 接入真实下载。")
        .arg(distribution, major, packageType);
}
