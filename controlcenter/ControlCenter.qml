import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets"

// milk control center — the reference (Synoptik) quick-settings surface:
// volume + brightness sliders, power actions, calendar, tiny system monitor.
PanelWindow {
    id: root

    screen: Theme.mainScreen()
    exclusionMode: ExclusionMode.Normal
    aboveWindows: true
    focusable: false
    visible: Ui.controlVisible
    color: "transparent"

    anchors {
        top: true
        right: true
        bottom: true
    }
    implicitWidth: Math.round(380 * 1.1)
    mask: Region {
        item: panel
    }

    onVisibleChanged: if (visible) slideAnim.restart()

    // ---------------- system stats (checked periodically) ----------------
    property int cpuPct: 0
    property int memPct: 0
    property var _cpuPrev: null

    Timer {
        interval: 2000
        running: Ui.controlVisible
        repeat: true
        onTriggered: root.refreshStats()
    }

    function refreshStats() {
        // memory
        try {
            const m = readFile("/proc/meminfo");
            const mem = /MemTotal:\s+(\d+)/.exec(m);
            const free = /MemAvailable:\s+(\d+)/.exec(m);
            if (mem && free)
                root.memPct = Math.round((1 - Number(free[1]) / Number(mem[1])) * 100);
        } catch (e) {}
        // cpu
        try {
            const c = readFile("/proc/stat");
            const l = c.split("\n")[0];
            const p = l.split(/\s+/).slice(1).map(Number);
            const tot = p.reduce((a, b) => a + b, 0);
            const idle = p[3] + (p[4] ?? 0);
            if (root._cpuPrev) {
                const dTot = tot - root._cpuPrev.tot;
                const dIdle = idle - root._cpuPrev.idle;
                root.cpuPct = Math.round((1 - dIdle / Math.max(dTot, 1)) * 100);
            }
            root._cpuPrev = { tot, idle };
        } catch (e) {}
    }

    function readFile(path) {
        try {
            const f = Qt.createQmlObject(
                `import Quickshell.Io; FileView { path: "${path}"; blockLoading: true }`, root);
            const t = f.text();
            f.destroy();
            return t ?? "";
        } catch (e) { return ""; }
    }

    // ---------------- brightness (brightnessctl) ----------------
    property int brightPct: 100
    property bool hasBacklight: false

    function probeBrightness() {
        const f = Qt.createQmlObject(
            `import Quickshell.Io; FileView { path: "/tmp/hyprmilk-bright"; blockLoading: true }`, root);
        const t = f.text(); f.destroy();
        const m = /brightness,([^ ]+),(\d+),(\d+)/.exec(t ?? "");
        if (m) { root.hasBacklight = true; root.brightPct = Number(m[3]); }
    }

    property var _bright: null
    function setBrightness(pct) {
        root.brightPct = pct;
        Quickshell.execDetached(["sh", "-c",
            `brightnessctl -m set ${pct}% > /tmp/hyprmilk-bright 2>/dev/null || true`]);
    }

    Component.onCompleted: {
        refreshStats();
        Quickshell.execDetached(["sh", "-c",
            "brightnessctl -m get > /tmp/hyprmilk-bright 2>/dev/null || true"]);
        probePump.start();
    }
    Timer { id: probePump; interval: 500; onTriggered: { root.probeBrightness(); stop(); } }

    // ---------------- power actions (reference commands) ----------------
    function power(cmd) { Quickshell.execDetached(cmd); }

    // ---------------- volume (Pipewire) ----------------
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null

    // ---------------- panel ----------------
    Border {
        id: panel

        readonly property real uiScale: 1.1
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Math.round(88 * uiScale)
            bottom: parent.bottom
        }
        width: parent.width
        opacity: 0
        transform: Translate { id: slide; x: panel.width }

        SequentialAnimation {
            id: slideAnim
            ParallelAnimation {
                NumberAnimation { target: slide; property: "x"; to: 0; duration: Theme.animMed; easing.type: Easing.OutCubic }
                NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Theme.animFast }
            }
        }
        Connections {
            target: Ui
            function onControlVisibleChanged() { if (!Ui.controlVisible) outAnim.start(); }
        }
        SequentialAnimation {
            id: outAnim
            ParallelAnimation {
                NumberAnimation { target: slide; property: "x"; to: panel.width; duration: Theme.animMed; easing.type: Easing.InCubic }
                NumberAnimation { target: panel; property: "opacity"; to: 0; duration: Theme.animFast }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ---- stats row ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StatBlock { label: "CPU"; value: root.cpuPct }
                StatBlock { label: "RAM"; value: root.memPct }
                StatBlock { label: "VOL"; value: Math.round((root.sink?.volume ?? 0) * 100) }
                StatBlock { label: "BRI"; value: root.brightPct }

                component StatBlock: Rectangle {
                    id: sb
                    property string label: ""
                    property int value: 0
                    Layout.fillWidth: true
                    height: 40
                    color: Theme.bg2
                    border.color: Theme.bg3
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: `${sb.label}  ${sb.value}%`
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.fg
                        smooth: false
                    }
                }
            }

            // ---- volume slider ----
            Text { text: "VOLUME"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.fg2; smooth: false }
            PixelSlider {
                value: sink?.volume ?? 0
                onMoved: v => { if (root.sink) root.sink.volume = v; }
                onPressed: v => { if (root.sink) root.sink.volume = v; }
            }

            // ---- brightness slider ----
            Text { text: "BRIGHTNESS"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.fg2; smooth: false }
            PixelSlider {
                value: root.brightPct / 100
                enabled: root.hasBacklight
                onMoved: v => root.setBrightness(Math.round(v * 100))
                onPressed: v => root.setBrightness(Math.round(v * 100))
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.bg3 }

            // ---- power actions ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "POWER"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.fg2
                    smooth: false
                }
                PowerBtn { glyph: "⏻"; tip: "lock"; onClicked: root.power(["hyprlock"]) }
                PowerBtn { glyph: "⏾"; tip: "sleep"; onClicked: root.power(["systemctl", "suspend"]) }
                PowerBtn { glyph: "↩"; tip: "logout"; onClicked: root.power(["hyprctl", "dispatch", "exit"]) }
                PowerBtn { glyph: "⟳"; tip: "reboot"; onClicked: root.power(["systemctl", "reboot"]) }
                PowerBtn { glyph: "⏼"; tip: "off"; onClicked: root.power(["systemctl", "poweroff"]) }

                component PowerBtn: Rectangle {
                    id: pb
                    property string glyph: ""
                    property string tip: ""
                    signal clicked()
                    Layout.preferredWidth: 44
                    height: 40
                    color: mouse.containsMouse ? Theme.accent2 : Theme.bg2
                    border.color: Theme.bg3
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: pb.glyph
                        font.pixelSize: 18
                        color: Theme.fg
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pb.clicked()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.bg3 }

            // ---- calendar ----
            Text {
                text: Qt.formatDate(new Date(), "MMMM yyyy")
                font.family: Theme.fontFamily
                font.pixelSize: 14
                color: Theme.accent
                smooth: false
            }
            CalendarGrid {}
        }
    }

    // pixel slider: 12 blocks, red filled / dark empty
    component PixelSlider: Item {
        id: ps
        property real value: 0
        signal moved(real v)
        signal pressed(real v)

        Layout.fillWidth: true
        height: 28

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: 12

                Rectangle {
                    required property int index
                    readonly property bool on: (index + 1) / 12 <= ps.value
                    width: 22
                    height: 24
                    color: on ? Theme.accent : Theme.bg2
                    border.color: Theme.bg3
                    border.width: 1
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: e => {
                if (pressed) {
                    const v = Math.max(0, Math.min(1, e.x / parent.width));
                    ps.value = v;
                    ps.moved(v);
                }
            }
            onPressed: e => {
                const v = Math.max(0, Math.min(1, e.x / parent.width));
                ps.value = v;
                ps.pressed(v);
            }
        }
    }

    // month grid
    component CalendarGrid: Column {
        id: cg

        property date today: new Date()

        function daysInMonth() {
            const d = new Date(cg.today.getFullYear(), cg.today.getMonth() + 1, 0);
            return d.getDate();
        }
        function firstDow() {
            return new Date(cg.today.getFullYear(), cg.today.getMonth(), 1).getDay();
        }

        // weekday header
        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            Row {
                width: cg.width
                Text {
                    width: cg.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.fg2
                    smooth: false
                }
            }
        }

        function cells() {
            const cells = [];
            for (let i = 0; i < firstDow(); i++) cells.push(0);
            for (let d = 1; d <= daysInMonth(); d++) cells.push(d);
            while (cells.length % 7 !== 0) cells.push(0);
            return cells;
        }

        property var grid: cells()

        Repeater {
            model: Math.ceil(cg.grid.length / 7)

            Row {
                id: outerRow
                property int rowIndex: index
                width: cg.width
                Repeater {
                    model: 7

                    Rectangle {
                        required property int index
                        readonly property int day:
                            cg.grid[(outerRow.rowIndex * 7) + index]
                        width: cg.width / 7 - 3
                        height: 24
                        color: day === cg.today.getDate() ? Theme.accent2 : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: day > 0 ? day : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: day === cg.today.getDate() ? Theme.fg
                                : day > 0 ? Theme.fg2 : "transparent"
                            smooth: false
                        }
                    }
                }
            }
        }
    }
}
