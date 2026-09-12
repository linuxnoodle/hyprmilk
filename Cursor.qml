pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Global pointer position via the Hyprland IPC socket (Synoptik pattern):
// ONE persistent python client polls `cursorpos` and streams to SplitParser.
// Battery: the client only emits on CHANGE and its poll rate decays from
// 10Hz (moving) to 1Hz (at rest) — an idle cursor has nothing to parallax,
// so it must not wake the machine. The poller also dies entirely while a
// window has focus (parallax frozen anyway); gx/gy keep their last values,
// matching the freeze design.
Singleton {
    id: root

    property real gx: -1
    property real gy: -1
    readonly property bool ready: gx >= 0

    readonly property bool active: Theme.parallaxEnabled && RoomState.wallpaperFocused

    Process {
        running: Cursor.active
        command: ["python3", "-u", "-c",
            "import socket, os, time\n" +
            "sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')\n" +
            "path = f'/run/user/{os.getuid()}/hypr/{sig}/.socket.sock'\n" +
            "last = ''\n" +
            "idle = 0\n" +
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
            "        pos = data.decode('utf-8', errors='ignore').strip()\n" +
            "        if pos != last:\n" +
            "            last = pos\n" +
            "            idle = 0\n" +
            "            print(pos, flush=True)\n" +
            "        else:\n" +
            "            idle += 1\n" +
            "    except Exception: pass\n" +
            "    finally: s.close()\n" +
            "    # 10Hz while moving, backs off to 1Hz at rest\n" +
            "    if idle < 20: delay = 0.1\n" +
            "    elif idle < 60: delay = 0.25\n" +
            "    elif idle < 240: delay = 0.5\n" +
            "    else: delay = 1.0\n" +
            "    time.sleep(delay)"]
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
