import Quickshell
import Quickshell.Hyprland
import QtQuick
import "bg" as Bg
import "bar" as Bar
import "dialogue" as Dlg

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

        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: 220
        WlrMask {}

        component WlrMask: Region {
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
