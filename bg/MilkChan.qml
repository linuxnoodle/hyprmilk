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
    property real fadeOpacity: 1.0   // fast crossfade on pose/emotion change
    Behavior on fadeOpacity {
        NumberAnimation { duration: 110; easing.type: Easing.InOutQuad }
    }
    opacity: root.fadeOpacity

    // two-phase: fade out, swap frame (mid-window), fade back in
    Timer {
        id: fadeSwap
        interval: 130
        onTriggered: root.fadeOpacity = 1
    }

    readonly property string base: `../assets/sprites/${pose}/${emotion}`
    // sources are self-contained single expressions (one snapshot each)
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
            : (m && (m?.eyes[String(v)] ?? []).includes("open")
                ? `../assets/sprites/${pose}/${emotion}/${emotion}_eyes_closed.png` : "");
    }
    readonly property string eyesClosedSrc: eyesHalfSrc !== "" ? `../assets/sprites/${pose}/${emotion}/${emotion}_eyes_closed.png` : ""
    readonly property bool hasEyes: eyesOpenSrc !== ""
    // body: self-contained snapshot (no transient combos)
    readonly property string bodySrc: {
        const m = RoomState.manifest.sprites?.[pose]?.[emotion];
        const v = (m?.bodies ?? []).includes(variant) ? variant : (m?.bodies?.[0] ?? 1);
        return `../assets/sprites/${pose}/${emotion}/${emotion}_${v}.png`;
    }
    // mouth: own flap frames, else the pose's neutral emotion flap frames (game does this)
    readonly property string mouthClosedSrc: {
        const m = RoomState.manifest.sprites?.[pose]?.[emotion];
        const mouths = m?.mouths ?? [];
        return mouths.includes("closed")
            ? `../assets/sprites/${pose}/${emotion}/${emotion}_mouth_closed.png`
            : `../assets/sprites/${pose}/neutral/neutral_mouth_closed.png`;
    }
    readonly property string mouthHalfSrc: {
        const m = RoomState.manifest.sprites?.[pose]?.[emotion];
        const mouths = m?.mouths ?? [];
        // always flap: own frame when shipped, else the pose's neutral flap
        // (neutral has half+full for every pose, so no emotion is ever silent)
        if (mouths.includes("half"))
            return `../assets/sprites/${pose}/${emotion}/${emotion}_mouth_half.png`;
        return `../assets/sprites/${pose}/neutral/neutral_mouth_half.png`;
    }
    readonly property string mouthFullSrc: {
        const m = RoomState.manifest.sprites?.[pose]?.[emotion];
        const mouths = m?.mouths ?? [];
        if (mouths.includes("full"))
            return `../assets/sprites/${pose}/${emotion}/${emotion}_mouth_full.png`;
        return `../assets/sprites/${pose}/neutral/neutral_mouth_full.png`;
    }

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
            root.fadeOpacity = 0;   // fade out old frame...
            fadeSwap.restart();       // ...swap mid-window, fade back in
            root.pose = RoomState.spritePose;
            root.emotion = RoomState.spriteEmotion;
            root.variant = RoomState.spriteVariant;
        }
    }


    // gentle idle bob like the game's subtle motion — DISABLED: continuous
    // repaint flickers the layer under the cursor on some Qt/qs versions
    // SequentialAnimation on y {
    //     running: true
    //     loops: Animation.Infinite
    //     NumberAnimation { to: 6; duration: 3200; easing.type: Easing.InOutSine }
    //     NumberAnimation { to: 0; duration: 3200; easing.type: Easing.InOutSine }
    // }
}
