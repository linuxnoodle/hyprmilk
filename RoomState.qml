pragma Singleton

import QtQuick
import Quickshell
import "data/rooms.js" as RoomsData
import "data/manifest.js" as ManifestData
import "data/dialogue.js" as DialogueData
import "data/walls.js" as WallsData

QtObject {
    id: root

    // ---- static data (compiled to JS modules by tools/ — no runtime file IO) ----
    property var rooms: RoomsData.rooms
    property var manifest: ManifestData.manifest
    property var dialogue: DialogueData.dialogue
    property var walls: WallsData.walls.walls
    property int wallIndex: -1   // chosen once at boot (real game imagery)
    property int lastSayIndex: -1

    // ---- live state ----
    property int currentWs: 1
    readonly property var room: rooms[String(currentWs)] ?? null
    readonly property string roomId: room?.id ?? "hub"

    property bool voiceMuted: false
    property bool speaking: false   // dialogue typewriter active -> sprite mouth
    property bool dialogueVisible: false   // milk dialogue window present
    property bool girlVisible: false   // Milk-Chan sprite hidden by default (toggleGirl to show)
    property bool autoTalk: false   // periodic idle dialogue off by default (IPC/launcher still manual)
    property bool wallpaperFocused: true   // no window focused (desktop active)

    // sprite reseed trigger (bump to randomize pose/emotion/variant)
    property int spriteEpoch: 0
    property string spritePose: "arms_down"
    property string spriteEmotion: "neutral"
    property int spriteVariant: 1
    property int stateCursor: 0   // deterministic cycle position

    signal didChangeRoom(string roomId)
    signal dialogueRequested(var line)

    // ----------------------------------------------------------------
    function reseedSprite(pose, emotion) {
        const sprites = manifest.sprites;
        const keys = Object.keys(sprites);
        const poseKey = pose && sprites[pose] ? pose
            : keys[Math.floor(Math.random() * keys.length)];
        const emos = Object.keys(sprites[poseKey]);
        const emoKey = emotion && sprites[poseKey][emotion] ? emotion
            : emos[Math.floor(Math.random() * emos.length)];
        const bodies = sprites[poseKey][emoKey].bodies;
        spritePose = poseKey;
        spriteEmotion = emoKey;
        spriteVariant = bodies[Math.floor(Math.random() * bodies.length)];
        spriteEpoch++;
    }

    // hyprctl on this machine is a hyprlua shim that mangles bare dispatch
    // strings; use the raw hyprland socket instead (verified working).
    function dispatch(cmd) {
        Quickshell.execDetached(["python3", "-c",
            "import socket, os\n" +
            "sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')\n" +
            "p = f'/run/user/{os.getuid()}/hypr/{sig}/.socket.sock'\n" +
            "s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n" +
            "s.connect(p)\n" +
            "s.sendall('dispatch " + cmd + "'.encode())\n" +
            "s.close()"]);
    }

    // launcher/IPC action: toggle Milk-Chan visibility
    function toggleGirl() {
        girlVisible = !girlVisible;
    }

    // launcher/IPC action: toggle periodic idle dialogue
    function toggleAutoTalk() {
        autoTalk = !autoTalk;
    }

    // launcher action: cycle the wallpaper (red-dominant layer behind the
    // room plate's transparent windows)
    function cycleWallpaper() {
        if (!walls?.length)
            return;
        wallIndex = (wallIndex + 1) % walls.length;
    }

    function comboList() {
        const out = [];
        const sprites = manifest.sprites;
        for (const p of Object.keys(sprites))
            for (const e of Object.keys(sprites[p]))
                out.push([p, e]);
        return out;
    }

    function applySprite(p, e) {
        const bodies = manifest.sprites[p][e].bodies;
        spritePose = p;
        spriteEmotion = e;
        spriteVariant = bodies[Math.floor(Math.random() * bodies.length)];
        spriteEpoch++;
    }

    // click on the wallpaper cycles the girl's pose/emotion deterministically
    function nextState() {
        const combos = comboList();
        if (!combos.length)
            return;
        stateCursor = (stateCursor + 1) % combos.length;
        applySprite(combos[stateCursor][0], combos[stateCursor][1]);
    }


    function say(line) {
        dialogueRequested(line);
    }

    function sayRandom() {
        const lines = dialogue[roomId];
        if (!lines?.length)
            return;
        // avoid repeating the immediately-previous line (same object would
        // not retrigger the dialogue box, making it look frozen)
        let idx = Math.floor(Math.random() * lines.length);
        if (lines.length > 1 && idx === lastSayIndex)
            idx = (idx + 1) % lines.length;
        lastSayIndex = idx;
        say(lines[idx]);
    }


    function toggleVoice() {
        voiceMuted = !voiceMuted;
        const p = Quickshell.env("XDG_STATE_HOME") + "/hyprmilk";
        Quickshell.execDetached(["sh", "-c",
            `mkdir -p '${p}' && echo ${voiceMuted ? 1 : 0} > '${p}/voice`]);
    }

    // ----------------------------------------------------------------
    // wallpaper visual state is STABLE: switching workspaces must not re-roll it.
    // only explicit clicks (nextState) change the girl; dialogue still follows room.
    onCurrentWsChanged: {
        didChangeRoom(roomId);
    }

    Component.onCompleted: {
        // seed a wallpaper image immediately
        if (walls?.length)
            wallIndex = Math.floor(Math.random() * walls.length);
    }
}