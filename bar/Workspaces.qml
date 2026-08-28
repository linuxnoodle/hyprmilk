pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland
import ".."
import "../data/wsbindings.js" as Binds

// workspace dots — one per workspace BINDED to this monitor
// (from hyprland.lua workspace rules: DP-3=1-5, DP-2=6-10, DP-1=11)
MouseArea {
    id: root

    required property var bar
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    property var wsIds: []

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
        // static binding map from hyprland.lua (includes empty bound ws)
        if (stat && stat.length) {
            root.wsIds = stat.slice();
            return;
        }
        // fallback: whatever hyprctl currently reports for this monitor
        if (!_parser || _parser.running)
            return;
        root._fallbackPath = "/tmp/hyprmilk-ws.json";
        _parser = procComp.createObject(root);
        _parser.command = ["sh", "-c", "hyprctl workspaces -j > /tmp/hyprmilk-ws.json 2>/dev/null"];
        _parser.exited.connect(() => {
            try {
                const ws = JSON.parse(fv.text());
                const ids = ws.filter(w => (w.monitor ?? "") === name)
                              .map(w => w.id).sort((a, b) => a - b);
                if (ids.length)
                    root.wsIds = ids;
            } catch (e) {}
            root._parser = null;
        });
        _parser.running = true;
    }

    property Component procComp: Component { Process { } }
    property var _parser: null
    property string _fallbackPath: ""   // set only when the fallback is used

    // hyprctl fallback reader (path stays empty until fallback actually runs)
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
        Hyprland.dispatch(`workspace ${wsIds[at]}`);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "moveworkspace")
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
                required property int index
                readonly property int wsIndex: root.wsIds[index]
                readonly property bool active:
                    (root.monitor?.activeWorkspace ?? null) != null
                    && root.monitor.activeWorkspace.id == wsIndex

                implicitWidth: Math.round(24 * (bar?.uiScale ?? 1))
                implicitHeight: Math.round(24 * (bar?.uiScale ?? 1))
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onPressed: Hyprland.dispatch(`workspace ${wsIndex}`)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 0   // pixel rectangles, not circles
                    color: active ? Theme.accent2 : Theme.bg3
                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: wsIndex
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(11 * (bar?.uiScale ?? 1))
                    color: active ? Theme.fg : Theme.fg2
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