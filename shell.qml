import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import "bg" as Bg
import "bar" as Bar
import "dialogue" as Dlg
import "launcher" as L
import "notifs" as N
import "osd" as O
import "music" as M
import "controlcenter" as Cc

ShellRoot {

    // the game's own dialogue font (gui.text_font = 122.ttf, "Retro Gaming")
    // FontLoader registers it app-side; we also install it system-wide in
    // tools/install.sh so the family name always resolves.
    FontLoader {
        id: gameFont
        source: "assets/fonts/game-122.ttf"
        onStatusChanged: if (status === FontLoader.Ready && gameFont.name !== "")
            Theme.gameFontFamily = gameFont.name
    }
    // static fallback: never leave text on a default font
    function ensureFont() {
        if (Theme.gameFontFamily === "")
            Theme.gameFontFamily = "Retro Gaming"
    }

    // widest monitor = the "main" screen (girl + dialogue live here)
    function mainScreenInfo() {
        const screens = Quickshell.screens;
        let best = screens[0];
        for (let i = 1; i < screens.length; ++i)
            if (screens[i].width > best.width)
                best = screens[i];
        return best;
    }

    // background-mode focus + cursor source: ONE python helper. Listens to
    // socket2, re-queries ground truth (j/activewindow) on relevant events,
    // streams "F 1/0" focus transitions and "C x,y" cursor samples (only
    // while wallpaper-focused — cursor polling idles when a window has
    // focus). Replaces both the old Cursor poller process and Quickshell's
    // Hyprland.activeToplevel, whose hydration wedged on a long-lived
    // instance (Quickshell 0.3.1 + Hyprland 0.56.2) and froze the parallax
    // permanently ON; raw-payload parsing alone misses the empty-workspace
    // unfreeze. All state flows through this one process, so hot-reloads
    // can't desync QML-driven process management.
    Process {
        running: true
        command: ["python3", "-u", "-c",
            "import socket, os, json, time, select, ctypes, signal\n" +
            "ctypes.CDLL('libc.so.6', use_errno=True).prctl(1, signal.SIGTERM)\n" +
            "sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')\n" +
            "base = f\"/run/user/{os.getuid()}/hypr/{sig}\"\n" +
            "EV = ('activewindow', 'activewindowv2', 'workspace', 'workspacev2',\n" +
            "      'focusedmon', 'openwindow', 'closewindow', 'movewindow',\n" +
            "      'changefloatingmode', 'activespecial')\n" +
            "def q(cmd):\n" +
            "    try:\n" +
            "        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n" +
            "        s.settimeout(2)\n" +
            "        s.connect(base + '/.socket.sock')\n" +
            "        s.sendall(cmd)\n" +
            "        data = b''\n" +
            "        while True:\n" +
            "            c = s.recv(65536)\n" +
            "            if not c: break\n" +
            "            data += c\n" +
            "        s.close()\n" +
            "        return data\n" +
            "    except Exception:\n" +
            "        return None\n" +
            "def qfocus():\n" +
            "    # wallpaper showing <=> the FOCUSED monitor's active workspace has no\n" +
            "    # mapped clients. j/activewindow is globally sticky (reports the last\n" +
            "    # window even after mouse crossover to an empty monitor), so it cannot\n" +
            "    # answer this; monitors+clients can.\n" +
            "    try:\n" +
            "        mon = json.loads(q(b'j/monitors') or '[]')\n" +
            "        ws = None\n" +
            "        for m in mon:\n" +
            "            if m.get('focused'):\n" +
            "                ws = (m.get('activeWorkspace') or {}).get('id')\n" +
            "                break\n" +
            "        if ws is None:\n" +
            "            return None\n" +
            "        cl = json.loads(q(b'j/clients') or '[]')\n" +
            "        for c in cl:\n" +
            "            if c.get('mapped') and (c.get('workspace') or {}).get('id') == ws:\n" +
            "                return 1\n" +
            "        return 0\n" +
            "    except Exception:\n" +
            "        return None\n" +
            "def qcursor():\n" +
            "    d = q(b'cursorpos')\n" +
            "    if d is None: return None\n" +
            "    p = d.decode(errors='ignore').strip().split(',')\n" +
            "    return p[0] + ',' + p[1] if len(p) >= 2 else None\n" +
                        "focused = None\n" +
            "def seeFocus():\n" +
            "    global focused\n" +
            "    f = qfocus()\n" +
            "    if f is not None and f != focused:\n" +
            "        focused = f\n" +
            "        print('F ' + str(f), flush=True)\n" +
            "while True:\n" +
            "    try:\n" +
            "        seeFocus()\n" +
            "        s2 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n" +
            "        s2.connect(base + '/' + '.socket2.sock')\n" +
            "        s2.setblocking(False)\n" +
            "        buf = b''\n" +
            "        nextpoll = 0.0\n" +
            "        nextfocus = 0.0\n" +
            "        while True:\n" +
            "            r, _, _ = select.select([s2], [], [], 0.05)\n" +
            "            now = time.time()\n" +
            "            if r:\n" +
            "                chunk = s2.recv(4096)\n" +
            "                if not chunk: break\n" +
            "                buf += chunk\n" +
            "                while b'\\n' in buf:\n" +
            "                    line, buf = buf.split(b'\\n', 1)\n" +
            "                    ev = line.decode(errors='ignore').split('>>', 1)[0]\n" +
            "                    if ev in EV:\n" +
            "                        seeFocus()\n" +
            "            if now >= nextfocus:\n" +
            "                seeFocus()\n" +
            "                nextfocus = now + 0.4\n" +
            "            if focused == 0 and now >= nextpoll:\n" +
            "                c = qcursor()\n" +
            "                if c: print('C ' + c, flush=True)\n" +
            "                nextpoll = now + 0.1\n" +
            "    except Exception:\n" +
            "        time.sleep(1)\n"]
        stdout: SplitParser {
            onRead: data => {
                const d = data.trim();
                if (d.startsWith("F ")) {
                    // helper semantics: F 1 = a window has focus (j/activewindow
                    // returned an address), F 0 = no focused window -> wallpaper
                    // is showing. INVERTED from window-focus on purpose.
                    const wallpaperFocused = d.substring(2) === "0";
                    if (wallpaperFocused !== RoomState.wallpaperFocused) {
                        RoomState.wallpaperFocused = wallpaperFocused;
                        Sfx.setAmbientFocus(wallpaperFocused);
                    }
                } else if (d.startsWith("C ")) {
                    const parts = d.substring(2).split(",");
                    const cx = parseFloat(parts[0]);
                    const cy = parseFloat(parts[1]);
                    if (!isNaN(cx) && !isNaN(cy)) {
                        Cursor.gx = cx;
                        Cursor.gy = cy;
                    }
                }
            }
        }
    }

    // workspace tracking -> RoomState. focusedmon only updates the room
    // label/ambient; dialogue fires only on a real workspace switch
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // NOTE: focus/background-mode tracking lives in the Process above
            // (authoritative j/activewindow queries); this handler is only
            // for workspace/room tracking.
            if (event.name === "workspace") {
                const m = Hyprland.focusedMonitor;
                if (m?.activeWorkspace)
                    RoomState.currentWs = m.activeWorkspace.id;
                // no auto-intro on every ws switch (text is periodic / on demand)
            } else if (event.name === "focusedmon") {
                const m = Hyprland.focusedMonitor;
                if (m?.activeWorkspace && m.activeWorkspace.id !== RoomState.currentWs)
                    RoomState.currentWs = m.activeWorkspace.id;
            }
        }
    }

    // notification server: track everything, toast on arrival
    NotificationServer {
        id: notifServer
        keepOnReload: true

        property var toastHost: null

        onNotification: n => {
            n.tracked = true;
            toastHost?.push(n);
        }
    }

    Variants {
        model: Quickshell.screens

        Bg.Bg {}
    }

    Variants {
        model: Quickshell.screens

        Bar.Bar {}
    }

    // dialogue box on main monitor (input-transparent except the box itself)
    PanelWindow {
        id: dlgWin

        screen: mainScreenInfo()
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: false    // renders below apps, visible over the wallpaper
        color: "transparent"
        visible: RoomState.dialogueVisible   // decoupled from child visibility   // unmap when idle — parked transparent windows flicker

        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: 220
        mask: Region {
            item: box.visible ? box : null
        }

        Dlg.Box {
            id: box
            anchors {
                bottom: parent.bottom
                bottomMargin: 24
                horizontalCenter: parent.horizontalCenter
            }
        }
    }

    L.Launcher {}

    N.Center {
        server: notifServer
    }

    N.Toasts {
        id: toasts
        server: notifServer
        Component.onCompleted: notifServer.toastHost = this
    }

    O.Osd {}

    M.PlayerPopup {}

    Cc.ControlCenter {}

    // periodic dialogue — a line every few minutes, on its own
    // (opt-in via RoomState.autoTalk; off by default)
    Timer {
        id: periodicDialogue
        interval: 240000   // 4 min
        running: RoomState.autoTalk
        repeat: true
        onTriggered: if (RoomState.wallpaperFocused) RoomState.sayRandom()
    }

    // idle mood swings: random pose/emotion every 45-150s (never while
    // speaking, so the mouth stays synced)
    Timer {
        id: idleMood
        interval: 45000 + Math.random() * 105000
        running: RoomState.girlVisible   // no point rolling moods for a hidden girl
        repeat: true
        onTriggered: {
            if (RoomState.wallpaperFocused
                    && !RoomState.speaking && RoomState.girlVisible)
                RoomState.reseedSprite();
            idleMood.interval = 45000 + Math.random() * 105000;
        }
    }

    // room ambient follows the active room
    Connections {
        target: RoomState

        function onDidChangeRoom(roomId) {
            const r = RoomState.rooms[String(RoomState.currentWs)];
            Sfx.ambient(r?.ambient ?? "");
        }
    }

    Component.onCompleted: {
        ensureFont();
        const r = RoomState.rooms[String(RoomState.currentWs)];
        if (r?.ambient)
            Sfx.ambient(r.ambient);
        Sfx.setAmbientFocus(RoomState.wallpaperFocused);
    }
}
