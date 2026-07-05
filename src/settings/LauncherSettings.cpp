#include "settings/LauncherSettings.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"

#include <QFile>
#include <QFontDatabase>
#include <QJsonArray>
#include <QStorageInfo>
#include <QSet>

QJsonObject LauncherSettings::defaults() const {
    const char *raw = R"JSON({
        "themeMode": "light",
        "themeBrightnessMode": "auto",
        "themeColor": "default",
        "themeColorType": "default",
        "customThemeColor": "#5C6BC0",
        "themeAppearanceOverrides": "",
        "selectedThemeTitle": "默认",
        "launcherVisibility": "hide",
        "updateChannel": "stable",
        "acceptPreviewUpdate": false,
        "disableAutoShowUpdateDialog": false,
        "checkUpdateOnStartup": true,
        "minMemoryMb": 256,
        "maxMemoryMb": 4096,
        "autoMemory": true,
        "defaultIsolation": "modded",
        "javaType": "auto",
        "customJavaVersion": "17",
        "gameWidth": 854,
        "gameHeight": 480,
        "fullscreen": false,
        "windowType": "windowed",
        "gameResolution": "854x480",
        "quickPlayType": "none",
        "quickPlayServer": "",
        "quickPlaySingleplayer": "",
        "javaPath": "",
        "javaAuto": true,
        "jvmArgs": "",
        "noJVMOptions": false,
        "noOptimizingJVMOptions": false,
        "notCheckJVM": false,
        "permSize": "",
        "gameDir": "",
        "preLaunchCommand": "",
        "commandWrapper": "",
        "postExitCommand": "",
        "language": "zh_CN",
        "disableAprilFools": false,
        "titleTransparent": false,
        "turnOffAnimations": false,
        "disableAutoGameOptions": false,
        "enableGameList": true,
        "enableOfflineAccount": true,
        "allowAutoAgent": true,
        "showLogs": false,
        "enableDebugLogOutput": false,
        "notCheckGame": false,
        "runningDir": "",
        "gameArguments": "",
        "environmentVariables": "",
        "processPriority": "normal",
        "graphicsBackend": "default",
        "openGLRenderer": "default",
        "themePack": "default",
        "themeColorStyle": "system",
        "themeBrightness": "auto",
        "backgroundType": "default",
        "builtinBackgroundId": "2021-08-26",
        "backgroundImage": "",
        "customBackgroundImagePath": "",
        "backgroundImageUrl": "",
        "networkBackgroundImageUrl": "",
        "backgroundPaint": "",
        "customBackgroundPaint": "",
        "backgroundOpacity": 1.0,
        "fallbackBackgroundType": "builtin",
        "backgroundFallbackType": "builtin",
        "backgroundFallbackPaint": "",
        "backgroundLoadPolicy": "wait_for_background",
        "networkBackgroundImageCachePolicy": "enabled",
        "logFont": "monospace",
        "logFontFamily": "monospace",
        "logFontSize": 12.0,
        "globalFontFamily": "",
        "launcherFontFamily": "",
        "autoChooseDownloadSource": true,
        "versionListSource": "balanced",
        "downloadSource": "balanced",
        "defaultAddonSource": "modrinth",
        "commonDirType": "default",
        "commonDirectory": "",
        "autoDownloadThreads": true,
        "downloadThreads": 64,
        "proxyType": "default",
        "proxyHost": "",
        "proxyPort": 0,
        "proxyUsername": "",
        "proxyPassword": "",
        "hasProxyAuth": false,
        "uiScale": 1.0,
        "fontAntiAliasing": "auto"
    })JSON";
    return JsonUtil::objectFromString(QString::fromUtf8(raw), {});
}

QJsonObject LauncherSettings::load() {
    QJsonObject out = defaults();
    merge(out, JsonUtil::readObjectFile(LauncherPaths::settingsFile(), {}));
    save(out);
    return out;
}

bool LauncherSettings::save(const QJsonObject &settings) {
    return JsonUtil::writeObjectFile(LauncherPaths::settingsFile(), settings);
}

QJsonObject LauncherSettings::update(const QString &key, const QString &rawValue) {
    QJsonObject settings = load();
    settings.insert(key, parseValue(key, rawValue));
    save(settings);
    return settings;
}

QJsonObject LauncherSettings::appearanceOptions() const {
    QJsonArray builtinBackgrounds;
    builtinBackgrounds.append(QJsonObject{{"id", "2021-08-26"}, {"title", "2021-08-26"}});
    builtinBackgrounds.append(QJsonObject{{"id", "2016-02-25"}, {"title", "2016-02-25"}});
    builtinBackgrounds.append(QJsonObject{{"id", "2015-06-22"}, {"title", "2015-06-22"}});

    QJsonArray fonts;
    const auto families = QFontDatabase::families();
    for (int i = 0; i < families.size() && i < 80; ++i) fonts.append(families.at(i));

    QJsonArray colors;
    colors.append(QJsonObject{{"id", "default"}, {"title", "默认"}, {"value", "#5C6BC0"}});
    colors.append(QJsonObject{{"id", "blue"}, {"title", "蓝色"}, {"value", "#5C6BC0"}});
    colors.append(QJsonObject{{"id", "green"}, {"title", "绿色"}, {"value", "#43A047"}});
    colors.append(QJsonObject{{"id", "purple"}, {"title", "紫色"}, {"value", "#7E57C2"}});
    colors.append(QJsonObject{{"id", "red"}, {"title", "红色"}, {"value", "#E53935"}});

    return QJsonObject{{"builtinBackgrounds", builtinBackgrounds}, {"fontFamilies", fonts}, {"themeColors", colors}};
}

QJsonObject LauncherSettings::systemMemory() const {
    quint64 total = 0;
#if defined(Q_OS_LINUX)
    QFile meminfo("/proc/meminfo");
    if (meminfo.open(QIODevice::ReadOnly)) {
        const auto lines = meminfo.readAll().split('\n');
        for (const auto &line : lines) {
            if (line.startsWith("MemTotal:")) {
                QList<QByteArray> parts = line.simplified().split(' ');
                if (parts.size() >= 2) total = parts[1].toULongLong() / 1024;
                break;
            }
        }
    }
#endif
    if (total == 0) total = 8192;
    const int recommendedMax = static_cast<int>(qMax<quint64>(1024, total / 2));
    return QJsonObject{{"totalMb", static_cast<qint64>(total)}, {"recommendedMinMb", 256}, {"recommendedMaxMb", recommendedMax}};
}

void LauncherSettings::merge(QJsonObject &base, const QJsonObject &overlay) {
    for (auto it = overlay.begin(); it != overlay.end(); ++it) base.insert(it.key(), it.value());
}

QJsonValue LauncherSettings::parseValue(const QString &key, const QString &rawValue) {
    const QString v = rawValue.trimmed();
    static const QSet<QString> boolKeys = {
        "autoMemory", "noJVMOptions", "noOptimizingJVMOptions", "notCheckJVM", "javaAuto",
        "titleTransparent", "turnOffAnimations", "animationDisabled", "acceptPreviewUpdate",
        "disableAutoShowUpdateDialog", "checkUpdateOnStartup", "disableAprilFools", "disableAutoGameOptions",
        "showLogs", "enableDebugLogOutput", "notCheckGame", "enableGameList", "enableOfflineAccount",
        "allowAutoAgent", "autoChooseDownloadSource", "autoDownloadThreads", "hasProxyAuth", "fullscreen"
    };
    static const QSet<QString> intKeys = {"minMemoryMb", "maxMemoryMb", "gameWidth", "gameHeight", "downloadThreads", "proxyPort"};
    static const QSet<QString> doubleKeys = {"uiScale", "backgroundOpacity", "logFontSize"};
    if (boolKeys.contains(key)) return v == "true";
    if (intKeys.contains(key)) return v.toInt();
    if (doubleKeys.contains(key)) return v.toDouble();
    return rawValue;
}
