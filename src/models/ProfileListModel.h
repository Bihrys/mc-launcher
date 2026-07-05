#pragma once

#include <QAbstractListModel>
#include <QJsonArray>

class ProfileListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    explicit ProfileListModel(QObject *parent = nullptr);
    enum Roles { ProfileIdRole = Qt::UserRole + 1, ProfileNameRole, ProfilePathRole, ProfileSelectedRole };
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return m_rows.size(); }
    Q_INVOKABLE void refresh();
signals:
    void countChanged();
private:
    QJsonArray m_rows;
};
