pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../widgets"

PanelWindow {
    id: root

    required property var modelData

    WlrLayershell.namespace: "shell:bar"
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: Theme.barExclusive
    implicitHeight: Theme.barExclusive
    color: "transparent"
    mask: barRegion

    Region {
        id: barRegion
        width: bar.width
        height: bar.height
    }

    Rectangle {
        id: bar

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: Theme.barMargin
            topMargin: Theme.barMargin
            rightMargin: Theme.barMargin
        }

        implicitHeight: Theme.barHeight
        color: "transparent"

        // left: workspaces
        Border {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            implicitWidth: leftRow.implicitWidth + 24
            RowLayout {
                id: leftRow
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                Workspaces {
                    bar: root
                }
            }
        }

        // right: clock
        Border {
            id: rightSeg
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            implicitWidth: timeWidget.implicitWidth + 24
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                Time {
                    id: timeWidget
                    size: 14
                    showDate: false
                }
            }
            MouseArea {
                z: 10
                anchors.fill: parent
                hoverEnabled: true
                onEntered: timeWidget.showDate = true
                onExited: timeWidget.showDate = false
            }
            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.animMed }
            }
        }

        // tray segment: room label + voice mute + power
        Border {
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: rightSeg.left
                rightMargin: 16
            }
            implicitWidth: trayRow.implicitWidth + 24
            RowLayout {
                id: trayRow
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 12

                Text {
                    text: RoomState.roomId.toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.fg2
                    smooth: false
                }

                Text {
                    text: RoomState.voiceMuted ? "🔇" : "🔊"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: RoomState.voiceMuted ? Theme.fg2 : Theme.fg

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: RoomState.toggleVoice()
                    }
                }

                Text {
                    text: "⏻"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.fg2

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.exit()
                    }
                }
            }
        }
    }
}
