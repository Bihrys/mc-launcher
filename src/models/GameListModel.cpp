#include "models/GameListModel.h"

#include "game/InstanceService.h"

#include <QJsonObject>
#include <QRegularExpression>

GameListModel::GameListModel(QObject *parent) : QAbstractListModel(parent) {}

int GameListModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_rows.size();
}

QVariant GameListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) return {};
    QJsonObject row = m_rows.at(index.row()).toObject();
    switch (role) {
    case InstanceIdRole: return row.value("id").toString();
    case TitleRole: return row.value("title").toString();
    case SubtitleRole: return row.value("subtitle").toString();
    case TagRole: return row.value("tag").toString();
    case IconNameRole: return row.value("iconName").toString();
    case SelectedRole: return row.value("selected").toBool();
    case CanUpdateRole: return row.value("canUpdate").toBool();
    case GameVersionRole: return row.value("gameVersion").toString();
    case LoaderSummaryRole: return row.value("loaderSummary").toString();
    default: return {};
    }
}

QHash<int, QByteArray> GameListModel::roleNames() const {
    return {{InstanceIdRole, "instanceId"}, {TitleRole, "title"}, {SubtitleRole, "subtitle"}, {TagRole, "tag"}, {IconNameRole, "iconName"}, {SelectedRole, "selected"}, {CanUpdateRole, "canUpdate"}, {GameVersionRole, "gameVersion"}, {LoaderSummaryRole, "loaderSummary"}};
}

QJsonArray GameListModel::filtered(const QJsonArray &rows) const {
    const QString text = m_search.trimmed();
    if (text.isEmpty()) return rows;

    const bool regexMode = text.startsWith(QStringLiteral("regex:"), Qt::CaseInsensitive);
    const QRegularExpression expression(
        regexMode ? text.mid(QStringLiteral("regex:").size())
                  : QRegularExpression::escape(text),
        QRegularExpression::CaseInsensitiveOption);

    QJsonArray out;
    if (!expression.isValid()) return out;
    for (const QJsonValue &value : rows) {
        const QJsonObject object = value.toObject();
        const QString corpus = object.value(QStringLiteral("id")).toString()
            + u' ' + object.value(QStringLiteral("title")).toString();
        if (expression.match(corpus).hasMatch()) out.append(object);
    }
    return out;
}

void GameListModel::setRows(const QJsonArray &rows) {
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
    emit isEmptyChanged();
}

void GameListModel::refresh() {
    InstanceService service;
    QJsonObject payload = service.list();
    m_allRows = payload.value("instances").toArray();
    m_selectedId = payload.value("selectedInstance").toString();
    setRows(filtered(m_allRows));
}

void GameListModel::setSearch(const QString &text) {
    m_search = text;
    setRows(filtered(m_allRows));
}

void GameListModel::selectInstance(const QString &id) {
    InstanceService service;
    const QJsonObject payload = service.select(id);
    m_allRows = payload.value(QStringLiteral("instances")).toArray();
    m_selectedId = payload.value(QStringLiteral("selectedInstance")).toString();
    setRows(filtered(m_allRows));
}

QString GameListModel::renameInstance(const QString &id, const QString &newName) {
    InstanceService s; QString msg = s.rename(id, newName).value("message").toString(); refresh(); return msg;
}
QString GameListModel::duplicateInstance(const QString &id, const QString &newName, bool copySaves) {
    InstanceService s; QString msg = s.duplicate(id, newName, copySaves).value("message").toString(); refresh(); return msg;
}
QString GameListModel::removeInstance(const QString &id) {
    InstanceService s; QString msg = s.remove(id).value("message").toString(); refresh(); return msg;
}
QString GameListModel::openFolder(const QString &id) {
    InstanceService s; return s.openFolder(id);
}
