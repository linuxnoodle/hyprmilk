pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import ".."
import "../widgets"

PanelWindow {
    id: root

    required property var modelData

    // UI scale grows with screen width so the bar isn't tiny on ultrawide
    readonly property real uiScale: Math.max(1, Math.min(1.6, width / 2560))
    readonly property int segPad: Math.round(12 * uiScale)
    readonly property int segGap: Math.round(16 * uiScale)
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null

    WlrLayershell.namespace: "shell:bar"
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: Math.round(Theme.barExclusive * root.uiScale)  // reserve space so windows start below the bar
    implicitHeight: exclusiveZone
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

        implicitHeight: Math.round(Theme.barHeight * root.uiScale)
        color: "transparent"

        // left: workspaces
        Border {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            implicitWidth: leftRow.implicitWidth + 2 * root.segPad
            RowLayout {
                id: leftRow
                anchors {
                    fill: parent
                    leftMargin: root.segPad
                    rightMargin: root.segPad
                }
                Workspaces {
                    bar: root
                }
            }
        }

        // center: music (only when something plays)
        Border {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                bottom: parent.bottom
            }
            implicitWidth: mprisRow.implicitWidth + 2 * root.segPad
            visible: mpris.displayText !== ""

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.animMed }
            }

            RowLayout {
                id: mprisRow
                anchors {
                    fill: parent
                    leftMargin: root.segPad
                    rightMargin: root.segPad
                }
                MprisWidget {
                    id: mpris
                    uiScale: root.uiScale
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
            implicitWidth: timeWidget.implicitWidth + 2 * root.segPad
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: root.segPad
                    rightMargin: root.segPad
                }
                Time {
                    id: timeWidget
                    size: Math.round(14 * root.uiScale)
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
                rightMargin: root.segGap
            }
            implicitWidth: trayRow.implicitWidth + 2 * root.segPad
            RowLayout {
                id: trayRow
                anchors {
                    fill: parent
                    leftMargin: root.segPad
                    rightMargin: root.segPad
                }
                spacing: Math.round(12 * root.uiScale)

                Text {
                    text: RoomState.roomId.toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(12 * root.uiScale)
                    color: Theme.fg2
                    smooth: false
                }

                // sink volume: state icon + percent to its right; click =
                // mute toggle, wheel = volume
                Item {
                    id: volGroup
                    implicitWidth: volIcon.width + volText.implicitWidth
                        + Math.round(5 * root.uiScale)
                    implicitHeight: Math.max(volIcon.height, volText.implicitHeight)

                    BarIcon {
                        id: volIcon
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "speaker"
                        active: !(root.sink?.muted ?? false)
                        muted: root.sink?.muted ?? false
                    }

                    Text {
                        id: volText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: volIcon.right
                        anchors.leftMargin: Math.round(5 * root.uiScale)
                        function volPct() {
                            return `${Math.round((root.sink?.volume ?? 0) * 100)}%`;
                        }
                        text: root.sink?.muted ? `--` : volPct()
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(12 * root.uiScale)
                        color: root.sink?.muted ? Theme.fg2 : Theme.fg
                        smooth: false
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.sink)
                                root.sink.muted = !root.sink.muted;
                        }
                        onWheel: e => {
                            if (!root.sink)
                                return;
                            e.accepted = true;
                            const step = Math.sign(e.angleDelta.y) * 0.05;
                            root.sink.volume = Math.max(0, Math.min(1,
                                (root.sink.volume ?? 0) + step));
                        }
                    }
                }

                Battery {
                    size: Math.round(12 * root.uiScale)
                }

                Item {
                    width: voiceIcon.width
                    height: voiceIcon.height

                    BarIcon {
                        id: voiceIcon
                        kind: "speaker"
                        active: !RoomState.voiceMuted
                        muted: RoomState.voiceMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: RoomState.toggleVoice()
                    }
                }

                Item {
                    width: bellIcon.width
                    height: bellIcon.height

                    BarIcon {
                        id: bellIcon
                        kind: "bell"
                        active: Ui.notifCenterVisible
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.notifCenterVisible = !Ui.notifCenterVisible
                    }
                }

                Text {
                    text: "⏻"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(14 * root.uiScale)
                    color: Theme.fg2

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.controlVisible = !Ui.controlVisible
                    }
                }
            }
        }
    }
}
