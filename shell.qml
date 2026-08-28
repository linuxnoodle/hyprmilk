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
            const m = Hyprland.focusedMonitor;
            if (!m?.activeWorkspace)
                return;
            const ws = m.activeWorkspace.id;
            if (event.name === "workspace") {
                RoomState.currentWs = ws;
                RoomState.sayRoomIntro(RoomState.roomId);
            } else if (event.name === "focusedmon") {
                if (ws !== RoomState.currentWs)
                    RoomState.currentWs = ws;
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
    }
}
