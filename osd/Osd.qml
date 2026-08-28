import Quickshell
import QtQuick
import Quickshell.Services.Pipewire
import ".."
import "../widgets"

// volume OSD — tiny framed popup, bottom center, auto-hides
PanelWindow {
    id: root

    screen: Quickshell.primaryScreen ?? Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 90
    visible: osd.visible   // unmap when idle
    mask: Region {
        item: osd.visible ? osd : null
    }

    property bool shown: false

    function flash() {
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null

    Connections {
        target: root.sink

        function onVolumeChanged() {
            root.flash();
        }
        function onMutedChanged() {
            root.flash();
        }
    }

    Rectangle {
        id: osd

        readonly property real uiScale: 1.15

        anchors {
            bottom: parent.bottom
            bottomMargin: 28
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.round(320 * uiScale)
        height: Math.round(52 * uiScale)
        radius: 0
        color: Theme.bg
        border.color: Theme.bg3
        border.width: 1
        opacity: root.shown ? 1 : 0
        visible: root.shown || opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast }
        }

        Row {
            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.sink?.muted ? "🔇" : "🔊"
                font.pixelSize: 18
                color: Theme.fg
            }

            // pixel volume blocks
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: 10

                    Rectangle {
                        required property int index
                        readonly property real vol: root.sink?.volume ?? 0
                        width: 16
                        height: 22
                        color: (index + 1) / 10 <= vol
                            ? (root.sink?.muted ? Theme.bg3 : Theme.accent)
                            : Theme.bg2
                        border.color: Theme.bg3
                        border.width: 1
                    }
                }
            }
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            text: `${Math.round((root.sink?.volume ?? 0) * 100)}%`
            font.family: Theme.fontFamily
            font.pixelSize: 14
            color: Theme.fg
            smooth: false
        }
    }
}
