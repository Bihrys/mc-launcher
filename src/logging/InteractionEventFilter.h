#pragma once

#include <QObject>
#include <QPointF>

class QEvent;
class QQuickItem;
class QQuickWindow;

class InteractionEventFilter : public QObject {
    Q_OBJECT
public:
    explicit InteractionEventFilter(QObject *parent = nullptr);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    QString describeObject(QObject *object) const;
    QString describeQuickTarget(const QPointF &globalPosition) const;
    QQuickItem *deepestChildAt(QQuickItem *root, const QPointF &pointInRoot) const;
    static QString mouseButtonName(int button);
    static QString modifiersName(int modifiers);

    qint64 m_lastDragLogMs = 0;
};
