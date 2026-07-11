#include <QElapsedTimer>
#include <QEvent>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlError>
#include <QQuickStyle>
#include <QtQml>

#include <exception>

#include "bridge/LauncherBackend.h"
#include "diagnostics/FpsMonitor.h"
#include "logging/AppLogger.h"
#include "logging/InteractionEventFilter.h"
#include "models/GameListModel.h"
#include "models/ProfileListModel.h"

namespace {
bool isTrackedInputEvent(QEvent::Type type) {
    switch (type) {
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
    case QEvent::MouseButtonDblClick:
    case QEvent::Wheel:
    case QEvent::KeyPress:
    case QEvent::KeyRelease:
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::Shortcut:
        return true;
    default:
        return false;
    }
}

class LoggedGuiApplication final : public QGuiApplication {
public:
    using QGuiApplication::QGuiApplication;

    bool notify(QObject *receiver, QEvent *event) override {
        // 事件处理可能会删除 receiver，因此所有诊断字段必须在分发前复制。
        const int eventType = event ? static_cast<int>(event->type()) : -1;
        const QString receiverClass = receiver && receiver->metaObject()
            ? QString::fromLatin1(receiver->metaObject()->className()) : QString();
        const QString receiverObjectName = receiver ? receiver->objectName() : QString();
        const bool tracked = event && isTrackedInputEvent(event->type());
        QElapsedTimer timer;
        if (tracked) timer.start();

        try {
            const bool handled = QGuiApplication::notify(receiver, event);
            const qint64 durationMs = tracked ? timer.elapsed() : 0;
            if (tracked && durationMs >= 100) {
                AppLogger::warning("ui.dispatch", "slow_input_event",
                                   "一次输入事件处理耗时超过 100 ms。", {
                    {"eventType", eventType},
                    {"durationMs", static_cast<double>(durationMs)},
                    {"handled", handled},
                    {"receiverClass", receiverClass},
                    {"receiverObjectName", receiverObjectName}
                });
            }
            return handled;
        } catch (const std::exception &exception) {
            AppLogger::fatal("ui.dispatch", "exception_during_event",
                             QString::fromUtf8(exception.what()), {
                {"eventType", eventType},
                {"receiverClass", receiverClass},
                {"receiverObjectName", receiverObjectName}
            });
            AppLogger::flush();
            throw;
        } catch (...) {
            AppLogger::fatal("ui.dispatch", "unknown_exception_during_event", QString(), {
                {"eventType", eventType},
                {"receiverClass", receiverClass},
                {"receiverObjectName", receiverObjectName}
            });
            AppLogger::flush();
            throw;
        }
    }
};
} // namespace

int main(int argc, char *argv[]) {
    LoggedGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName("Bihrys");
    QCoreApplication::setApplicationName("mc-launcher-qt-cpp");
    QCoreApplication::setApplicationVersion("0.1.0");

    AppLogger::initialize();
    AppLogger::installQtMessageHandler();
    AppLogger::installCrashHandlers();

    InteractionEventFilter interactionFilter;
    app.installEventFilter(&interactionFilter);

    QObject::connect(&app, &QGuiApplication::applicationStateChanged,
                     &app, [](Qt::ApplicationState state) {
        AppLogger::info("lifecycle", "application_state_changed", QString(), {
            {"state", static_cast<int>(state)}
        });
    });
    QObject::connect(&app, &QCoreApplication::aboutToQuit,
                     &app, []() {
        AppLogger::info("lifecycle", "about_to_quit");
        AppLogger::flush();
    });

    QQuickStyle::setStyle("Basic");
    AppLogger::info("qml", "quick_style_selected", QString(), {{"style", "Basic"}});

    qmlRegisterType<LauncherBackend>("com.bihrys.launcher", 1, 0, "LauncherBackend");
    qmlRegisterType<FpsMonitor>("com.bihrys.launcher", 1, 0, "FpsMonitor");
    qmlRegisterType<GameListModel>("com.bihrys.launcher", 1, 0, "GameListModel");
    qmlRegisterType<ProfileListModel>("com.bihrys.launcher", 1, 0, "ProfileListModel");
    AppLogger::info("qml", "types_registered");

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     &app, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            AppLogger::warning("qml", "engine_warning", warning.description(), {
                {"url", warning.url().toString()},
                {"line", warning.line()},
                {"column", warning.column()},
                {"object", warning.object() ? QString::fromLatin1(warning.object()->metaObject()->className()) : QString()}
            });
        }
    });

    const QUrl url(QStringLiteral("qrc:/qt/qml/com/bihrys/launcher/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *object, const QUrl &objectUrl) {
        AppLogger::info("qml", "root_object_created", QString(), {
            {"requestedUrl", url.toString()},
            {"objectUrl", objectUrl.toString()},
            {"success", object != nullptr},
            {"class", object ? QString::fromLatin1(object->metaObject()->className()) : QString()}
        });
    }, Qt::QueuedConnection);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() {
        AppLogger::fatal("qml", "root_object_creation_failed",
                         "QML 根对象创建失败，应用将退出。",
                         {{"exitCode", -1}});
        AppLogger::flush();
        QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    AppLogger::info("qml", "engine_load_begin", QString(), {{"url", url.toString()}});
    engine.load(url);
    AppLogger::info("qml", "engine_load_returned", QString(), {
        {"rootObjectCount", engine.rootObjects().size()}
    });

    int exitCode = -1;
    try {
        exitCode = app.exec();
    } catch (const std::exception &e) {
        AppLogger::fatal("crash", "exception_escaped_event_loop",
                         QString::fromUtf8(e.what()));
        exitCode = -2;
    } catch (...) {
        AppLogger::fatal("crash", "unknown_exception_escaped_event_loop");
        exitCode = -3;
    }

    AppLogger::markCleanShutdown(exitCode);
    return exitCode;
}
