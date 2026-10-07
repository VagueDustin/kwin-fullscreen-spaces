// Slide-down title bar shown over a fullscreen window, like macOS.

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Window {
    id: bar

    property var client: null
    property bool shown: false

    signal exitRequested(var w)

    flags: Qt.FramelessWindowHint | Qt.X11BypassWindowManagerHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    transientParent: null // top-level; otherwise it waits for the script root, which has no window
    visible: false
    height: Math.round(Kirigami.Units.gridUnit * 1.9)

    function reveal(w) {
        const g = w.output.geometry;
        client = w;
        x = g.x;
        y = g.y;
        width = g.width;
        hideAfterSlide.stop();
        visible = true;
        shown = true;
    }

    function dismiss() {
        if (!client) return;
        client = null;
        shown = false;
        hideAfterSlide.restart();
    }

    Timer {
        id: hideAfterSlide
        interval: 180
        onTriggered: if (!bar.client) bar.visible = false
    }

    Rectangle {
        id: panel
        width: parent.width
        height: parent.height
        y: bar.shown ? 0 : -height
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Kirigami.Theme.colorSet: Kirigami.Theme.Header
        Kirigami.Theme.inherit: false
        color: Kirigami.Theme.backgroundColor

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
        }

        // Title (icon + caption), centred like a regular title bar.
        RowLayout {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - buttons.width * 2 - Kirigami.Units.largeSpacing * 4)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: bar.client ? bar.client.icon : ""
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: bar.client ? bar.client.caption : ""
                elide: Text.ElideRight
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
        }

        // Same order as the normal title bar: minimize, exit full screen, close.
        Row {
            id: buttons
            anchors { right: parent.right; rightMargin: Kirigami.Units.smallSpacing; verticalCenter: parent.verticalCenter }
            spacing: 0

            PlasmaComponents.ToolButton {
                icon.name: "window-minimize"
                display: QQC2.AbstractButton.IconOnly
                text: "Minimize"
                onClicked: { const w = bar.client; bar.dismiss(); if (w) w.minimized = true; }
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-restore"
                display: QQC2.AbstractButton.IconOnly
                text: "Exit Full Screen"
                onClicked: { const w = bar.client; bar.dismiss(); if (w) bar.exitRequested(w); }
            }
            PlasmaComponents.ToolButton {
                icon.name: "window-close"
                display: QQC2.AbstractButton.IconOnly
                text: "Close"
                onClicked: { const w = bar.client; bar.dismiss(); if (w) w.closeWindow(); }
            }
        }
    }
}
