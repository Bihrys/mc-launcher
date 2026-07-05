/****************************************************************************
** Meta object code from reading C++ file 'LauncherBackend.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../src/bridge/LauncherBackend.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'LauncherBackend.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN15LauncherBackendE_t {};
} // unnamed namespace

template <> constexpr inline auto LauncherBackend::qt_create_metaobjectdata<qt_meta_tag_ZN15LauncherBackendE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "LauncherBackend",
        "outputChanged",
        "",
        "currentAccountNameChanged",
        "currentAccountKindChanged",
        "currentAccountAvatarUrlChanged",
        "accountsJsonChanged",
        "pendingYggdrasilProfilesJsonChanged",
        "authServersJsonChanged",
        "downloadCatalogJsonChanged",
        "downloadTaskJsonChanged",
        "installedVersionsJsonChanged",
        "instanceListJsonChanged",
        "instanceDetailJsonChanged",
        "selectedGameVersionChanged",
        "launchTaskJsonChanged",
        "launcherSettingsJsonChanged",
        "detectedJavaJsonChanged",
        "instanceModsJsonChanged",
        "instanceResourcepacksJsonChanged",
        "instanceWorldsJsonChanged",
        "detectJava",
        "startDetectJava",
        "pollJavaTask",
        "downloadJava",
        "distribution",
        "major",
        "packageType",
        "loginOffline",
        "username",
        "loginYggdrasil",
        "serverUrl",
        "password",
        "pollYggdrasilLoginTask",
        "loginMicrosoftBrowser",
        "clientId",
        "selectYggdrasilProfile",
        "index",
        "refreshAccounts",
        "refreshAuthServers",
        "addAuthServer",
        "name",
        "url",
        "deleteAuthServer",
        "offlineAvatarPreview",
        "switchAccount",
        "switchAccountFast",
        "displayKind",
        "avatarUrl",
        "switchAccountByIdentifier",
        "identifier",
        "deleteAccount",
        "startRefreshAccount",
        "startUploadSkin",
        "fileUrl",
        "model",
        "startMigrateAccount",
        "target",
        "startCleanupAvatarCache",
        "pollRefreshAccountTask",
        "refreshDownloadCatalog",
        "source",
        "startRefreshDownloadCatalog",
        "pollDownloadCatalogTask",
        "startFetchInstallerMetadata",
        "gameVersion",
        "startFetchLoaderMetadata",
        "loaderKind",
        "pollInstallerMetadataTask",
        "installGameVersion",
        "loaderVersion",
        "pollDownloadTask",
        "cancelDownloadTask",
        "refreshInstalledVersions",
        "refreshInstances",
        "refreshInstanceDetail",
        "versionId",
        "refreshInstanceMods",
        "setInstanceModEnabled",
        "fileName",
        "enabled",
        "deleteInstanceMod",
        "refreshInstanceResourcepacks",
        "setInstanceResourcepackEnabled",
        "deleteInstanceResourcepack",
        "refreshInstanceWorlds",
        "deleteInstanceWorld",
        "selectInstance",
        "renameInstance",
        "newName",
        "duplicateInstance",
        "copySaves",
        "deleteInstance",
        "openInstanceFolder",
        "folderKey",
        "generateInstanceLaunchCommand",
        "cleanInstance",
        "clearInstanceAssets",
        "clearInstanceLibraries",
        "saveInstanceSettings",
        "settingsJson",
        "selectGameVersion",
        "deleteGameVersion",
        "launchSelectedVersion",
        "startLaunchSelectedVersion",
        "visibility",
        "cancelLaunchTask",
        "pollLaunchTask",
        "refreshLauncherSettings",
        "refreshSystemMemory",
        "refreshAppearanceOptions",
        "exportLauncherThemePack",
        "updateLauncherSetting",
        "key",
        "value",
        "generateLaunchCommand",
        "openFolder",
        "path",
        "openLauncherSpecialFolder",
        "kind",
        "exportLauncherDiagnostics",
        "resetLauncherSettings",
        "clearLauncherCache",
        "openUrl",
        "output",
        "currentAccountName",
        "currentAccountKind",
        "currentAccountAvatarUrl",
        "accountsJson",
        "pendingYggdrasilProfilesJson",
        "authServersJson",
        "downloadCatalogJson",
        "downloadTaskJson",
        "installedVersionsJson",
        "instanceListJson",
        "instanceDetailJson",
        "selectedGameVersion",
        "launchTaskJson",
        "launcherSettingsJson",
        "detectedJavaJson",
        "instanceModsJson",
        "instanceResourcepacksJson",
        "instanceWorldsJson"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'outputChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currentAccountNameChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currentAccountKindChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currentAccountAvatarUrlChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'accountsJsonChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'pendingYggdrasilProfilesJsonChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'authServersJsonChanged'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'downloadCatalogJsonChanged'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'downloadTaskJsonChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'installedVersionsJsonChanged'
        QtMocHelpers::SignalData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'instanceListJsonChanged'
        QtMocHelpers::SignalData<void()>(12, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'instanceDetailJsonChanged'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'selectedGameVersionChanged'
        QtMocHelpers::SignalData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'launchTaskJsonChanged'
        QtMocHelpers::SignalData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'launcherSettingsJsonChanged'
        QtMocHelpers::SignalData<void()>(16, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'detectedJavaJsonChanged'
        QtMocHelpers::SignalData<void()>(17, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'instanceModsJsonChanged'
        QtMocHelpers::SignalData<void()>(18, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'instanceResourcepacksJsonChanged'
        QtMocHelpers::SignalData<void()>(19, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'instanceWorldsJsonChanged'
        QtMocHelpers::SignalData<void()>(20, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'detectJava'
        QtMocHelpers::MethodData<void()>(21, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'startDetectJava'
        QtMocHelpers::MethodData<void()>(22, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'pollJavaTask'
        QtMocHelpers::MethodData<QString()>(23, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'downloadJava'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 25 }, { QMetaType::QString, 26 }, { QMetaType::QString, 27 },
        }}),
        // Method 'loginOffline'
        QtMocHelpers::MethodData<void(const QString &)>(28, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 29 },
        }}),
        // Method 'loginYggdrasil'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(30, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 31 }, { QMetaType::QString, 29 }, { QMetaType::QString, 32 },
        }}),
        // Method 'pollYggdrasilLoginTask'
        QtMocHelpers::MethodData<QString()>(33, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'loginMicrosoftBrowser'
        QtMocHelpers::MethodData<void(const QString &)>(34, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 35 },
        }}),
        // Method 'selectYggdrasilProfile'
        QtMocHelpers::MethodData<void(const QString &)>(36, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 37 },
        }}),
        // Method 'refreshAccounts'
        QtMocHelpers::MethodData<QString()>(38, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'refreshAuthServers'
        QtMocHelpers::MethodData<QString()>(39, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'addAuthServer'
        QtMocHelpers::MethodData<QString(const QString &, const QString &)>(40, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 41 }, { QMetaType::QString, 42 },
        }}),
        // Method 'deleteAuthServer'
        QtMocHelpers::MethodData<QString(const QString &)>(43, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 37 },
        }}),
        // Method 'offlineAvatarPreview'
        QtMocHelpers::MethodData<QString(const QString &)>(44, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 29 },
        }}),
        // Method 'switchAccount'
        QtMocHelpers::MethodData<void(const QString &)>(45, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 37 },
        }}),
        // Method 'switchAccountFast'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &, const QString &)>(46, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 37 }, { QMetaType::QString, 29 }, { QMetaType::QString, 47 }, { QMetaType::QString, 48 },
        }}),
        // Method 'switchAccountByIdentifier'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &, const QString &)>(49, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 50 }, { QMetaType::QString, 29 }, { QMetaType::QString, 47 }, { QMetaType::QString, 48 },
        }}),
        // Method 'deleteAccount'
        QtMocHelpers::MethodData<void(const QString &)>(51, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 37 },
        }}),
        // Method 'startRefreshAccount'
        QtMocHelpers::MethodData<void(const QString &)>(52, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 37 },
        }}),
        // Method 'startUploadSkin'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(53, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 37 }, { QMetaType::QString, 54 }, { QMetaType::QString, 55 },
        }}),
        // Method 'startMigrateAccount'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(56, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 37 }, { QMetaType::QString, 57 },
        }}),
        // Method 'startCleanupAvatarCache'
        QtMocHelpers::MethodData<void()>(58, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'pollRefreshAccountTask'
        QtMocHelpers::MethodData<QString()>(59, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'refreshDownloadCatalog'
        QtMocHelpers::MethodData<QString(const QString &)>(60, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 61 },
        }}),
        // Method 'refreshDownloadCatalog'
        QtMocHelpers::MethodData<QString()>(60, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::QString),
        // Method 'startRefreshDownloadCatalog'
        QtMocHelpers::MethodData<void(const QString &)>(62, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 61 },
        }}),
        // Method 'startRefreshDownloadCatalog'
        QtMocHelpers::MethodData<void()>(62, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'pollDownloadCatalogTask'
        QtMocHelpers::MethodData<QString()>(63, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'startFetchInstallerMetadata'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(64, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 61 }, { QMetaType::QString, 65 },
        }}),
        // Method 'startFetchLoaderMetadata'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(66, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 61 }, { QMetaType::QString, 65 }, { QMetaType::QString, 67 },
        }}),
        // Method 'pollInstallerMetadataTask'
        QtMocHelpers::MethodData<QString()>(68, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'installGameVersion'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &, const QString &)>(69, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 61 }, { QMetaType::QString, 65 }, { QMetaType::QString, 67 }, { QMetaType::QString, 70 },
        }}),
        // Method 'pollDownloadTask'
        QtMocHelpers::MethodData<QString()>(71, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'cancelDownloadTask'
        QtMocHelpers::MethodData<void()>(72, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'refreshInstalledVersions'
        QtMocHelpers::MethodData<QString()>(73, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'refreshInstances'
        QtMocHelpers::MethodData<QString()>(74, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'refreshInstanceDetail'
        QtMocHelpers::MethodData<QString(const QString &)>(75, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'refreshInstanceMods'
        QtMocHelpers::MethodData<QString(const QString &)>(77, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'setInstanceModEnabled'
        QtMocHelpers::MethodData<void(const QString &, const QString &, bool)>(78, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 79 }, { QMetaType::Bool, 80 },
        }}),
        // Method 'deleteInstanceMod'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(81, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 79 },
        }}),
        // Method 'refreshInstanceResourcepacks'
        QtMocHelpers::MethodData<QString(const QString &)>(82, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'setInstanceResourcepackEnabled'
        QtMocHelpers::MethodData<void(const QString &, const QString &, bool)>(83, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 79 }, { QMetaType::Bool, 80 },
        }}),
        // Method 'deleteInstanceResourcepack'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(84, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 79 },
        }}),
        // Method 'refreshInstanceWorlds'
        QtMocHelpers::MethodData<QString(const QString &)>(85, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'deleteInstanceWorld'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(86, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 79 },
        }}),
        // Method 'selectInstance'
        QtMocHelpers::MethodData<void(const QString &)>(87, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'renameInstance'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(88, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 89 },
        }}),
        // Method 'duplicateInstance'
        QtMocHelpers::MethodData<void(const QString &, const QString &, bool)>(90, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 89 }, { QMetaType::Bool, 91 },
        }}),
        // Method 'deleteInstance'
        QtMocHelpers::MethodData<QString(const QString &)>(92, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'openInstanceFolder'
        QtMocHelpers::MethodData<QString(const QString &, const QString &)>(93, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 94 },
        }}),
        // Method 'openInstanceFolder'
        QtMocHelpers::MethodData<QString(const QString &)>(93, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'generateInstanceLaunchCommand'
        QtMocHelpers::MethodData<QString(const QString &)>(95, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'cleanInstance'
        QtMocHelpers::MethodData<QString(const QString &)>(96, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'clearInstanceAssets'
        QtMocHelpers::MethodData<QString(const QString &)>(97, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'clearInstanceLibraries'
        QtMocHelpers::MethodData<QString(const QString &)>(98, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'saveInstanceSettings'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(99, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 }, { QMetaType::QString, 100 },
        }}),
        // Method 'selectGameVersion'
        QtMocHelpers::MethodData<void(const QString &)>(101, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'deleteGameVersion'
        QtMocHelpers::MethodData<void(const QString &)>(102, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'launchSelectedVersion'
        QtMocHelpers::MethodData<void()>(103, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'startLaunchSelectedVersion'
        QtMocHelpers::MethodData<void(const QString &)>(104, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 105 },
        }}),
        // Method 'cancelLaunchTask'
        QtMocHelpers::MethodData<void()>(106, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'pollLaunchTask'
        QtMocHelpers::MethodData<QString()>(107, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'refreshLauncherSettings'
        QtMocHelpers::MethodData<QString()>(108, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'refreshSystemMemory'
        QtMocHelpers::MethodData<QString()>(109, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'refreshAppearanceOptions'
        QtMocHelpers::MethodData<QString()>(110, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'exportLauncherThemePack'
        QtMocHelpers::MethodData<QString()>(111, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'updateLauncherSetting'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(112, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 113 }, { QMetaType::QString, 114 },
        }}),
        // Method 'generateLaunchCommand'
        QtMocHelpers::MethodData<QString(const QString &)>(115, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 76 },
        }}),
        // Method 'openFolder'
        QtMocHelpers::MethodData<void(const QString &)>(116, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 117 },
        }}),
        // Method 'openLauncherSpecialFolder'
        QtMocHelpers::MethodData<QString(const QString &)>(118, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 119 },
        }}),
        // Method 'exportLauncherDiagnostics'
        QtMocHelpers::MethodData<QString()>(120, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'resetLauncherSettings'
        QtMocHelpers::MethodData<QString()>(121, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'clearLauncherCache'
        QtMocHelpers::MethodData<QString()>(122, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'openUrl'
        QtMocHelpers::MethodData<void(const QString &)>(123, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 42 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'output'
        QtMocHelpers::PropertyData<QString>(124, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'currentAccountName'
        QtMocHelpers::PropertyData<QString>(125, QMetaType::QString, QMC::DefaultPropertyFlags, 1),
        // property 'currentAccountKind'
        QtMocHelpers::PropertyData<QString>(126, QMetaType::QString, QMC::DefaultPropertyFlags, 2),
        // property 'currentAccountAvatarUrl'
        QtMocHelpers::PropertyData<QString>(127, QMetaType::QString, QMC::DefaultPropertyFlags, 3),
        // property 'accountsJson'
        QtMocHelpers::PropertyData<QString>(128, QMetaType::QString, QMC::DefaultPropertyFlags, 4),
        // property 'pendingYggdrasilProfilesJson'
        QtMocHelpers::PropertyData<QString>(129, QMetaType::QString, QMC::DefaultPropertyFlags, 5),
        // property 'authServersJson'
        QtMocHelpers::PropertyData<QString>(130, QMetaType::QString, QMC::DefaultPropertyFlags, 6),
        // property 'downloadCatalogJson'
        QtMocHelpers::PropertyData<QString>(131, QMetaType::QString, QMC::DefaultPropertyFlags, 7),
        // property 'downloadTaskJson'
        QtMocHelpers::PropertyData<QString>(132, QMetaType::QString, QMC::DefaultPropertyFlags, 8),
        // property 'installedVersionsJson'
        QtMocHelpers::PropertyData<QString>(133, QMetaType::QString, QMC::DefaultPropertyFlags, 9),
        // property 'instanceListJson'
        QtMocHelpers::PropertyData<QString>(134, QMetaType::QString, QMC::DefaultPropertyFlags, 10),
        // property 'instanceDetailJson'
        QtMocHelpers::PropertyData<QString>(135, QMetaType::QString, QMC::DefaultPropertyFlags, 11),
        // property 'selectedGameVersion'
        QtMocHelpers::PropertyData<QString>(136, QMetaType::QString, QMC::DefaultPropertyFlags, 12),
        // property 'launchTaskJson'
        QtMocHelpers::PropertyData<QString>(137, QMetaType::QString, QMC::DefaultPropertyFlags, 13),
        // property 'launcherSettingsJson'
        QtMocHelpers::PropertyData<QString>(138, QMetaType::QString, QMC::DefaultPropertyFlags, 14),
        // property 'detectedJavaJson'
        QtMocHelpers::PropertyData<QString>(139, QMetaType::QString, QMC::DefaultPropertyFlags, 15),
        // property 'instanceModsJson'
        QtMocHelpers::PropertyData<QString>(140, QMetaType::QString, QMC::DefaultPropertyFlags, 16),
        // property 'instanceResourcepacksJson'
        QtMocHelpers::PropertyData<QString>(141, QMetaType::QString, QMC::DefaultPropertyFlags, 17),
        // property 'instanceWorldsJson'
        QtMocHelpers::PropertyData<QString>(142, QMetaType::QString, QMC::DefaultPropertyFlags, 18),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<LauncherBackend, qt_meta_tag_ZN15LauncherBackendE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject LauncherBackend::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15LauncherBackendE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15LauncherBackendE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN15LauncherBackendE_t>.metaTypes,
    nullptr
} };

void LauncherBackend::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<LauncherBackend *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->outputChanged(); break;
        case 1: _t->currentAccountNameChanged(); break;
        case 2: _t->currentAccountKindChanged(); break;
        case 3: _t->currentAccountAvatarUrlChanged(); break;
        case 4: _t->accountsJsonChanged(); break;
        case 5: _t->pendingYggdrasilProfilesJsonChanged(); break;
        case 6: _t->authServersJsonChanged(); break;
        case 7: _t->downloadCatalogJsonChanged(); break;
        case 8: _t->downloadTaskJsonChanged(); break;
        case 9: _t->installedVersionsJsonChanged(); break;
        case 10: _t->instanceListJsonChanged(); break;
        case 11: _t->instanceDetailJsonChanged(); break;
        case 12: _t->selectedGameVersionChanged(); break;
        case 13: _t->launchTaskJsonChanged(); break;
        case 14: _t->launcherSettingsJsonChanged(); break;
        case 15: _t->detectedJavaJsonChanged(); break;
        case 16: _t->instanceModsJsonChanged(); break;
        case 17: _t->instanceResourcepacksJsonChanged(); break;
        case 18: _t->instanceWorldsJsonChanged(); break;
        case 19: _t->detectJava(); break;
        case 20: _t->startDetectJava(); break;
        case 21: { QString _r = _t->pollJavaTask();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 22: _t->downloadJava((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 23: _t->loginOffline((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 24: _t->loginYggdrasil((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 25: { QString _r = _t->pollYggdrasilLoginTask();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 26: _t->loginMicrosoftBrowser((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 27: _t->selectYggdrasilProfile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 28: { QString _r = _t->refreshAccounts();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 29: { QString _r = _t->refreshAuthServers();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 30: { QString _r = _t->addAuthServer((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 31: { QString _r = _t->deleteAuthServer((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 32: { QString _r = _t->offlineAvatarPreview((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 33: _t->switchAccount((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 34: _t->switchAccountFast((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4]))); break;
        case 35: _t->switchAccountByIdentifier((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4]))); break;
        case 36: _t->deleteAccount((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 37: _t->startRefreshAccount((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 38: _t->startUploadSkin((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 39: _t->startMigrateAccount((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 40: _t->startCleanupAvatarCache(); break;
        case 41: { QString _r = _t->pollRefreshAccountTask();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 42: { QString _r = _t->refreshDownloadCatalog((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 43: { QString _r = _t->refreshDownloadCatalog();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 44: _t->startRefreshDownloadCatalog((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 45: _t->startRefreshDownloadCatalog(); break;
        case 46: { QString _r = _t->pollDownloadCatalogTask();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 47: _t->startFetchInstallerMetadata((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 48: _t->startFetchLoaderMetadata((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 49: { QString _r = _t->pollInstallerMetadataTask();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 50: _t->installGameVersion((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4]))); break;
        case 51: { QString _r = _t->pollDownloadTask();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 52: _t->cancelDownloadTask(); break;
        case 53: { QString _r = _t->refreshInstalledVersions();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 54: { QString _r = _t->refreshInstances();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 55: { QString _r = _t->refreshInstanceDetail((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 56: { QString _r = _t->refreshInstanceMods((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 57: _t->setInstanceModEnabled((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3]))); break;
        case 58: _t->deleteInstanceMod((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 59: { QString _r = _t->refreshInstanceResourcepacks((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 60: _t->setInstanceResourcepackEnabled((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3]))); break;
        case 61: _t->deleteInstanceResourcepack((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 62: { QString _r = _t->refreshInstanceWorlds((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 63: _t->deleteInstanceWorld((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 64: _t->selectInstance((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 65: _t->renameInstance((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 66: _t->duplicateInstance((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[3]))); break;
        case 67: { QString _r = _t->deleteInstance((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 68: { QString _r = _t->openInstanceFolder((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 69: { QString _r = _t->openInstanceFolder((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 70: { QString _r = _t->generateInstanceLaunchCommand((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 71: { QString _r = _t->cleanInstance((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 72: { QString _r = _t->clearInstanceAssets((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 73: { QString _r = _t->clearInstanceLibraries((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 74: _t->saveInstanceSettings((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 75: _t->selectGameVersion((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 76: _t->deleteGameVersion((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 77: _t->launchSelectedVersion(); break;
        case 78: _t->startLaunchSelectedVersion((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 79: _t->cancelLaunchTask(); break;
        case 80: { QString _r = _t->pollLaunchTask();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 81: { QString _r = _t->refreshLauncherSettings();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 82: { QString _r = _t->refreshSystemMemory();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 83: { QString _r = _t->refreshAppearanceOptions();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 84: { QString _r = _t->exportLauncherThemePack();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 85: _t->updateLauncherSetting((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 86: { QString _r = _t->generateLaunchCommand((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 87: _t->openFolder((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 88: { QString _r = _t->openLauncherSpecialFolder((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 89: { QString _r = _t->exportLauncherDiagnostics();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 90: { QString _r = _t->resetLauncherSettings();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 91: { QString _r = _t->clearLauncherCache();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 92: _t->openUrl((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::outputChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::currentAccountNameChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::currentAccountKindChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::currentAccountAvatarUrlChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::accountsJsonChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::pendingYggdrasilProfilesJsonChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::authServersJsonChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::downloadCatalogJsonChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::downloadTaskJsonChanged, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::installedVersionsJsonChanged, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::instanceListJsonChanged, 10))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::instanceDetailJsonChanged, 11))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::selectedGameVersionChanged, 12))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::launchTaskJsonChanged, 13))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::launcherSettingsJsonChanged, 14))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::detectedJavaJsonChanged, 15))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::instanceModsJsonChanged, 16))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::instanceResourcepacksJsonChanged, 17))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherBackend::*)()>(_a, &LauncherBackend::instanceWorldsJsonChanged, 18))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->output(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->currentAccountName(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->currentAccountKind(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->currentAccountAvatarUrl(); break;
        case 4: *reinterpret_cast<QString*>(_v) = _t->accountsJson(); break;
        case 5: *reinterpret_cast<QString*>(_v) = _t->pendingYggdrasilProfilesJson(); break;
        case 6: *reinterpret_cast<QString*>(_v) = _t->authServersJson(); break;
        case 7: *reinterpret_cast<QString*>(_v) = _t->downloadCatalogJson(); break;
        case 8: *reinterpret_cast<QString*>(_v) = _t->downloadTaskJson(); break;
        case 9: *reinterpret_cast<QString*>(_v) = _t->installedVersionsJson(); break;
        case 10: *reinterpret_cast<QString*>(_v) = _t->instanceListJson(); break;
        case 11: *reinterpret_cast<QString*>(_v) = _t->instanceDetailJson(); break;
        case 12: *reinterpret_cast<QString*>(_v) = _t->selectedGameVersion(); break;
        case 13: *reinterpret_cast<QString*>(_v) = _t->launchTaskJson(); break;
        case 14: *reinterpret_cast<QString*>(_v) = _t->launcherSettingsJson(); break;
        case 15: *reinterpret_cast<QString*>(_v) = _t->detectedJavaJson(); break;
        case 16: *reinterpret_cast<QString*>(_v) = _t->instanceModsJson(); break;
        case 17: *reinterpret_cast<QString*>(_v) = _t->instanceResourcepacksJson(); break;
        case 18: *reinterpret_cast<QString*>(_v) = _t->instanceWorldsJson(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setOutput(*reinterpret_cast<QString*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *LauncherBackend::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *LauncherBackend::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15LauncherBackendE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int LauncherBackend::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 93)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 93;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 93)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 93;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 19;
    }
    return _id;
}

// SIGNAL 0
void LauncherBackend::outputChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void LauncherBackend::currentAccountNameChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void LauncherBackend::currentAccountKindChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void LauncherBackend::currentAccountAvatarUrlChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void LauncherBackend::accountsJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void LauncherBackend::pendingYggdrasilProfilesJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void LauncherBackend::authServersJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void LauncherBackend::downloadCatalogJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void LauncherBackend::downloadTaskJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void LauncherBackend::installedVersionsJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void LauncherBackend::instanceListJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}

// SIGNAL 11
void LauncherBackend::instanceDetailJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 11, nullptr);
}

// SIGNAL 12
void LauncherBackend::selectedGameVersionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 12, nullptr);
}

// SIGNAL 13
void LauncherBackend::launchTaskJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 13, nullptr);
}

// SIGNAL 14
void LauncherBackend::launcherSettingsJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 14, nullptr);
}

// SIGNAL 15
void LauncherBackend::detectedJavaJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 15, nullptr);
}

// SIGNAL 16
void LauncherBackend::instanceModsJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 16, nullptr);
}

// SIGNAL 17
void LauncherBackend::instanceResourcepacksJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 17, nullptr);
}

// SIGNAL 18
void LauncherBackend::instanceWorldsJsonChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 18, nullptr);
}
QT_WARNING_POP
