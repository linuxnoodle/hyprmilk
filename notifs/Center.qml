import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import ".."
import "../widgets"

// notification center — right slide-in panel with history
PanelWindow {
    id: root

    required property NotificationServer server

    screen: Theme.mainScreen()
    exclusionMode: ExclusionMode.Normal
    aboveWindows: true
    focusable: true
    visible: Ui.notifCenterVisible
    color: "transparent"

    anchors {
        top: true
        right: true
        bottom: true
    }
    implicitWidth: Math.round(380 * panel.uiScale)
    mask: Region {
        item: panel
    }

    onVisibleChanged: if (visible)
        anim.start()

    Border {
        id: panel

        readonly property real uiScale: 1.15

        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }
        width: parent.width
        opacity: 0
        transform: Translate { id: slide; x: panel.width }

        SequentialAnimation {
            id: anim
            ParallelAnimation {
                NumberAnimation { target: slide; property: "x"; to: 0; duration: Theme.animMed; easing.type: Easing.OutCubic }
                NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Theme.animFast }
            }
        }

        Connections {
            target: Ui

            function onNotifCenterVisibleChanged() {
                if (!Ui.notifCenterVisible)
                    outAnim.start();
            }
        }
        SequentialAnimation {
            id: outAnim
            ParallelAnimation {
                NumberAnimation { target: slide; property: "x"; to: panel.width; duration: Theme.animMed; easing.type: Easing.InCubic }
                NumberAnimation { target: panel; property: "opacity"; to: 0; duration: Theme.animFast }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "NOTIFICATIONS"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.accent
                    smooth: false
                    Layout.fillWidth: true
                }
                Text {
                    text: "clear"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.fg2

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            for (const n of root.server.trackedNotifications.values)
                                n.dismiss();
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.bg3 }

            // history — tracked notifications, newest last; show reversed
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: root.server.trackedNotifications.values.slice().reverse()

                delegate: Rectangle {
                    required property var modelData
                    width: list.width
                    height: Math.max(64, col.implicitHeight + 20)
                    color: Theme.bg2
                    border.color: Theme.bg3
                    border.width: 1

                    ColumnLayout {
                        id: col
                        anchors {
                            fill: parent
                            margins: 10
                            leftMargin: 14
                        }
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.appName ?? "milk"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.fg2
                            smooth: false
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: modelData.summary ?? ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.fg
                            smooth: false
                        }
                        Text {
                            visible: (modelData.body ?? "") !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: modelData.body ?? ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.fg2
                            smooth: false
                        }
                    }
                    Rectangle {
                        width: 3
                        color: Theme.accent
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: modelData.dismiss()
                    }
                }
            }

            Text {
                visible: list.count === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "...and then there was silence."
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.fg2
                smooth: false
            }
        }
    }
}
