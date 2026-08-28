pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// global pointer position (px) — hyprctl cursorpos polled into a temp file.
// only runs while parallax is enabled (Theme.parallaxEnabled).
Singleton {
    id: root

    property real gx: 0
    property real gy: 0
    property bool ready: false

    readonly property bool active: Theme.parallaxEnabled

    FileView {
        id: fv
        path: Cursor.active ? "/tmp/hyprmilk-cursor" : ""
        blockLoading: true
    }

    Timer {
        interval: 33
        running: Cursor.active
        repeat: true
        onTriggered: {
            const t = fv.text() ?? "";
            const m = /^(-?\d+)[, ]+(-?\d+)/.exec(t.trim());
            if (m) {
                root.gx = Number(m[1]);
                root.gy = Number(m[2]);
                root.ready = true;
            }
        }
    }

    property var _proc: null

    function ensure() {
        if (!root.active)
            return;
        if (_proc && _proc.running)
            return;
        _proc = procComp.createObject(root);
        // self-terminates when the qs parent dies (no orphan loops)
        _proc.command = ["sh", "-c",
            "while kill -0 $PPID 2>/dev/null; do " +
            "hyprctl cursorpos > /tmp/hyprmilk-cursor 2>/dev/null; sleep 0.033; done"];
        _proc.running = true;
    }

    property Component procComp: Component {
        Process {}
    }

    Component.onCompleted: ensure()
}