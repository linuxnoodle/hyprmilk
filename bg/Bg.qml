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

    // content moves OPPOSITE the cursor; nearer layers (higher depth) more.
    // background mode: when a window is focused the target freezes at its
    // last value (parallax + idle animation hold still until focus returns)
    property real _frozenX: 0
    property real _frozenY: 0

    readonly property real targetX: par
        ? (RoomState.wallpaperFocused ? (cursorNormX - 0.5) * -overscanX : _frozenX)
        : 0
    readonly property real targetY: par
        ? (RoomState.wallpaperFocused ? (cursorNormY - 0.5) * -overscanY : _frozenY)
        : 0

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

    Connections {
        target: RoomState
        function onWallpaperFocusedChanged() {
            if (!RoomState.wallpaperFocused) {
                // snapshot the resting offset so parallax freezes in place
                bg._frozenX = bg.smoothX;
                bg._frozenY = bg.smoothY;
            }
        }
    }

    // per-depth offset (depth 1 = room plate reference)
    function layerX(depth) { return smoothX * depth; }
    function layerY(depth) { return smoothY * depth; }

    Timer {
        interval: 64
        running: true
        repeat: true
        // breathing pauses while a window is focused (background mode)
        onTriggered: if (RoomState.wallpaperFocused) bg.breathPhase += 0.045
    }

    // click = next girl state
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

        // crossfade: the OLD frame fades out over the new one, which is kept
        // fully opaque so it decodes eagerly (no opacity-0 lazy-decode pop).
        Image {
            id: wallOld
            z: 2                      // above wallNew during the transition
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            opacity: 1
            visible: source !== ""
        }
        Image {
            id: wallNew
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            source: RoomState.wallIndex >= 0
                ? `../assets/bg/walls/${RoomState.walls[RoomState.wallIndex]}.png`
                : "../assets/bg/walls/room.png"
            asynchronous: false
        }

        // fades the outgoing frame away, revealing the (always-decoded) new one
        NumberAnimation {
            id: wallFadeOut
            target: wallOld; property: "opacity"
            from: 1; to: 0
            duration: 700
            easing.type: Easing.InOutQuad
        }
        Timer {
            id: wallFadeReset
            interval: 720
            onTriggered: wallOld.z = 0
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
            // crossfade: layer the outgoing frame above, fade it away over
            // the always-decoded new one
            if (bg._prevWallIdx >= 0 && RoomState.walls?.length) {
                wallOld.source =
                    `../assets/bg/walls/${RoomState.walls[bg._prevWallIdx]}.png`;
                wallOld.opacity = 1;
                wallOld.z = 2;
                wallFadeReset.restart();
                wallFadeOut.start();
            }
            bg._prevWallIdx = RoomState.wallIndex;
        }
    }

    Component.onCompleted: {
        bg._prevWallIdx = RoomState.wallIndex;
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