#pragma once

#include <QJsonObject>
#include <QString>

#include <atomic>
#include <functional>
#include <memory>

class JavaService {
public:
    QJsonObject detect(bool useCache = true) const;
    QJsonObject addJavaPath(const QString &path) const;
    QJsonObject disableJava(const QString &path) const;
    QJsonObject restoreJava(const QString &path) const;
    QJsonObject removeDisabledJava(const QString &path) const;
    QJsonObject uninstallManagedJava(const QString &path) const;
    QJsonObject installJavaArchive(const QString &archivePath) const;
    QJsonObject downloadJava(
        const QString &distribution,
        int major,
        const QString &packageType,
        const std::function<void(const QJsonObject &)> &progress = {},
        std::shared_ptr<std::atomic_bool> cancellation = {}) const;

private:
    QString normalizeInputPath(const QString &path) const;
    QString resolveJavaExecutable(const QString &path) const;
    QJsonObject inspectRuntime(const QString &executable,
                               const QJsonObject &cacheEntry = {}) const;
    QJsonObject loadState() const;
    bool saveState(const QJsonObject &state) const;
};
