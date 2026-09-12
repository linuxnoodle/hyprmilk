import Quickshell
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

    // workspace tracking -> RoomState. focusedmon only updates the room
    // label/ambient; dialogue fires only on a real workspace switch
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const focusEvents = ["activewindow", "activewindowv2", "workspace",
                                 "focusedmon", "movewindow", "openwindow",
                                 "closewindow", "changefloatingmode"];

            // background mode: a window is focused <=> activeToplevel exists.
            // moving to an EMPTY workspace fires no activewindow event, so
            // derive focus from the toplevel itself on every relevant event.
            if (focusEvents.includes(event.name)) {
                const focused = Hyprland.activeToplevel !== null;
                if (focused !== RoomState.wallpaperFocused) {
                    RoomState.wallpaperFocused = focused;
                    Sfx.setAmbientFocus(focused);
                }
            }

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
