pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import ".."
import "../widgets"

// stylized PNG window frames (the game's frame9 slices) drawn over every
// normal window. Hyprland can't draw PNG borders, so this overlay does it,
// polling hyprctl for exact geometry.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    // claim the same zone as the bar so we get FULL-screen geometry
    // (a layer without a zone gets clipped under the bar's zone)
    exclusiveZone: root.barZone

    anchors {
        top: true
        left: true
        bottom: true
        right: true
    }
    mask: Region {
        item: null   // fully input-transparent
    }

    readonly property int barZone: Math.round(Theme.barExclusive
        * Math.max(1, Math.min(1.6, width / 2560)))

    property var frames: []
    property var _parser: null

    // hyprctl writes geometry json to a temp file; FileView reads it back
    // (Process.stdout isn't populated without a parser in qs 0.3.1)
    FileView {
        id: fv
        path: "/tmp/hyprmilk-frames.json"
        blockLoading: true
    }

    function refresh() {
        if (_parser && _parser.running)
            return;
        _parser = procComp.createObject(root);
        _parser.command = ["sh", "-c",
            "hyprctl clients -j > /tmp/hyprmilk-frames.json 2>/dev/null"];
        _parser.exited.connect(() => {
            const t = fv.text();
            if (t && t.length > 0)
                root.applyFrames(t);
            root._parser = null;
        });
        _parser.running = true;
    }

    function applyFrames(json) {
        try {
            let mon = null;
            try {
                mon = Hyprland.monitorFor(modelData);
            } catch (e2) {
                console.warn("[frames] monitorFor fail", modelData?.name);
            }
            const monId = mon?.id ?? -1;
            const activeId = mon?.activeWorkspace?.id ?? -1;
            const list = [];
            const clients = JSON.parse(json);
            for (const c of clients) {
                if (c.monitor !== monId)
                    continue;
                if (!c.mapped || c.hidden || c.fullscreen !== 0)
                    continue;
                // only windows on THIS monitor's ACTIVE workspace
                if (c.workspace?.id !== activeId)
                    continue;
                const ws = c.workspace?.name ?? "";
                if (ws.startsWith("special"))
                    continue;
                list.push({ info: c });
            }
            root.frames = list;
        } catch (e) {
            console.warn("[frames] parse error", e, "json type=", typeof json,
                "len=", json?.length, "head=", String(json).slice(0, 80));
        }
    }

    property Component procComp: Component {
        Process {}
    }

    Timer {
        id: debounce
        interval: 250
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const names = ["openwindow", "closewindow", "windowmove",
                           "windowresize", "fullscreen", "workspace",
                           "moveworkspace", "changefloatingmode"];
            if (names.includes(event.name))
                debounce.restart();
        }
    }

    Repeater {
        model: root.frames

        delegate: Border {
            required property var modelData
            readonly property var info: modelData.info

            fillColor: "transparent"   // outline only, never cover the app
            // hyprctl clients JSON: position is under "at": [x, y]
            x: (info.at?.[0] ?? 0) - (root.modelData?.x ?? 0)
            y: (info.at?.[1] ?? 0) - (root.modelData?.y ?? 0)
            width: info.size?.[0] ?? 0
            height: info.size?.[1] ?? 0
        }
    }

    Component.onCompleted: refresh()
}