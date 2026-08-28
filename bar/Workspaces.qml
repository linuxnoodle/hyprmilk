pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland
import ".."
import "../data/wsbindings.js" as Binds

// workspace chips — one per workspace BINDED to this monitor
// (hyprland.lua rules: DP-3=1-5, DP-2=6-10, DP-1=11).
// occupied (has windows) = solid; empty = outline-only; active = milk red.
MouseArea {
    id: root

    required property var bar
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    property var wsIds: []
    property var occupied: ({})   // wsId -> true when it has windows

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    acceptedButtons: Qt.NoButton
    hoverEnabled: true

    function currentIndex() {
        return monitor?.activeWorkspace?.id ?? wsIds[0] ?? 1;
    }

    function refresh() {
        const name = monitor?.name ?? "";
        const stat = Binds.wsbindings[name];
        if (stat && stat.length)
            root.wsIds = stat.slice();   // static binding map (incl. empty ws)
        queryOccupancy();
    }

    // occupancy: hyprctl workspaces -> which ws have windows
    function queryOccupancy() {
        if (_occParser && _occParser.running)
            return;
        root._fallbackPath = "/tmp/hyprmilk-ws.json";
        _occParser = procComp.createObject(root);
        _occParser.command = ["sh", "-c",
            "hyprctl workspaces -j > /tmp/hyprmilk-ws.json 2>/dev/null"];
        _occParser.exited.connect(() => {
            try {
                const occ = {};
                for (const w of JSON.parse(fv.text()))
                    occ[w.id] = (w.windows ?? 0) > 0;
                root.occupied = occ;
            } catch (e) {}
            root._occParser = null;
        });
        _occParser.running = true;
    }

    property Component procComp: Component { Process { } }
    property var _parser: null
    property var _occParser: null
    property string _fallbackPath: ""

    // hyprctl reader
    FileView {
        id: fv
        path: root._fallbackPath
        blockLoading: true
    }

    onWheel: e => {
        e.accepted = true;
        if (!wsIds.length)
            return;
        const idx = wsIds.indexOf(currentIndex());
        const step = -Math.sign(e.angleDelta.y);
        const at = Math.max(0, Math.min(wsIds.length - 1, idx + step));
        RoomState.dispatch(`workspace ${wsIds[at]}`);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const names = ["workspace", "moveworkspace", "createworkspace",
                           "destroyworkspace", "movewindow", "openwindow",
                           "closewindow"];
            if (names.includes(event.name))
                root.refresh();
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Math.round(8 * (bar?.uiScale ?? 1))

        Repeater {
            model: root.wsIds

            delegate: MouseArea {
                id: chip
                required property int index
                readonly property int wsIndex: root.wsIds[index]
                readonly property bool active:
                    (root.monitor?.activeWorkspace ?? null) != null
                    && root.monitor.activeWorkspace.id == wsIndex
                readonly property bool hasWindows: root.occupied[wsIndex] === true

                implicitWidth: Math.round(24 * (bar?.uiScale ?? 1))
                implicitHeight: Math.round(24 * (bar?.uiScale ?? 1))
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onPressed: RoomState.dispatch(`workspace ${wsIndex}`)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 0   // pixel rectangles, not circles
                    // active: milk red; occupied: darker grey; empty: hollow
                    color: active ? Theme.accent2
                        : chip.hasWindows ? "#262a33"
                        : "transparent"
                    border.width: chip.hasWindows ? 0 : 1
                    border.color: "#3b4045"
                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: wsIndex
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(11 * (bar?.uiScale ?? 1))
                    color: active ? Theme.fg
                        : chip.hasWindows ? "#8c2b2b"
                        : "#5c2222"   // empty: dimmer
                    smooth: false
                }
            }
        }
    }

    Connections {
        target: root.monitor

        function onActiveWorkspaceChanged() {
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}