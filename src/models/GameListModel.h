#pragma once
#include <QAbstractListModel>
#include <QJsonArray>
#include <QString>

class GameListModel : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(int count READ count NOTIFY countChanged)
  Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
  Q_PROPERTY(bool isEmpty READ isEmpty NOTIFY isEmptyChanged)

public:
  explicit GameListModel(QObject *parent = nullptr);
  enum Roles {
    InstanceIdRole = Qt::UserRole + 1,
    TitleRole,
    SubtitleRole,
    TagRole,
    IconNameRole,
    SelectedRole,
    CanUpdateRole,
    GameVersionRole,
    LoaderSummaryRole
  };
  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index, int role) const override;
  QHash<int, QByteArray> roleNames() const override;
  int count() const { return m_rows.size(); }
  bool loading() const { return m_loading; }
  bool isEmpty() const { return m_rows.isEmpty(); }

  Q_INVOKABLE void refresh();
  Q_INVOKABLE void setSearch(const QString &text);
  Q_INVOKABLE void selectInstance(const QString &id);
  Q_INVOKABLE QString renameInstance(const QString &id, const QString &newName);
  Q_INVOKABLE QString duplicateInstance(const QString &id,
                                        const QString &newName, bool copySaves);
  Q_INVOKABLE QString removeInstance(const QString &id);
  Q_INVOKABLE QString openFolder(const QString &id);

signals:
  void countChanged();
  void loadingChanged();
  void isEmptyChanged();

private:
  void setRows(const QJsonArray &rows);
  QJsonArray filtered(const QJsonArray &rows) const;
  QJsonArray m_allRows;
  QJsonArray m_rows;
  QString m_search;
  QString m_selectedId;
  bool m_loading = false;
};
