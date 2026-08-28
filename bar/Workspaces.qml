pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import ".."

// 7 workspace dots — one per room. pixel circles, game palette.
MouseArea {
    id: root

    required property var bar
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    property int wsBaseIndex: 1
    property int wsCount: 7
    property int currentIndex: 1

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    acceptedButtons: Qt.NoButton
    hoverEnabled: true

    onWheel: e => {
        e.accepted = true;
        const step = -Math.sign(e.angleDelta.y);
        const targetWs = currentIndex + step;
        if (targetWs >= wsBaseIndex && targetWs < wsBaseIndex + wsCount)
            Hyprland.dispatch(`workspace ${targetWs}`);
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 8

        Repeater {
            model: root.wsCount

            MouseArea {
                id: wsItem

                required property int index
                property int wsIndex: root.wsBaseIndex + index
                readonly property bool active:
                    (root.monitor?.activeWorkspace ?? null) != null
                    && root.monitor.activeWorkspace.id == wsItem.wsIndex
                readonly property bool current: root.currentIndex === wsItem.wsIndex

                implicitWidth: 24
                implicitHeight: 24
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onPressed: Hyprland.dispatch(`workspace ${wsIndex}`)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: width / 2
                    color: wsItem.active ? Theme.accent2
                        : wsItem.current ? "#52263e"
                        : Theme.bg3
                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: wsItem.index + 1
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: wsItem.active || wsItem.current ? Theme.fg : Theme.fg2
                    smooth: false
                }
            }
        }
    }

    Connections {
        target: root.monitor

        function onActiveWorkspaceChanged() {
            root.currentIndex = root.monitor?.activeWorkspace?.id ?? root.currentIndex;
        }
    }

    Component.onCompleted:
        currentIndex = monitor?.activeWorkspace?.id ?? 1
}
