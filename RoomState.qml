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

    // ---- live state ----
    property int currentWs: 1
    readonly property var room: rooms[String(currentWs)] ?? null
    readonly property string roomId: room?.id ?? "hub"

    property int plateIndex: 0
    property bool voiceMuted: false
    property bool speaking: false   // dialogue typewriter active -> sprite mouth

    // sprite reseed trigger (bump to randomize pose/emotion/variant)
    property int spriteEpoch: 0
    property string spritePose: "arms_down"
    property string spriteEmotion: "neutral"
    property int spriteVariant: 1
    property int stateCursor: 0   // deterministic cycle position

    signal didChangeRoom(string roomId)
    signal dialogueRequested(var line)
    signal wallChanged(int index)

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

    // launcher action: cycle the wallpaper (red-dominant layer behind the
    // room plate's transparent windows)
    function cycleWallpaper() {
        if (!walls?.length)
            return;
        wallIndex = (wallIndex + 1) % walls.length;
        wallChanged(wallIndex);
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

    function randomPlate() {
        const plates = room?.plates ?? [];
        if (!plates.length)
            return;
        plateIndex = Math.floor(Math.random() * plates.length);
    }

    function say(line) {
        dialogueRequested(line);
    }

    function sayRandom() {
        const lines = dialogue[roomId];
        if (!lines?.length)
            return;
        const line = lines[Math.floor(Math.random() * lines.length)];
        say(line);
    }

    function sayRoomIntro(roomId) {
        // one distilled line so textboxes always appear on room entry
        const lines = dialogue[roomId];
        if (!lines?.length)
            return;
        const picks = lines.filter(l => l.speaker === "narr");
        const line = (picks.length ? picks : lines)[
            Math.floor(Math.random() * (picks.length ? picks.length : lines.length))];
        say(line);
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