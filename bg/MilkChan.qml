import Quickshell
import QtQuick
import ".."

// Milk-Chan sprite rig — replicates the game's LiveComposite:
//   body:   {emotion}_{variant}.png
//   eyes:   {emotion}_{variant}_eyes_{open,half}.png + shared eyes_closed
//   mouth:  {emotion}_mouth_{closed,half,full}.png
// Blink: open -> (2..6s random) -> half (.1) -> closed (.2) -> half (.1) -> open
// Talk:  mouth half (.1) <-> full (.1) while `speaking`, else closed
Item {
    id: root

    property string pose: RoomState.spritePose
    property string emotion: RoomState.spriteEmotion
    property int variant: RoomState.spriteVariant
    property bool speaking: false
    property real scale: 0.5

    readonly property string base: `../assets/sprites/${pose}/${emotion}`
    readonly property var manifest: RoomState.manifest.sprites?.[pose]?.[emotion] ?? null
    // clamp variant to what this pose/emotion actually ships (kills transient
    // combos while pose/emotion/variant update in sequence)
    readonly property int effVariant: (manifest?.bodies ?? []).includes(variant)
        ? variant : (manifest?.bodies?.[0] ?? 1)
    // eye sources: self-contained single expressions so pose/emotion/variant
    // are read as one snapshot (no mixed-staleness intermediate paths)
    readonly property string eyesOpenSrc: {
        const m = RoomState.manifest.sprites?.[pose]?.[emotion];
        const v = (m?.bodies ?? []).includes(variant) ? variant : (m?.bodies?.[0] ?? 1);
        return (m?.eyes[String(v)] ?? []).includes("open")
            ? `../assets/sprites/${pose}/${emotion}/${emotion}_${v}_eyes_open.png` : "";
    }
    readonly property string eyesHalfSrc: {
        const m = RoomState.manifest.sprites?.[pose]?.[emotion];
        const v = (m?.bodies ?? []).includes(variant) ? variant : (m?.bodies?.[0] ?? 1);
        return (m?.eyes[String(v)] ?? []).includes("half")
            ? `../assets/sprites/${pose}/${emotion}/${emotion}_${v}_eyes_half.png`
            : (m ? `../assets/sprites/${pose}/${emotion}/${emotion}_eyes_closed.png` : "");
    }
    readonly property string eyesClosedSrc: eyesHalfSrc !== "" ? `../assets/sprites/${pose}/${emotion}/${emotion}_eyes_closed.png` : ""
    readonly property bool hasEyes: eyesOpenSrc !== ""
    readonly property string bodySrc: `${base}/${emotion}_${effVariant}.png`
    // mouth: own flap frames, else the pose's neutral emotion flap frames (game does this)
    readonly property string neutralMouth: `../assets/sprites/${pose}/neutral`
    readonly property var mouthSet: manifest?.mouths ?? []
    readonly property string mouthClosedSrc: mouthSet.includes("closed") ? `${base}/${emotion}_mouth_closed.png` : `${neutralMouth}/neutral_mouth_closed.png`
    readonly property string mouthHalfSrc: mouthSet.includes("half") ? `${base}/${emotion}_mouth_half.png`
        : mouthSet.includes("full") ? `${neutralMouth}/neutral_mouth_half.png` : ""
    readonly property string mouthFullSrc: mouthSet.includes("full") ? `${base}/${emotion}_mouth_full.png`
        : mouthSet.includes("half") ? `${neutralMouth}/neutral_mouth_full.png` : ""

    // game sprite is 1959x1027; keep native ratio, scale down
    implicitWidth: 1959 * scale
    implicitHeight: 1027 * scale

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: false
        cache: false
        source: root.bodySrc
    }

    Image {
        id: eyes
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: false
        cache: false
        property string phase: "open"   // open | half | closed
        visible: root.eyesOpenSrc !== ""
        source: phase === "open" ? root.eyesOpenSrc
            : phase === "half" ? root.eyesHalfSrc
            : root.eyesClosedSrc
    }

    Image {
        id: mouth
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: false
        cache: false
        property string phase: "closed" // closed | half | full
        source: phase === "half" ? root.mouthHalfSrc
            : phase === "full" ? root.mouthFullSrc
            : root.mouthClosedSrc
    }

    // ---- blink loop (chained timers; no SequenceContainer in qs 0.3) ----
    Timer {
        id: blinkHold
        interval: 2000 + Math.random() * 4000
        running: root.eyesOpenSrc !== ""
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
        repeat: root.speaking && root.mouthHalfSrc !== "" && root.mouthFullSrc !== ""
        running: root.speaking && root.mouthHalfSrc !== "" && root.mouthFullSrc !== ""
        onTriggered: mouth.phase = mouth.phase === "half" ? "full" : "half"
        onRunningChanged: if (!running) mouth.phase = "closed"
    }

    // reseeds from RoomState (workspace change etc.)
    Connections {
        target: RoomState
        function onSpriteEpochChanged() {
            root.pose = RoomState.spritePose;
            root.emotion = RoomState.spriteEmotion;
            root.variant = RoomState.spriteVariant;
        }
    }

    // gentle idle bob like the game's subtle motion
    SequentialAnimation on y {
        running: true
        loops: Animation.Infinite
        NumberAnimation { to: 6; duration: 3200; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 3200; easing.type: Easing.InOutSine }
    }
}
