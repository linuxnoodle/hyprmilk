import QtQuick
import ".."

Rectangle {
    id: root

    property int size: 14
    property bool showDate: false

    color: "transparent"
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        font.bold: false
        color: Theme.fg
        smooth: false

        property date now: new Date()
        text: {
            const h = String(now.getHours()).padStart(2, "0");
            const m = String(now.getMinutes()).padStart(2, "0");
            if (!showDate)
                return `${h}:${m}`;
            const d = String(now.getDate()).padStart(2, "0");
            const mo = String(now.getMonth() + 1).padStart(2, "0");
            return `${d}.${mo} ${h}:${m}`;
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: label.now = new Date()
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animFast }
    }
}
