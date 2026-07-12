#pragma once
#include <QByteArray>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QTcpServer>
#include <QTimer>

#include <atomic>
#include <functional>
#include <memory>

#include "account/AccountService.h"
#include "download/DownloadService.h"
#include "game/InstanceService.h"
#include "java/JavaService.h"
#include "launch/LaunchService.h"
#include "settings/LauncherSettings.h"

class LauncherBackend : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString output READ output WRITE setOutput NOTIFY outputChanged)
  Q_PROPERTY(QString currentAccountName READ currentAccountName NOTIFY
                 currentAccountNameChanged)
  Q_PROPERTY(QString currentAccountKind READ currentAccountKind NOTIFY
                 currentAccountKindChanged)
  Q_PROPERTY(QString currentAccountAvatarUrl READ currentAccountAvatarUrl NOTIFY
                 currentAccountAvatarUrlChanged)
  Q_PROPERTY(QString accountsJson READ accountsJson NOTIFY accountsJsonChanged)
  Q_PROPERTY(
      QString pendingYggdrasilProfilesJson READ pendingYggdrasilProfilesJson
          NOTIFY pendingYggdrasilProfilesJsonChanged)
  Q_PROPERTY(QString microsoftLoginTaskJson READ microsoftLoginTaskJson NOTIFY
                 microsoftLoginTaskJsonChanged)
  Q_PROPERTY(QString authServersJson READ authServersJson NOTIFY
                 authServersJsonChanged)
  Q_PROPERTY(QString downloadCatalogJson READ downloadCatalogJson NOTIFY
                 downloadCatalogJsonChanged)
  Q_PROPERTY(QString downloadTaskJson READ downloadTaskJson NOTIFY
                 downloadTaskJsonChanged)
  Q_PROPERTY(QString installedVersionsJson READ installedVersionsJson NOTIFY
                 installedVersionsJsonChanged)
  Q_PROPERTY(QString instanceListJson READ instanceListJson NOTIFY
                 instanceListJsonChanged)
  Q_PROPERTY(QString instanceDetailJson READ instanceDetailJson NOTIFY
                 instanceDetailJsonChanged)
  Q_PROPERTY(QString selectedGameVersion READ selectedGameVersion NOTIFY
                 selectedGameVersionChanged)
  Q_PROPERTY(
      QString launchTaskJson READ launchTaskJson NOTIFY launchTaskJsonChanged)
  Q_PROPERTY(QString launcherSettingsJson READ launcherSettingsJson NOTIFY
                 launcherSettingsJsonChanged)
  Q_PROPERTY(QString detectedJavaJson READ detectedJavaJson NOTIFY
                 detectedJavaJsonChanged)
  Q_PROPERTY(QString instanceModsJson READ instanceModsJson NOTIFY
                 instanceModsJsonChanged)
  Q_PROPERTY(QString instanceResourcepacksJson READ instanceResourcepacksJson
                 NOTIFY instanceResourcepacksJsonChanged)
  Q_PROPERTY(QString instanceWorldsJson READ instanceWorldsJson NOTIFY
                 instanceWorldsJsonChanged)
  Q_PROPERTY(QString logFilePath READ logFilePath CONSTANT)
  Q_PROPERTY(QString sessionLogFilePath READ sessionLogFilePath CONSTANT)
  Q_PROPERTY(QString crashLogFilePath READ crashLogFilePath CONSTANT)

public:
  explicit LauncherBackend(QObject *parent = nullptr);

  QString output() const { return m_output; }
  void setOutput(const QString &value);
  QString currentAccountName() const { return m_currentAccountName; }
  QString currentAccountKind() const { return m_currentAccountKind; }
  QString currentAccountAvatarUrl() const { return m_currentAccountAvatarUrl; }
  QString accountsJson() const { return m_accountsJson; }
  QString pendingYggdrasilProfilesJson() const {
    return m_pendingYggdrasilProfilesJson;
  }
  QString authServersJson() const { return m_authServersJson; }
  QString microsoftLoginTaskJson() const { return m_microsoftLoginTaskJson; }
  QString downloadCatalogJson() const { return m_downloadCatalogJson; }
  QString downloadTaskJson() const { return m_downloadTaskJson; }
  QString installedVersionsJson() const { return m_installedVersionsJson; }
  QString instanceListJson() const { return m_instanceListJson; }
  QString instanceDetailJson() const { return m_instanceDetailJson; }
  QString selectedGameVersion() const { return m_selectedGameVersion; }
  QString launchTaskJson() const { return m_launchTaskJson; }
  QString launcherSettingsJson() const { return m_launcherSettingsJson; }
  QString detectedJavaJson() const { return m_detectedJavaJson; }
  QString instanceModsJson() const { return m_instanceModsJson; }
  QString instanceResourcepacksJson() const {
    return m_instanceResourcepacksJson;
  }
  QString instanceWorldsJson() const { return m_instanceWorldsJson; }
  QString logFilePath() const;
  QString sessionLogFilePath() const;
  QString crashLogFilePath() const;

  Q_INVOKABLE void detectJava();
  Q_INVOKABLE void startDetectJava();
  Q_INVOKABLE QString pollJavaTask();
  Q_INVOKABLE void downloadJava(const QString &distribution,
                                const QString &major,
                                const QString &packageType);
  Q_INVOKABLE void cancelJavaTask();
  Q_INVOKABLE void addJavaPath(const QString &path);
  Q_INVOKABLE void installJavaArchive(const QString &archivePath);
  Q_INVOKABLE void disableJava(const QString &path);
  Q_INVOKABLE void restoreJava(const QString &path);
  Q_INVOKABLE void removeDisabledJava(const QString &path);
  Q_INVOKABLE void uninstallManagedJava(const QString &path);
  Q_INVOKABLE void revealJava(const QString &path);

  Q_INVOKABLE void loginOffline(const QString &username);
  Q_INVOKABLE void loginOfflineWithUuid(const QString &username,
                                        const QString &uuid);
  Q_INVOKABLE void loginYggdrasil(const QString &serverUrl,
                                  const QString &username,
                                  const QString &password);
  Q_INVOKABLE QString pollYggdrasilLoginTask();
  Q_INVOKABLE QString microsoftClientConfiguration();
  Q_INVOKABLE void loginMicrosoftBrowser();
  Q_INVOKABLE void loginMicrosoftDeviceCode();
  Q_INVOKABLE void cancelMicrosoftLogin();
  Q_INVOKABLE QString pollMicrosoftLoginTask();
  Q_INVOKABLE QString qrCodeDataUrl(const QString &text);
  Q_INVOKABLE void selectYggdrasilProfile(const QString &index);
  Q_INVOKABLE QString refreshAccounts();
  Q_INVOKABLE QString refreshAuthServers();
  Q_INVOKABLE QString probeAuthServer(const QString &url);
  Q_INVOKABLE void startProbeAuthServer(const QString &url);
  Q_INVOKABLE QString pollAuthServerProbeTask();
  Q_INVOKABLE QString addAuthServer(const QString &name, const QString &url);
  Q_INVOKABLE QString deleteAuthServer(const QString &index);
  Q_INVOKABLE QString offlineAvatarPreview(const QString &username);
  Q_INVOKABLE QString setOfflineSkin(const QString &index, const QString &fileUrl,
                                     const QString &capeFileUrl, const QString &model,
                                     const QString &cslApi,
                                     const QString &skinType = QStringLiteral("default"));
  Q_INVOKABLE void switchAccount(const QString &index);
  Q_INVOKABLE void switchAccountFast(const QString &index,
                                     const QString &username,
                                     const QString &displayKind,
                                     const QString &avatarUrl);
  Q_INVOKABLE void switchAccountByIdentifier(const QString &identifier,
                                             const QString &username,
                                             const QString &displayKind,
                                             const QString &avatarUrl);
  Q_INVOKABLE void deleteAccount(const QString &index);
  Q_INVOKABLE void startRefreshAccount(const QString &index);
  Q_INVOKABLE void reauthenticateYggdrasil(const QString &index,
                                           const QString &password);
  Q_INVOKABLE void startUploadSkin(const QString &index, const QString &fileUrl,
                                   const QString &model);
  Q_INVOKABLE void startMigrateAccount(const QString &index,
                                       const QString &target);
  Q_INVOKABLE void startCleanupAvatarCache();
  Q_INVOKABLE QString pollRefreshAccountTask();

  Q_INVOKABLE QString refreshDownloadCatalog(const QString &source = QString());
  Q_INVOKABLE void
  startRefreshDownloadCatalog(const QString &source = QString());
  Q_INVOKABLE QString pollDownloadCatalogTask();
  Q_INVOKABLE void startFetchInstallerMetadata(const QString &source,
                                               const QString &gameVersion);
  Q_INVOKABLE void startFetchLoaderMetadata(const QString &source,
                                            const QString &gameVersion,
                                            const QString &loaderKind);
  Q_INVOKABLE QString pollInstallerMetadataTask();
  Q_INVOKABLE void installGameVersion(const QString &source,
                                      const QString &gameVersion,
                                      const QString &instanceName,
                                      const QString &loaderKind,
                                      const QString &loaderVersion,
                                      const QString &addonsJson);
  Q_INVOKABLE QString pollDownloadTask();
  Q_INVOKABLE void cancelDownloadTask();
  Q_INVOKABLE QString refreshInstalledVersions();

  Q_INVOKABLE QString refreshInstances();
  Q_INVOKABLE QString refreshInstanceDetail(const QString &versionId);
  Q_INVOKABLE QString refreshInstanceMods(const QString &versionId);
  Q_INVOKABLE void setInstanceModEnabled(const QString &versionId,
                                         const QString &fileName, bool enabled);
  Q_INVOKABLE void deleteInstanceMod(const QString &versionId,
                                     const QString &fileName);
  Q_INVOKABLE QString refreshInstanceResourcepacks(const QString &versionId);
  Q_INVOKABLE void setInstanceResourcepackEnabled(const QString &versionId,
                                                  const QString &fileName,
                                                  bool enabled);
  Q_INVOKABLE void deleteInstanceResourcepack(const QString &versionId,
                                              const QString &fileName);
  Q_INVOKABLE QString refreshInstanceWorlds(const QString &versionId);
  Q_INVOKABLE void deleteInstanceWorld(const QString &versionId,
                                       const QString &fileName);
  Q_INVOKABLE void selectInstance(const QString &versionId);
  Q_INVOKABLE void renameInstance(const QString &versionId,
                                  const QString &newName);
  Q_INVOKABLE void duplicateInstance(const QString &versionId,
                                     const QString &newName, bool copySaves);
  Q_INVOKABLE QString deleteInstance(const QString &versionId);
  Q_INVOKABLE QString openInstanceFolder(const QString &versionId,
                                         const QString &folderKey = QString());
  Q_INVOKABLE QString generateInstanceLaunchCommand(const QString &versionId);
  Q_INVOKABLE QString cleanInstance(const QString &versionId);
  Q_INVOKABLE QString clearInstanceAssets(const QString &versionId);
  Q_INVOKABLE QString clearInstanceLibraries(const QString &versionId);
  Q_INVOKABLE void saveInstanceSettings(const QString &versionId,
                                        const QString &settingsJson);

  Q_INVOKABLE void selectGameVersion(const QString &versionId);
  Q_INVOKABLE void deleteGameVersion(const QString &versionId);
  Q_INVOKABLE void launchSelectedVersion();
  Q_INVOKABLE void startLaunchSelectedVersion(const QString &visibility);
  Q_INVOKABLE void cancelLaunchTask();
  Q_INVOKABLE QString pollLaunchTask();

  Q_INVOKABLE QString refreshLauncherSettings();
  Q_INVOKABLE QString refreshSystemMemory();
  Q_INVOKABLE QString refreshAppearanceOptions();
  Q_INVOKABLE QString exportLauncherThemePack();
  Q_INVOKABLE void updateLauncherSetting(const QString &key,
                                         const QString &value);
  Q_INVOKABLE QString generateLaunchCommand(const QString &versionId);
  Q_INVOKABLE void openFolder(const QString &path);
  Q_INVOKABLE void openFile(const QString &path);
  Q_INVOKABLE QString exportGameCrashLog(const QString &sourcePath);
  Q_INVOKABLE QString openLauncherSpecialFolder(const QString &kind);
  Q_INVOKABLE QString exportLauncherDiagnostics();
  Q_INVOKABLE QString resetLauncherSettings();
  Q_INVOKABLE QString clearLauncherCache();
  Q_INVOKABLE void openUrl(const QString &url);
  Q_INVOKABLE void logUiAction(const QString &category, const QString &action,
                               const QString &detailsJson = QString());
  Q_INVOKABLE QString flushLogs();

signals:
  void outputChanged();
  void currentAccountNameChanged();
  void currentAccountKindChanged();
  void currentAccountAvatarUrlChanged();
  void accountsJsonChanged();
  void pendingYggdrasilProfilesJsonChanged();
  void microsoftLoginTaskJsonChanged();
  void authServersJsonChanged();
  void downloadCatalogJsonChanged();
  void downloadTaskJsonChanged();
  void installedVersionsJsonChanged();
  void instanceListJsonChanged();
  void instanceDetailJsonChanged();
  void selectedGameVersionChanged();
  void launchTaskJsonChanged();
  void launcherSettingsJsonChanged();
  void detectedJavaJsonChanged();
  void instanceModsJsonChanged();
  void instanceResourcepacksJsonChanged();
  void instanceWorldsJsonChanged();

private:
  void setAccountsPayload(const QJsonObject &payload);
  void setCurrentAccountFromPayload(const QJsonObject &payload);
  void setString(QString &field, const QString &value,
                 void (LauncherBackend::*signal)());
  QString stringify(const QJsonObject &object) const;
  QString fieldName(const QString *field) const;
  QString summarizeFieldValue(const QString *field, const QString &value) const;
  void startJavaOperation(const QString &title,
                          const QString &message,
                          std::function<QJsonObject()> operation);
  void finishJavaOperation(const QJsonObject &result,
                           const QString &fallbackTitle);
  void handleMicrosoftCallback();
  void startMicrosoftAuthorizationExchange(const QString &code);
  void finishMicrosoftLogin(const QJsonObject &result, quint64 serial);
  void setMicrosoftLoginTask(const QJsonObject &task);
  void stopMicrosoftCallbackServer();

  LauncherSettings m_settings;
  AccountService m_accounts;
  InstanceService m_instances;
  DownloadService m_downloads;
  JavaService m_java;
  LaunchService m_launch;

  QString m_output;
  QString m_currentAccountName;
  QString m_currentAccountKind;
  QString m_currentAccountAvatarUrl;
  QString m_accountsJson;
  QString m_pendingYggdrasilProfilesJson;
  QString m_microsoftLoginTaskJson;
  QString m_authServersJson;
  QString m_downloadCatalogJson;
  QString m_downloadTaskJson;
  QString m_installedVersionsJson;
  QString m_instanceListJson;
  QString m_instanceDetailJson;
  QString m_selectedGameVersion;
  QString m_launchTaskJson;
  QString m_launcherSettingsJson;
  QString m_detectedJavaJson;
  QString m_instanceModsJson;
  QString m_instanceResourcepacksJson;
  QString m_instanceWorldsJson;
  QString m_catalogTaskJson;
  bool m_downloadFinishRefreshed = false;
  QString m_installerMetadataTaskJson;
  QString m_javaTaskJson;
  QString m_accountTaskJson;
  QString m_yggdrasilTaskJson;
  QString m_authServerProbeTaskJson;

  // HMCL-style asynchronous version-list tasks. A monotonically increasing
  // serial prevents an older network response from overwriting a newer refresh.
  quint64 m_catalogRequestSerial = 0;
  quint64 m_installerRequestSerial = 0;
  quint64 m_javaRequestSerial = 0;
  quint64 m_accountRequestSerial = 0;
  quint64 m_authServerProbeRequestSerial = 0;
  quint64 m_microsoftRequestSerial = 0;
  std::shared_ptr<std::atomic_bool> m_javaCancellation;
  std::shared_ptr<std::atomic_bool> m_microsoftCancellation;
  QTcpServer m_microsoftCallbackServer;
  QTimer m_microsoftCallbackTimeout;
  QString m_microsoftClientId;
  QString m_microsoftRedirectUri;
  QString m_microsoftState;
  QString m_microsoftCodeVerifier;
};
