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

    // workspace tracking -> RoomState
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "focusedmon") {
                const m = Hyprland.focusedMonitor;
                if (m?.activeWorkspace)
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

    // dialogue box on primary screen (input-transparent except the box itself)
    PanelWindow {
        id: dlgWin

        screen: Quickshell.primaryScreen ?? Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: false
        color: "transparent"
        visible: box.visible   // unmap when idle — parked transparent windows flicker

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
        const r = RoomState.rooms[String(RoomState.currentWs)];
        if (r?.ambient)
            Sfx.ambient(r.ambient);
    }
}
