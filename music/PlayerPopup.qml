import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets"

// music player popup — below the bar center; MPRIS + game radio
PanelWindow {
    id: root

    screen: Theme.mainScreen()
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    visible: Ui.playerPopupVisible
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 320
    mask: Region {
        item: panel
    }

    Border {
        id: panel

        readonly property real uiScale: 1.2

        anchors {
            top: parent.top
            topMargin: 52
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.round(420 * uiScale)
        height: Math.round(230 * uiScale)
        
        ColumnLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            // ---- MPRIS section ----
            Text {
                visible: !Music.hasTrack && !Music.radioPlaying
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "nothing is playing..."
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.fg2
                smooth: false
            }

            ColumnLayout {
                visible: Music.hasTrack
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Music.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(16 * panel.uiScale)
                    color: Theme.fg
                    smooth: false
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    visible: Music.artist !== ""
                    text: Music.artist
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(12 * panel.uiScale)
                    color: Theme.accent
                    smooth: false
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 24

                    CtrlButton { glyph: "⏮"; onClicked: Music.previous() }
                    CtrlButton {
                        glyph: Music.isPlaying ? "⏸" : "▶"
                        big: true
                        onClicked: Music.togglePlaying()
                    }
                    CtrlButton { glyph: "⏭"; onClicked: Music.next() }
                }
            }

            Rectangle {
                visible: Music.hasTrack && (Music.radioPlaying || true)
                Layout.fillWidth: true
                height: 1
                color: Theme.bg3
            }

            // ---- game radio section ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "GAME RADIO"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.fg2
                    smooth: false
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index
                            readonly property int st: index + 1
                            readonly property bool active: Music.station === st
                            width: 64
                            height: 36
                            color: active ? Theme.accent : Theme.bg2
                            border.color: active ? Theme.accent : Theme.bg3
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: `FM${parent.st}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.fg
                                smooth: false
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Music.startStation(parent.parent.st)
                            }
                        }
                    }

                    Text {
                        visible: Music.radioPlaying
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: `track ${Music.trackIndex + 1}`
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.fg2
                        smooth: false
                    }

                    Text {
                        visible: Music.radioPlaying
                        text: "⏭"
                        color: Theme.fg

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Music.nextTrack()
                        }
                    }
                }
            }
        }
    }

    component CtrlButton: Rectangle {
        id: cb

        property string glyph: "▶"
        property bool big: false
        signal clicked()

        width: big ? 48 : 36
        height: width
        color: mouse.containsMouse ? Theme.accent2 : Theme.bg2

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Theme.bg3
            border.width: 1
        }

        Text {
            anchors.centerIn: parent
            text: cb.glyph
            font.pixelSize: cb.big ? 18 : 14
            color: Theme.fg
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }
}
