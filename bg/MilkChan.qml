import Quickshell
import QtQuick
import ".."

// Milk-Chan sprite rig — replicates the game's LiveComposite:
//   body:   {emotion}_{variant}.png
//   eyes:   {emotion}_{variant}_eyes_{open,half}.png + shared eyes_closed
//   mouth:  {emotion}_mouth_{closed,half,full}.png
// Blink: open -> (2..6s random) -> half (.1) -> closed (.2) -> half (.1) -> open
// Talk:  mouth half (.1) <-> full (.1) while `speaking`, else closed
// Crossfade: a frozen ghost of the old pose fades out while the new fades in.
Item {
    id: root

    property string pose: RoomState.spritePose
    property string emotion: RoomState.spriteEmotion
    property int variant: RoomState.spriteVariant
    property bool speaking: false
    property real scale: 0.5
    // when false: unload all sprite textures + stop blink/talk timers.
    // Bg binds this to (girlVisible && main monitor) so hidden or secondary
    // monitors hold zero decoded frames.
    property bool live: true

    // ---- parametrized source helpers (also used by the ghost) ----
    function wrap(p, e, v) {
        return RoomState.manifest.sprites?.[p]?.[e] ?? null;
    }
    function bodySrc(p, e, v) {
        const m = wrap(p, e, v);
        if (!m)
            return "";
        const vv = (m?.bodies ?? []).includes(v) ? v : (m?.bodies?.[0] ?? 1);
        return `../assets/sprites/${p}/${e}/${e}_${vv}.png`;
    }
    function eyesOpenSrc(p, e, v) {
        const m = wrap(p, e, v);
        if (!m)
            return "";
        const vv = (m?.bodies ?? []).includes(v) ? v : (m?.bodies?.[0] ?? 1);
        return (m?.eyes[String(vv)] ?? []).includes("open")
            ? `../assets/sprites/${p}/${e}/${e}_${vv}_eyes_open.png` : "";
    }
    function eyesHalfSrc(p, e, v) {
        const m = wrap(p, e, v);
        if (!m)
            return "";
        const vv = (m?.bodies ?? []).includes(v) ? v : (m?.bodies?.[0] ?? 1);
        return (m?.eyes[String(vv)] ?? []).includes("half")
            ? `../assets/sprites/${p}/${e}/${e}_${vv}_eyes_half.png` : "";
    }
    function eyesClosedSrc(p, e, v) {
        const m = wrap(p, e, v);
        if (!m)
            return "";
        const vv = (m?.bodies ?? []).includes(v) ? v : (m?.bodies?.[0] ?? 1);
        return (m?.eyes[String(vv)] ?? []).length > 0
            ? `../assets/sprites/${p}/${e}/${e}_eyes_closed.png` : "";
    }
    function eyesPhaseSrc(p, e, v, phase) {
        if (phase === "open") return eyesOpenSrc(p, e, v);
        if (phase === "half") return eyesHalfSrc(p, e, v);
        if (phase === "closed") return eyesClosedSrc(p, e, v);
        return "";
    }
    function mouthSrc(p, e, phase) {
        const m = wrap(p, e, 0);
        if (!m)
            return "";
        const mouths = m.mouths ?? [];
        if (phase === "closed")
            return mouths.includes("closed")
                ? `../assets/sprites/${p}/${e}/${e}_mouth_closed.png`
                : `../assets/sprites/${p}/neutral/neutral_mouth_closed.png`;
        if (phase === "half")
            return mouths.includes("half")
                ? `../assets/sprites/${p}/${e}/${e}_mouth_half.png`
                : `../assets/sprites/${p}/neutral/neutral_mouth_half.png`;
        if (phase === "full")
            return mouths.includes("full")
                ? `../assets/sprites/${p}/${e}/${e}_mouth_full.png`
                : `../assets/sprites/${p}/neutral/neutral_mouth_full.png`;
        return "";
    }


    implicitWidth: 1959 * scale
    implicitHeight: 1027 * scale

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: false
        cache: true
        source: root.live ? root.bodySrc(root.pose, root.emotion, root.variant) : ""
    }
    Image {
        id: eyes
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: false
        cache: true
        property string phase: "open"
        visible: root.live && root.eyesOpenSrc(root.pose, root.emotion, root.variant) !== ""
        source: root.live ? root.eyesPhaseSrc(root.pose, root.emotion, root.variant, phase) : ""
    }
    Image {
        id: mouth
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: false
        cache: true
        property string phase: "closed"
        source: root.live ? root.mouthSrc(root.pose, root.emotion, phase) : ""
    }

    // ---- blink loop ----
    Timer {
        id: blinkHold
        interval: 2000 + Math.random() * 4000
        running: root.live && root.visible
                && root.eyesOpenSrc(root.pose, root.emotion, root.variant) !== ""
                && RoomState.wallpaperFocused   // frozen in background mode
        onTriggered: {
            eyes.phase = "half";
            t1.start();
        }
    }
    Timer { id: t1; interval: 100; onTriggered: { eyes.phase = "closed"; t2.start(); } }
    Timer { id: t2; interval: 200; onTriggered: { eyes.phase = "half"; t3.start(); } }
    Timer {
        id: t3
        interval: 100
        onTriggered: {
            eyes.phase = "open";
            blinkHold.interval = 2000 + Math.random() * 4000;
            blinkHold.start();
        }
    }

    // ---- talk flap ----
    Timer {
        id: talk
        interval: 100
        repeat: root.live && root.speaking && RoomState.wallpaperFocused
                && root.mouthSrc(root.pose, root.emotion, "half") !== ""
                && root.mouthSrc(root.pose, root.emotion, "full") !== ""
        running: repeat
        onTriggered: mouth.phase = mouth.phase === "half" ? "full" : "half"
        onRunningChanged: if (!running) mouth.phase = "closed"
    }

    // reseeds from RoomState: freeze old pose as ghost, swap, crossfade
    Connections {
        target: RoomState
        function onSpriteEpochChanged() {
            // instant swap (crossfade was disruptive; image is small enough)
            root.pose = RoomState.spritePose;
            root.emotion = RoomState.spriteEmotion;
            root.variant = RoomState.spriteVariant;
        }
    }
}