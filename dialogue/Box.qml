import QtQuick
import ".."

// VN dialogue box — game GUI frame, typewriter reveal, ties sprite mouth
Item {
    id: root

    readonly property real uiScale: Math.max(1, Math.min(1.6,
        (root.parent?.width ?? 1920) / 2560))

    property var line: null
    property bool speaking: false
    property string fullText: line?.text ?? ""
    property int shownChars: 0

    visible: false
    opacity: 0
    implicitWidth: Math.min(Math.round(1100 * uiScale),
        parent ? parent.width * 0.7 : 1100)
    implicitHeight: Math.round(150 * uiScale)

    // frame: game gui/frame.png, stretched 9-slice-ish (borders preserved)
    BorderImage {
        anchors.fill: parent
        source: "../assets/gui/frame.png"
        border.left: 24
        border.right: 24
        border.top: 24
        border.bottom: 24
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
        opacity: 0.92
    }

    Text {
        id: body
        anchors {
            fill: parent
            margins: Math.round(28 * root.uiScale)
        }
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(21 * root.uiScale)
        color: Theme.accent   // same red as the UI outlines
        text: root.fullText.slice(0, root.shownChars)
        smooth: false
    }

    onLineChanged: {
        if (!line)
            return;
        shownChars = 0;
        speaking = true;
        RoomState.speaking = true;
        RoomState.dialogueVisible = true;
        visible = true;
        opacity = 1;
        typeTimer.start();
        Sfx.randomNice();
        if (line.sfx)
            Sfx.sfx("assets/audio/" + line.sfx.replace(/^audio\//, ""), 70);
    }

    function finish() {
        speaking = false;
        shownChars = fullText.length;
        typeTimer.stop();
        hideTimer.restart();
        // keep RoomState.speaking true: text is still on screen (mouth flaps)
    }

    Timer {
        id: typeTimer
        interval: 28 // ~35 cps, game feels slower than default
        repeat: true
        running: root.speaking
        onTriggered: {
            if (root.shownChars >= root.fullText.length) {
                root.finish();
                stop();
            } else {
                root.shownChars++;
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 6000
        onTriggered: {
            hideAnim.start();
        }
    }

    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: Theme.animSlow }
        ScriptAction {
            script: {
                root.visible = false;
                RoomState.speaking = false;          // mouth stops once text leaves
                RoomState.dialogueVisible = false;   // unmaps the dialogue window
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // skip / advance
            if (root.speaking) {
                root.finish();
            } else {
                RoomState.sayRandom();
            }
        }
    }

    Connections {
        target: RoomState
        function onDialogueRequested(line) {
            // null-then-set: re-emits with the SAME line object must still
            // retrigger onLineChanged (same-object reassign doesn't notify)
            root.line = null;
            root.line = line;
        }
    }
}
