import Quickshell
import QtQuick
import ".."

// Layered wallpaper with per-layer cursor parallax (Synoptik pattern):
// - overscanned canvases (parent + overscan) so shifts never show edges
// - one `transform: Translate` per layer, scaled by layer depth
// - smoothing = Behavior + NumberAnimation (no timers, no idle CPU)
//   cursor source = Cursor singleton (persistent Hyprland IPC poller)
PanelWindow {
    id: bg

    required property var modelData

    screen: modelData
    exclusionMode: ExclusionMode.Normal   // clicks on wallpaper only
    aboveWindows: false
    focusable: false
    color: "transparent"

    // bar reserves space; give bg the SAME claim so it fills the full screen
    exclusiveZone: Math.round(Theme.barExclusive
        * Math.max(1, Math.min(1.6, width / 2560)))

    anchors {
        top: true
        left: true
        bottom: true
        right: true
    }

    // ---- parallax math (per-window, normalized to this monitor) ----
    readonly property bool par: Theme.parallaxEnabled
    readonly property real intensity: Theme.parallaxIntensity
    readonly property real overscanX: width * 0.14 * intensity
    readonly property real overscanY: height * 0.09 * intensity

    readonly property real cursorNormX: {
        if (!Cursor.ready || !modelData)
            return 0.5;
        return Math.max(0.0, Math.min(1.0,
            (Cursor.gx - (modelData.x ?? 0)) / (modelData.width || 1)));
    }
    readonly property real cursorNormY: {
        if (!Cursor.ready || !modelData)
            return 0.5;
        return Math.max(0.0, Math.min(1.0,
            (Cursor.gy - (modelData.y ?? 0)) / (modelData.height || 1)));
    }

    // content moves OPPOSITE the cursor; nearer layers (higher depth) more
    readonly property real targetX: par ? (cursorNormX - 0.5) * -overscanX : 0
    readonly property real targetY: par ? (cursorNormY - 0.5) * -overscanY : 0

    property real smoothX: targetX
    property real smoothY: targetY

    // momentum: underdamped spring = overshoot & settle when sweeping
    Behavior on smoothX {
        SpringAnimation { spring: 6.0; damping: 0.35; mass: 1.0; epsilon: 0.01 }
    }
    Behavior on smoothY {
        SpringAnimation { spring: 6.0; damping: 0.35; mass: 1.0; epsilon: 0.01 }
    }

    // shared warp fields (depth-scaled lean + foreshorten)
    // breathing phase for Milk-Chan (idle inhale/exhale)
    property real breathPhase: 0

    // per-depth offset (depth 1 = room plate reference)
    function layerX(depth) { return smoothX * depth; }
    function layerY(depth) { return smoothY * depth; }

    Timer {
        interval: 64
        running: true
        repeat: true
        onTriggered: bg.breathPhase += 0.045   // ~9s full breath cycle
    }

    // click = next girl state
    // wallpaper crossfade progress
    property real wallFade: 1
    Behavior on wallFade {
        NumberAnimation { duration: 240; easing.type: Easing.InOutQuad }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.CrossCursor
        onClicked: RoomState.nextState()
    }

    // ---- layer 1 (far): red-dominant imagery seen through the windows ----
    Item {
        id: wallCanvas
        z: -2
        anchors.centerIn: parent
        width: parent.width + bg.overscanX * 1.5
        height: parent.height + bg.overscanY * 1.5

        transform: Translate {
            x: bg.layerX(0.45)
            y: bg.layerY(0.45)
        }

        // crossfade: old frame lingers as backdrop while new fades in fast
        Image {
            id: wallOld
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            visible: source !== ""
        }
        Image {
            id: wallNew
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            opacity: bg.wallFade
            source: RoomState.wallIndex >= 0
                ? `../assets/bg/walls/${RoomState.walls[RoomState.wallIndex]}.png`
                : "../assets/bg/walls/room.png"
        }
    }

    // ---- layer 2 (mid): room plate, transparent window cutouts ----
    Item {
        id: plateCanvas
        z: 0
        anchors.centerIn: parent
        width: parent.width + bg.overscanX * 1.5
        height: parent.height + bg.overscanY * 1.5

        transform: Translate {
            x: bg.layerX(1.0)
            y: bg.layerY(1.0)
        }

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            source: "../assets/bg/bg.png"
        }
    }

    // ---- layer 3 (near): Milk-Chan, main monitor only ----
    MilkChan {
        id: bgWarp
        readonly property var main: bg.mainScreen()
        visible: (modelData?.width === main?.width) && main != null
                && RoomState.girlVisible

        // planted at the bottom edge; horizontal-only parallax so she never
        // detaches from or clips past the bottom
        scale: Math.min(1.05, parent.height / 1027 * 0.78)
        speaking: RoomState.speaking
        layer.enabled: true
        layer.smooth: false
        anchors {
            bottom: parent.bottom
            right: parent.right
            rightMargin: parent.width * 0.08
        }

        // vertical parallax = WARP, not translate: lean (shear) + slight
        // foreshorten, feet pinned to the bottom edge. driven by bg.smoothY.
        // idle breathing: gentle 2% vertical squash, feet pinned
        readonly property real breathSquash: 1 + Math.sin(bg.breathPhase) * 0.02
        readonly property real footH: height

        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(
                1, 0, 0, bg.layerX(1.6),
                0, bgWarp.breathSquash, 0, bgWarp.footH * (1 - bgWarp.breathSquash),
                0, 0, 1, 0,
                0, 0, 0, 1)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: RoomState.nextState()
        }
    }

    property int _prevWallIdx: -1

    Connections {
        target: RoomState
        function onWallIndexChanged() {
            // freeze the outgoing frame, fade the new one in
            if (bg._prevWallIdx >= 0 && RoomState.walls?.length) {
                // ids are document-scope aliases, not object properties
                wallOld.source =
                    `../assets/bg/walls/${RoomState.walls[bg._prevWallIdx]}.png`;
                bg.wallFade = 0;
                Qt.callLater(() => bg.wallFade = 1);
            }
            bg._prevWallIdx = RoomState.wallIndex;
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