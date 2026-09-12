import QtQuick
import Quickshell.Services.UPower
import ".."

// battery readout — "NN%" normally, time remaining on hover (Time.qml
// pattern: text swaps while hovered, segment width eases between sizes).
// low battery (< 15%) shifts to the brighter alarm red used for capslock
// in the hyprlock theme.
Rectangle {
    id: root

    property int size: 12
    property bool hovered: false

    readonly property var dev: UPower.displayDevice
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
    readonly property bool full: dev?.state === UPowerDeviceState.Full
    readonly property real pct: Math.round(dev?.percentage ?? 0)
    // seconds until empty (discharging) / full (charging); 0 = unknown
    readonly property int secs: charging ? (dev?.timeToFull ?? 0)
                                         : (dev?.timeToEmpty ?? 0)
    readonly property bool low: !charging && !full && pct <= 15

    // desktops: displayDevice is an AC line at 0% — hide rather than read 0%
    visible: (dev?.percentage ?? 0) > 0

    color: "transparent"
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    function fmtTime(s) {
        if (s <= 0)
            return "--:--";
        const h = Math.floor(s / 3600);
        const m = Math.round((s % 3600) / 60);
        if (h > 0)
            return `${h}:${String(m).padStart(2, "0")}`;
        return `${m}m`;
    }

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        color: root.low ? "#e23c3c" : Theme.fg
        smooth: false

        text: {
            if (root.hovered) {
                const t = root.fmtTime(root.secs);
                if (root.full)
                    return "ON AC";
                if (root.secs <= 0)
                    return `${root.pct}%`;
                return root.charging ? `${t} TO FULL` : `${t} LEFT`;
            }
            return root.charging ? `+${root.pct}%` : `${root.pct}%`;
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6   // forgiving hover target
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animFast }
    }
}
