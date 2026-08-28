pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// tiny audio engine: one-shot sfx + room ambient loop, both through mpv
QtObject {
    id: root

    // master audio switch — mpv-based sfx/ambient/voice. off for now.
    property bool enabled: false

    property bool voiceMuted: false   // mirrors RoomState.voiceMuted

    function sfx(path, volume) {
        if (!enabled || voiceMuted)
            return;
        const p = procComp.createObject(root);
        p.command = ["mpv", "--no-video", "--really-quiet",
                     `--volume=${volume ?? 100}`, Qt.resolvedUrl(path).toString().replace("file://", "")];
        p.running = true;
        p.exited.connect(() => p.destroy());
    }

    function randomNice() {
        if (!enabled)
            return;
        const n = 1 + Math.floor(Math.random() * 7);
        sfx(`assets/audio/ui/${n}.ogg`, 60);
    }

    property var _ambient: null
    property string _ambientPath: ""

    function ambient(path) {
        if (!enabled) {
            stopAmbient();
            return;
        }
        if (_ambientPath === path)
            return;
        stopAmbient();
        if (!path)
            return;
        _ambientPath = path;
        _ambient = procComp.createObject(root);
        _ambient.command = ["mpv", "--no-video", "--really-quiet", "--loop-file=inf",
                            Qt.resolvedUrl("assets/audio/" + path).toString().replace("file://", "")];
        _ambient.running = true;
    }

    function stopAmbient() {
        if (_ambient) {
            Quickshell.execDetached(["sh", "-c",
                `pkill -f "loop-file=inf.*${_ambientPath.split("/").pop()}" || true`]);
            _ambient = null;
        }
        _ambientPath = "";
    }

    property var _voice: null

    function voice(path) {
        if (!enabled || voiceMuted)
            return;
        if (_voice) {
            Quickshell.execDetached(["sh", "-c",
                `pkill -f "${path}" || true`]);
        }
        _voice = procComp.createObject(root);
        _voice.command = ["mpv", "--no-video", "--really-quiet",
                           Qt.resolvedUrl("assets/audio/" + path).toString().replace("file://", "")];
        _voice.running = true;
        _voice.exited.connect(() => _voice.destroy());
    }

    property Component procComp: Component {
        Process {}
    }
}
