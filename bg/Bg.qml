import Quickshell
import QtQuick
import ".."

PanelWindow {
    id: bg

    required property var modelData

    screen: modelData
    exclusionMode: ExclusionMode.Normal   // receive pointer over wallpaper only
    aboveWindows: false
    focusable: false
    color: "transparent"

    anchors {
        top: true
        left: true
        bottom: true
        right: true
    }

    // ---- pointer parallax (updates only while hovering the wallpaper) ----
    property real cx: 0.5
    property real cy: 0.5
    property real driftT: 0

    // subtle idle drift + cursor parallax offsets (px, screen-sized)
    readonly property real parX:
        (0.5 - cx) * 34 + Math.sin(driftT) * 16
    readonly property real parY:
        (0.5 - cy) * 20 + Math.cos(driftT * 0.83) * 9

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: bg.driftT += 0.055
    }

    // whole-surface pointer surface: hover = parallax, click = next state
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.CrossCursor

        onPositionChanged: e => {
            bg.cx = mouseX / width;
            bg.cy = mouseY / height;
        }
        onClicked: RoomState.nextState()
    }

    // ---- layers (each wrapped in an Item so offsets don't fight anchors) ----
    // bottom: skybox (intro-style art; off unless enabled via launcher)
    Item {
        z: -2
        anchors.fill: parent
        x: parX * 0.6
        y: parY * 0.6

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            visible: RoomState.showSkybox
            source: RoomState.skyboxIndex > 0
                ? `../assets/bg/skybox/${RoomState.skyboxIndex}.png` : ""
        }
    }

    // mirror reflection overlay over the skybox
    Item {
        z: -1
        anchors.fill: parent
        x: parX * 0.8
        y: parY * 0.8

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: RoomState.showSkybox
            source: RoomState.skyboxIndex > 0
                ? `../assets/bg/mirror/${RoomState.skyboxIndex}.png` : ""
        }
    }

    // room plate: static flat red/black bedroom, drawn slightly oversized so
    // parallax/drift never reveals edges. layer texture = repaint-stable.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        Image {
            anchors.fill: parent
            width: parent.width * 1.08
            height: parent.height * 1.08
            x: parX - (width - parent.width) / 2
            y: parY - (height - parent.height) / 2
            fillMode: Image.PreserveAspectCrop
            smooth: false
            layer.enabled: true
            layer.smooth: false
            layer.textureSize: Qt.size(width, height)
            source: "../assets/bg/bg.png"
        }
    }

    // Milk-Chan: only on the main (widest) monitor
    MilkChan {
        readonly property var main: bg.mainScreen()
        visible: (modelData?.width === main?.width) && main != null

        scale: Math.min(1.0, parent.height / 1027 * 0.7)
        speaking: RoomState.speaking
        layer.enabled: true
        layer.smooth: false
        x: parX * 0.35
        anchors {
            bottom: parent.bottom
            right: parent.right
            rightMargin: parent.width * 0.08
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: RoomState.nextState()
        }
    }

    function mainScreen() {
        const screens = Quickshell.screens;
        let best = null;
        for (let i = 0; i < screens.length; ++i) {
            const s = screens[i];
            if (s && (!best || s.width > best.width))
                best = s;
        }
        return best;
    }
}