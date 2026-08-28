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

    // ---- parametrized source helpers (also used by the ghost) ----
    function wrap(p, e, v) {
        return RoomState.manifest.sprites?.[p]?.[e] ?? null;
    }
    function bodySrc(p, e, v) {
        const m = wrap(p, e, v);
        const vv = (m?.bodies ?? []).includes(v) ? v : (m?.bodies?.[0] ?? 1);
        return `../assets/sprites/${p}/${e}/${e}_${vv}.png`;
    }
    function eyesOpenSrc(p, e, v) {
        const m = wrap(p, e, v);
        const vv = (m?.bodies ?? []).includes(v) ? v : (m?.bodies?.[0] ?? 1);
        return (m?.eyes[String(vv)] ?? []).includes("open")
            ? `../assets/sprites/${p}/${e}/${e}_${vv}_eyes_open.png` : "";
    }
    function eyesHalfSrc(p, e, v) {
        const m = wrap(p, e, v);
        const vv = (m?.bodies ?? []).includes(v) ? v : (m?.bodies?.[0] ?? 1);
        return (m?.eyes[String(vv)] ?? []).includes("half")
            ? `../assets/sprites/${p}/${e}/${e}_${vv}_eyes_half.png` : "";
    }
    function eyesClosedSrc(p, e, v) {
        const m = wrap(p, e, v);
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
        const mouths = wrap(p, e, 0)?.mouths ?? [];
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

    // ---- live frame (new pose during a crossfade) ----
    property real fadeOpacity: 1.0
    Behavior on fadeOpacity {
        NumberAnimation { duration: 110; easing.type: Easing.InOutQuad }
    }

    Timer {
        id: fadeIn
        interval: 130   // after old has dropped out, bring the new in
        onTriggered: root.fadeOpacity = 1
    }

    // ---- ghost of the previous pose, faded out during the crossfade ----
    property string oldPose: ""
    property string oldEmotion: ""
    property int oldVariant: 1
    property string oldEyesPhase: "open"
    property string oldMouthPhase: "closed"
    property real ghostOpacity: 0
    Behavior on ghostOpacity {
        NumberAnimation { duration: 260; easing.type: Easing.InOutQuad }
    }
    Timer {
        id: ghostDrop
        interval: 270
        onTriggered: root.ghostOpacity = 0
    }

    implicitWidth: 1959 * scale
    implicitHeight: 1027 * scale

    Item {
        opacity: root.fadeOpacity
        anchors.fill: parent

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
            source: root.bodySrc(root.pose, root.emotion, root.variant)
        }
        Image {
            id: eyes
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
            property string phase: "open"
            visible: root.eyesOpenSrc(root.pose, root.emotion, root.variant) !== ""
            source: root.eyesPhaseSrc(root.pose, root.emotion, root.variant, phase)
        }
        Image {
            id: mouth
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
            property string phase: "closed"
            source: root.mouthSrc(root.pose, root.emotion, phase)
        }
    }

    // ghost: frozen old frame on top while it fades away
    Item {
        opacity: root.ghostOpacity
        anchors.fill: parent
        z: 2
        enabled: false

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
            source: root.bodySrc(root.oldPose, root.oldEmotion, root.oldVariant)
        }
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
            visible: root.eyesOpenSrc(root.oldPose, root.oldEmotion, root.oldVariant) !== ""
            source: root.eyesPhaseSrc(root.oldPose, root.oldEmotion, root.oldVariant,
                                     root.oldEyesPhase)
        }
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: false
            cache: false
            source: root.mouthSrc(root.oldPose, root.oldEmotion, root.oldMouthPhase)
        }
    }

    // ---- blink loop ----
    Timer {
        id: blinkHold
        interval: 2000 + Math.random() * 4000
        running: root.eyesOpenSrc(root.pose, root.emotion, root.variant) !== ""
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
        repeat: root.speaking && root.mouthSrc(root.pose, root.emotion, "half") !== ""
                     && root.mouthSrc(root.pose, root.emotion, "full") !== ""
        running: repeat
        onTriggered: mouth.phase = mouth.phase === "half" ? "full" : "half"
        onRunningChanged: if (!running) mouth.phase = "closed"
    }

    // reseeds from RoomState: freeze old pose as ghost, swap, crossfade
    Connections {
        target: RoomState
        function onSpriteEpochChanged() {
            root.oldPose = root.pose;
            root.oldEmotion = root.emotion;
            root.oldVariant = root.variant;
            root.oldEyesPhase = eyes.phase;
            root.oldMouthPhase = mouth.phase;
            root.ghostOpacity = 1;      // old frame on top
            ghostDrop.restart();        // ...fades out over 260ms
            root.fadeOpacity = 0;       // new frame drops out...
            fadeIn.restart();           // ...then crossfades back in
            root.pose = RoomState.spritePose;
            root.emotion = RoomState.spriteEmotion;
            root.variant = RoomState.spriteVariant;
        }
    }
}