#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml>

#include "bridge/LauncherBackend.h"
#include "models/GameListModel.h"
#include "models/ProfileListModel.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName("Bihrys");
    QCoreApplication::setApplicationName("mc-launcher-qt-cpp");
    QQuickStyle::setStyle("Basic");

    qmlRegisterType<LauncherBackend>("com.bihrys.launcher", 1, 0, "LauncherBackend");
    qmlRegisterType<GameListModel>("com.bihrys.launcher", 1, 0, "GameListModel");
    qmlRegisterType<ProfileListModel>("com.bihrys.launcher", 1, 0, "ProfileListModel");

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/qt/qml/com/bihrys/launcher/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.load(url);
    return app.exec();
}
