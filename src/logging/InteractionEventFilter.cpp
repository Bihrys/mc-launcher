#include "logging/InteractionEventFilter.h"

#include "logging/AppLogger.h"

#include <QDateTime>
#include <QEvent>
#include <QFocusEvent>
#include <QGuiApplication>
#include <QInputMethodEvent>
#include <QJsonArray>
#include <QJsonObject>
#include <QKeyEvent>
#include <QKeySequence>
#include <QMouseEvent>
#include <QMoveEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QResizeEvent>
#include <QShortcutEvent>
#include <QStringList>
#include <QTouchEvent>
#include <QVariant>
#include <QWheelEvent>
#include <QWindow>

namespace {
QString className(QObject *object) {
    return object && object->metaObject()
        ? QString::fromLatin1(object->metaObject()->className())
        : QStringLiteral("<null>");
}

bool isTextInputLike(QObject *object) {
    const QString name = className(object).toLower();
    if (name.contains("textfield") || name.contains("textinput") ||
        name.contains("textarea") || name.contains("textedit")) {
        return true;
    }
    const QVariant echoMode = object ? object->property("echoMode") : QVariant();
    return echoMode.isValid();
}

QString safeProperty(QObject *object, const char *name) {
    if (!object) return {};
    const QVariant value = object->property(name);
    if (!value.isValid() || value.isNull()) return {};
    QString text = value.toString().trimmed();
    if (text.size() > 120) text = text.left(120) + QStringLiteral("…");
    return AppLogger::redactText(text);
}

QQuickWindow *windowAtGlobalPoint(const QPointF &globalPosition) {
    const QPoint point = globalPosition.toPoint();
    const auto windows = QGuiApplication::topLevelWindows();
    for (auto it = windows.crbegin(); it != windows.crend(); ++it) {
        QWindow *window = *it;
        if (!window || !window->isVisible()) continue;
        if (!window->geometry().contains(point)) continue;
        if (auto *quickWindow = qobject_cast<QQuickWindow *>(window)) return quickWindow;
    }
    return qobject_cast<QQuickWindow *>(QGuiApplication::focusWindow());
}
} // namespace

InteractionEventFilter::InteractionEventFilter(QObject *parent)
    : QObject(parent) {}

bool InteractionEventFilter::eventFilter(QObject *watched, QEvent *event) {
    if (!event) return QObject::eventFilter(watched, event);

    switch (event->type()) {
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
    case QEvent::MouseButtonDblClick: {
        auto *mouse = static_cast<QMouseEvent *>(event);
        const QString phase = event->type() == QEvent::MouseButtonPress
            ? "press" : event->type() == QEvent::MouseButtonRelease ? "release" : "double_click";
        AppLogger::info("ui.pointer", phase, QString(), {
            {"button", mouseButtonName(static_cast<int>(mouse->button()))},
            {"buttons", static_cast<int>(mouse->buttons())},
            {"modifiers", modifiersName(static_cast<int>(mouse->modifiers()))},
            {"globalX", mouse->globalPosition().x()},
            {"globalY", mouse->globalPosition().y()},
            {"localX", mouse->position().x()},
            {"localY", mouse->position().y()},
            {"source", static_cast<int>(mouse->source())},
            {"receiver", describeObject(watched)},
            {"target", describeQuickTarget(mouse->globalPosition())}
        });
        break;
    }
    case QEvent::MouseMove: {
        auto *mouse = static_cast<QMouseEvent *>(event);
        if (mouse->buttons() == Qt::NoButton) break;
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        if (now - m_lastDragLogMs < 50) break;
        m_lastDragLogMs = now;
        AppLogger::debug("ui.pointer", "drag_move", QString(), {
            {"buttons", static_cast<int>(mouse->buttons())},
            {"globalX", mouse->globalPosition().x()},
            {"globalY", mouse->globalPosition().y()},
            {"target", describeQuickTarget(mouse->globalPosition())}
        });
        break;
    }
    case QEvent::Wheel: {
        auto *wheel = static_cast<QWheelEvent *>(event);
        AppLogger::info("ui.pointer", "wheel", QString(), {
            {"angleDeltaX", wheel->angleDelta().x()},
            {"angleDeltaY", wheel->angleDelta().y()},
            {"pixelDeltaX", wheel->pixelDelta().x()},
            {"pixelDeltaY", wheel->pixelDelta().y()},
            {"globalX", wheel->globalPosition().x()},
            {"globalY", wheel->globalPosition().y()},
            {"modifiers", modifiersName(static_cast<int>(wheel->modifiers()))},
            {"target", describeQuickTarget(wheel->globalPosition())}
        });
        break;
    }
    case QEvent::KeyPress:
    case QEvent::KeyRelease: {
        auto *key = static_cast<QKeyEvent *>(event);
        if (key->isAutoRepeat() && event->type() == QEvent::KeyRelease) break;
        const int combined = key->key() | static_cast<int>(key->modifiers());
        AppLogger::info("ui.keyboard",
                        event->type() == QEvent::KeyPress ? "press" : "release",
                        QString(), {
            {"key", key->key()},
            {"keyName", QKeySequence(combined).toString(QKeySequence::PortableText)},
            {"modifiers", modifiersName(static_cast<int>(key->modifiers()))},
            {"autoRepeat", key->isAutoRepeat()},
            {"count", key->count()},
            {"focusObject", describeObject(QGuiApplication::focusObject())},
            {"textLength", key->text().size()}
        });
        break;
    }
    case QEvent::InputMethod: {
        auto *input = static_cast<QInputMethodEvent *>(event);
        AppLogger::debug("ui.input", "input_method", QString(), {
            {"commitLength", input->commitString().size()},
            {"preeditLength", input->preeditString().size()},
            {"replacementStart", input->replacementStart()},
            {"replacementLength", input->replacementLength()},
            {"focusObject", describeObject(QGuiApplication::focusObject())}
        });
        break;
    }
    case QEvent::FocusIn:
    case QEvent::FocusOut: {
        auto *focus = static_cast<QFocusEvent *>(event);
        AppLogger::debug("ui.focus",
                         event->type() == QEvent::FocusIn ? "focus_in" : "focus_out",
                         QString(), {
            {"reason", static_cast<int>(focus->reason())},
            {"object", describeObject(watched)}
        });
        break;
    }
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::TouchCancel: {
        auto *touch = static_cast<QTouchEvent *>(event);
        QJsonArray points;
        for (const QEventPoint &point : touch->points()) {
            points.append(QJsonObject{
                {"id", point.id()},
                {"state", static_cast<int>(point.state())},
                {"x", point.globalPosition().x()},
                {"y", point.globalPosition().y()},
                {"pressure", point.pressure()}
            });
        }
        AppLogger::info("ui.touch", QString::number(static_cast<int>(event->type())), QString(), {
            {"pointCount", touch->points().size()},
            {"points", points}
        });
        break;
    }
    case QEvent::Shortcut: {
        auto *shortcut = static_cast<QShortcutEvent *>(event);
        AppLogger::info("ui.keyboard", "shortcut", QString(), {
            {"key", shortcut->key().toString(QKeySequence::PortableText)},
            {"ambiguous", shortcut->isAmbiguous()},
            {"receiver", describeObject(watched)}
        });
        break;
    }
    case QEvent::Show:
    case QEvent::Hide:
    case QEvent::Close:
    case QEvent::WindowActivate:
    case QEvent::WindowDeactivate:
    case QEvent::WindowStateChange: {
        AppLogger::info("ui.window", QString::number(static_cast<int>(event->type())), QString(), {
            {"eventType", static_cast<int>(event->type())},
            {"object", describeObject(watched)}
        });
        break;
    }
    case QEvent::Resize: {
        auto *resize = static_cast<QResizeEvent *>(event);
        AppLogger::debug("ui.window", "resize", QString(), {
            {"oldWidth", resize->oldSize().width()},
            {"oldHeight", resize->oldSize().height()},
            {"width", resize->size().width()},
            {"height", resize->size().height()},
            {"object", describeObject(watched)}
        });
        break;
    }
    case QEvent::Move: {
        auto *move = static_cast<QMoveEvent *>(event);
        AppLogger::debug("ui.window", "move", QString(), {
            {"oldX", move->oldPos().x()},
            {"oldY", move->oldPos().y()},
            {"x", move->pos().x()},
            {"y", move->pos().y()},
            {"object", describeObject(watched)}
        });
        break;
    }
    default:
        break;
    }

    return QObject::eventFilter(watched, event);
}

QString InteractionEventFilter::describeObject(QObject *object) const {
    if (!object) return QStringLiteral("<null>");

    QStringList fields;
    fields << className(object);
    if (!object->objectName().isEmpty()) fields << QStringLiteral("objectName=") + object->objectName();

    const QString title = safeProperty(object, "title");
    const QString accessibleName = safeProperty(object, "accessibleName");
    const QString placeholder = safeProperty(object, "placeholderText");
    const QString page = safeProperty(object, "page");
    const QString section = safeProperty(object, "section");
    const QString key = safeProperty(object, "key");

    if (!title.isEmpty()) fields << QStringLiteral("title=") + title;
    if (!accessibleName.isEmpty()) fields << QStringLiteral("accessibleName=") + accessibleName;
    if (!placeholder.isEmpty()) fields << QStringLiteral("placeholder=") + placeholder;
    if (!page.isEmpty()) fields << QStringLiteral("page=") + page;
    if (!section.isEmpty()) fields << QStringLiteral("section=") + section;
    if (!key.isEmpty()) fields << QStringLiteral("key=") + key;

    if (!isTextInputLike(object)) {
        const QString text = safeProperty(object, "text");
        if (!text.isEmpty()) fields << QStringLiteral("text=") + text;
    }

    const struct {
        const char *name;
        const char *label;
    } booleanProperties[] = {
        {"enabled", "enabled"},
        {"visible", "visible"},
        {"activeFocus", "activeFocus"},
        {"checked", "checked"},
        {"pressed", "pressed"},
        {"containsMouse", "containsMouse"}
    };
    for (const auto &entry : booleanProperties) {
        const QVariant value = object->property(entry.name);
        if (value.isValid()) {
            fields << QString::fromLatin1(entry.label) + QLatin1Char('=')
                + (value.toBool() ? QStringLiteral("true") : QStringLiteral("false"));
        }
    }

    const QVariant currentIndex = object->property("currentIndex");
    if (currentIndex.isValid()) fields << QStringLiteral("currentIndex=") + currentIndex.toString();
    const QVariant acceptedButtons = object->property("acceptedButtons");
    if (acceptedButtons.isValid()) fields << QStringLiteral("acceptedButtons=") + acceptedButtons.toString();

    return fields.join(';');
}

QString InteractionEventFilter::describeQuickTarget(const QPointF &globalPosition) const {
    QQuickWindow *window = windowAtGlobalPoint(globalPosition);
    if (!window || !window->contentItem()) return QStringLiteral("<no-quick-window>");

    const QPoint localPoint = window->mapFromGlobal(globalPosition.toPoint());
    QQuickItem *target = deepestChildAt(window->contentItem(), QPointF(localPoint));
    if (!target) return describeObject(window);

    QStringList path;
    QObject *current = target;
    int depth = 0;
    while (current && current != window && depth < 8) {
        path << describeObject(current);
        current = current->parent();
        ++depth;
    }
    return path.join(" <- ");
}

QQuickItem *InteractionEventFilter::deepestChildAt(QQuickItem *root,
                                                    const QPointF &pointInRoot) const {
    if (!root) return nullptr;
    QQuickItem *current = root;
    QPointF point = pointInRoot;
    for (int depth = 0; depth < 32; ++depth) {
        QQuickItem *child = current->childAt(point.x(), point.y());
        if (!child || child == current) break;
        point = child->mapFromItem(current, point);
        current = child;
    }
    return current;
}

QString InteractionEventFilter::mouseButtonName(int button) {
    switch (static_cast<Qt::MouseButton>(button)) {
    case Qt::LeftButton: return "left";
    case Qt::RightButton: return "right";
    case Qt::MiddleButton: return "middle";
    case Qt::BackButton: return "back";
    case Qt::ForwardButton: return "forward";
    case Qt::NoButton: return "none";
    default: return QString::number(button);
    }
}

QString InteractionEventFilter::modifiersName(int modifiers) {
    QStringList values;
    const auto value = static_cast<Qt::KeyboardModifiers>(modifiers);
    if (value.testFlag(Qt::ShiftModifier)) values << "Shift";
    if (value.testFlag(Qt::ControlModifier)) values << "Ctrl";
    if (value.testFlag(Qt::AltModifier)) values << "Alt";
    if (value.testFlag(Qt::MetaModifier)) values << "Meta";
    if (value.testFlag(Qt::KeypadModifier)) values << "Keypad";
    if (value.testFlag(Qt::GroupSwitchModifier)) values << "GroupSwitch";
    return values.isEmpty() ? QStringLiteral("None") : values.join('+');
}
