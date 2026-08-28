pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// bar center segment: track title (click: popup, wheel: next/prev)
Rectangle {
    id: root

    required property real uiScale

    color: "transparent"
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property string displayText:
        Music.radioPlaying ? `📻 FM${Music.station} · track ${Music.trackIndex + 1}`
        : Music.hasTrack ? Music.title : ""

    RowLayout {
        id: row
        spacing: 8

        Text {
            visible: Music.isPlaying || Music.radioPlaying
            text: "♪"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(12 * root.uiScale)
            color: Theme.accent
            smooth: false
        }
        Text {
            text: root.displayText
            elide: Text.ElideRight
            Layout.preferredWidth: Math.min(implicitWidth, 420)
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(13 * root.uiScale)
            color: Theme.fg
            smooth: false
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.playerPopupVisible = !Ui.playerPopupVisible
        onWheel: e => {
            e.accepted = true;
            if (Math.sign(e.angleDelta.y) > 0)
                Music.next();
            else
                Music.previous();
        }
    }
}
