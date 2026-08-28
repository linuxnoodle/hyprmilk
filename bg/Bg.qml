import Quickshell
import QtQuick
import ".."

PanelWindow {
    id: bg

    required property var modelData

    screen: modelData
    exclusionMode: ExclusionMode.Normal   // clicks on wallpaper only
    aboveWindows: false
    focusable: false
    color: "transparent"

    // bar reserves space; give bg the SAME claim so it fills the full screen
    // (layer-shell: a surface's own zone sizes it into the reserved strip)
    exclusiveZone: Math.round(Theme.barExclusive
        * Math.max(1, Math.min(1.6, width / 2560)))

    anchors {
        top: true
        left: true
        bottom: true
        right: true
    }

    // ---- parallax engine ----
    // x = -50 + (center - pointer.x) * 0.05 : content moves OPPOSITE the
    // cursor; closer layers (higher depth) move more. pointer tracked
    // globally (Cursor singleton) so it follows the mouse everywhere.
    property real engineX: 0     // smoothed cursor-center delta [-0.5..0.5]
    property real engineY: 0
    property real phaseT: 0

    // slow idle drift (Lissajous periods ~30-60s) keeps the scene alive
    readonly property real driftX: Theme.parallaxEnabled ? Math.sin(bg.phaseT * 0.07) * 18 : 0
    readonly property real driftY: Theme.parallaxEnabled ? Math.cos(bg.phaseT * 0.055) * 12 : 0

    function normX() { return (Cursor.gx - (bg.modelData?.x ?? 0)) / bg.width - 0.5; }
    function normY() { return (Cursor.gy - (bg.modelData?.y ?? 0)) / bg.height - 0.5; }

    function shiftX(depth) { return Theme.parallaxEnabled ? (-bg.engineX * 120 + bg.driftX) * depth : 0; }
    function shiftY(depth) { return Theme.parallaxEnabled ? (-bg.engineY * 95 + bg.driftY) * depth : 0; }

    Timer {
        interval: 16
        running: Theme.parallaxEnabled   // dead when parallax disabled
        repeat: true
        onTriggered: {
            const k = Math.exp(-3.2 * 0.016);
            if (Cursor.ready) {
                bg.engineX += (bg.normX() - bg.engineX) * (1 - k);
                bg.engineY += (bg.normY() - bg.engineY) * (1 - k);
            } else {
                // cursor not reported yet: ease back to center
                bg.engineX *= (1 - k);
                bg.engineY *= (1 - k);
            }
            bg.phaseT += 0.016;
        }
    }

    // click = next girl state (motion comes from the global cursor, so it
    // works even when the pointer is over other windows)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.CrossCursor
        onClicked: RoomState.nextState()
    }

    // ---- layers (each wrapped in an Item so offsets don't fight anchors) ----
    // bottom: skybox (intro-style art; off unless enabled via launcher)
    Item {
        z: -2
        anchors.fill: parent
        x: bg.shiftX(0.35)
        y: bg.shiftY(0.35)

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
        x: bg.shiftX(0.5)
        y: bg.shiftY(0.5)

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: RoomState.showSkybox
            source: RoomState.skyboxIndex > 0
                ? `../assets/bg/mirror/${RoomState.skyboxIndex}.png` : ""
        }
    }

    // wallpaper: real game imagery (CGs / sky frames / room art) from
    // assets/bg/walls/, downscaled by tools. one static image per session,
    // cycled via the launcher action.
    Image {
        id: wall
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: false
        layer.enabled: true
        layer.smooth: false
        layer.textureSize: Qt.size(width, height)
        source: RoomState.wallIndex >= 0
            ? `../assets/bg/walls/${RoomState.walls[RoomState.wallIndex]}.png`
            : "../assets/bg/walls/room.png"
    }

    // Milk-Chan: only on the main (widest) monitor, closest layer
    MilkChan {
        readonly property var main: bg.mainScreen()
        visible: (modelData?.width === main?.width) && main != null

        scale: Math.min(1.0, parent.height / 1027 * 0.7)
        speaking: RoomState.speaking
        layer.enabled: true
        layer.smooth: false
        x: bg.shiftX(1.7)
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