pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// tiny audio engine: one-shot sfx + room ambient loop, both through mpv
QtObject {
    id: root

    // speech on (talking loop), ambient stays off
    property bool enabled: true          // gate for speech + one-shots
    property bool ambientEnabled: false  // room ambience loops: off

    property bool voiceMuted: false   // mirrors RoomState.voiceMuted

    // dialogue sfx only when the desktop/wallpaper is focused
    function focusOk() { return RoomState.wallpaperFocused; }

    // ---- talking loop: narr.ogg while a line is on screen ----
    property var _talk: null
    property int _talkSeq: 0
    property string _talkTok: ""

    function speakLoop() {
        if (!enabled || voiceMuted)
            return;
        speakLoopStop();
        // unique token per spawn: stale kills can't touch the fresh instance
        _talkTok = "hyprmilk-talk-" + (++_talkSeq);
        _talk = procComp.createObject(root);
        _talk.command = ["mpv", "--no-video", "--really-quiet", "--loop-file=inf",
                         "--volume=55", `--force-media-title=${_talkTok}`,
                         Qt.resolvedUrl("assets/audio/ui/narr.ogg").toString().replace("file://", "")];
        _talk.running = true;
    }

    function speakLoopStop() {
        // immediate, token-scoped kill: no delayed sleep, no cross-line races
        if (_talkTok !== "") {
            Quickshell.execDetached(["sh", "-c",
                `pkill -f ${_talkTok} 2>/dev/null || true`]);
            _talkTok = "";
        }
        if (_talk) {
            const proc = _talk;     // free the wrapper object (no per-line leak)
            _talk = null;
            proc.running = false;
            proc.destroy();
        }
    }

    function sfx(path, volume) {
        if (!enabled || voiceMuted || !focusOk())
            return;
        const p = procComp.createObject(root);
        p.command = ["mpv", "--no-video", "--really-quiet",
                     `--volume=${volume ?? 100}`, Qt.resolvedUrl(path).toString().replace("file://", "")];
        p.running = true;
        p.exited.connect(() => p.destroy());
    }

    function randomNice() {
        if (!enabled || !focusOk())
            return;
        const n = 1 + Math.floor(Math.random() * 7);
        sfx(`assets/audio/ui/${n}.ogg`, 60);
    }

    // ---- room ambience: starts at volume 0; focus fades it in/out slowly ----
    property var _ambient: null
    property string _ambientPath: ""

    function _sock() { return "/tmp/hyprmilk-amb.sock"; }

    function _mpvSet(json) {
        Quickshell.execDetached(["sh", "-c",
            `echo '${json}' > ${_sock()} 2>/dev/null || true`]);
    }

    // cancel any in-flight fade
    function _fadeCleanup() {
        Quickshell.execDetached(["sh", "-c",
            "pkill -f hyprmilk-fade 2>/dev/null || true"]);
    }

    // stepped ramp over the mpv IPC socket (JSON-RPC), then pause/resume
    function _fadeTo(vol0, vol1, steps, stepMs, paused) {
        _fadeCleanup();
        const seq = [];
        const n = Math.max(1, steps);
        for (let i = 1; i <= n; i++) {
            const v = Math.round(vol0 + (vol1 - vol0) * i / n);
            seq.push(`echo '{\"command\":[\"set_property\",\"volume\",${v}]}' > ${_sock()} 2>/dev/null; sleep 0.${stepMs}`);
        }
        seq.push(`echo '{\"command\":[\"set_property\",\"pause\",${paused ? "true" : "false"}]}' > ${_sock()} 2>/dev/null || true`);
        Quickshell.execDetached(["sh", "-c", `hyprmilk-fade; ${seq.join("; ")}`]);
    }

    // very slow ramp-up so momentary wallpaper focus never becomes audible
    function setAmbientFocus(focused) {
        if (!focused) {
            if (_ambient)
                _fadeTo(100, 0, 8, 12, true);   // ~1s down, then pause
            return;
        }
        if (_ambientPath) {
            if (!_ambient || !_ambient.running)
                startAmbient(_ambientPath);
            _fadeTo(1, 100, 24, 25, false);      // ~6s ramp up
        }
    }

    function startAmbient(path) {
        _ambient = procComp.createObject(root);
        _ambient.command = ["mpv", "--no-video", "--really-quiet", "--loop-file=inf",
                            "--volume=0", "--input-ipc-server=" + _sock(),
                            Qt.resolvedUrl("assets/audio/" + path).toString().replace("file://", "")];
        _ambient.running = true;
    }

    function ambient(path) {
        if (!enabled || !ambientEnabled) {
            stopAmbient();
            return;
        }
        if (_ambientPath === path)
            return;
        stopAmbient();
        if (!path)
            return;
        _ambientPath = path;
        startAmbient(path);
        // starts silent; only fades in when the wallpaper is focused
        _fadeCleanup();
    }

    function stopAmbient() {
        _fadeCleanup();
        if (_ambient) {
            const proc = _ambient;
            _ambient = null;
            Quickshell.execDetached(["sh", "-c",
                `pkill -f "loop-file=inf.*${_ambientPath.split("/").pop()}" || true`]);
            proc.running = false;
            proc.destroy();
        }
        _ambientPath = "";
        Quickshell.execDetached(["sh", "-c", `rm -f ${_sock()} || true`]);
    }

    property var _voice: null

    function voice(path) {
        if (!enabled || voiceMuted || !focusOk())
            return;
        if (_voice) {
            const old = _voice;
            _voice = null;
            old.running = false;
            old.destroy();
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
