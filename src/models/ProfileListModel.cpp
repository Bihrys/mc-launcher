#include "models/ProfileListModel.h"

#include "game/InstanceService.h"

#include <QJsonObject>

ProfileListModel::ProfileListModel(QObject *parent) : QAbstractListModel(parent) {}
int ProfileListModel::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_rows.size(); }
QVariant ProfileListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) return {};
    auto row = m_rows.at(index.row()).toObject();
    switch (role) {
    case ProfileIdRole: return row.value("id").toString();
    case ProfileNameRole: return row.value("name").toString();
    case ProfilePathRole: return row.value("path").toString();
    case ProfileSelectedRole: return row.value("selected").toBool();
    default: return {};
    }
}
QHash<int, QByteArray> ProfileListModel::roleNames() const { return {{ProfileIdRole, "profileId"}, {ProfileNameRole, "profileName"}, {ProfilePathRole, "profilePath"}, {ProfileSelectedRole, "profileSelected"}}; }
void ProfileListModel::refresh() {
    InstanceService s;
    auto rows = s.list().value("profiles").toArray();
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
}
