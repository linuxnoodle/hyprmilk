pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Global pointer position via the Hyprland IPC socket (Synoptik pattern):
// ONE persistent python client polls `cursorpos` at ~10Hz and streams to
// SplitParser — no process churn, no temp files.
Singleton {
    id: root

    property real gx: -1
    property real gy: -1
    readonly property bool ready: gx >= 0

    // poller only needed while the wallpaper can actually be seen AND parallax
    // is live — a focused window freezes parallax anyway, so kill the python
    // client (~10MB RSS + 10 wakeups/s) whenever one has focus. gx/gy keep
    // their last values while stopped, matching the parallax freeze design.
    readonly property bool active: Theme.parallaxEnabled && RoomState.wallpaperFocused

    Process {
        running: Cursor.active
        command: ["python3", "-u", "-c",
            "import socket, os, time\n" +
            "sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')\n" +
            "path = f'/run/user/{os.getuid()}/hypr/{sig}/.socket.sock'\n" +
            "while True:\n" +
            "    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n" +
            "    try:\n" +
            "        s.connect(path)\n" +
            "        s.sendall(b'cursorpos')\n" +
            "        data = b''\n" +
            "        while True:\n" +
            "            c = s.recv(256)\n" +
            "            if not c: break\n" +
            "            data += c\n" +
            "        print(data.decode('utf-8', errors='ignore').strip(), flush=True)\n" +
            "    except Exception: pass\n" +
            "    finally: s.close()\n" +
            "    time.sleep(0.1)\n"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(",");
                if (parts.length >= 2) {
                    const cx = parseFloat(parts[0]);
                    const cy = parseFloat(parts[1]);
                    if (!isNaN(cx) && !isNaN(cy)) {
                        root.gx = cx;
                        root.gy = cy;
                    }
                }
            }
        }
    }
}