import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."
import "../widgets"

// app launcher — fuzzy-ish search over desktop entries + shell actions
PanelWindow {
    id: root

    property int selectedIndex: 0
    property var results: []

    screen: Theme.mainScreen()
    exclusionMode: ExclusionMode.Normal
    aboveWindows: true
    focusable: true
    visible: Ui.launcherVisible
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 520
    mask: Region {
        item: panel
    }

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            searchField.forceActiveFocus();
            root.selectedIndex = 0;
        }
    }

    function activate() {
        if (results.length === 0)
            return;
        const r = results[selectedIndex];
        if (r.action)
            r.action();
        else
            Quickshell.execDetached(r.entry.command);
        Ui.launcherVisible = false;
    }

    function updateResults() {
        const q = searchField.text.toLowerCase().trim();
        const acts = [
            { name: "Switch wallpaper", comment: "next game CG / sky frame", action: () => RoomState.cycleWallpaper() },
            { name: "Toggle Milk-Chan", comment: "show / hide the girl", action: () => RoomState.toggleGirl() },
            { name: "Toggle idle chatter", comment: "auto dialogue every few minutes", action: () => RoomState.toggleAutoTalk() },
            { name: "Talk to Milk-Chan", comment: "random dialogue line", action: () => RoomState.sayRandom() },
            { name: "Game radio", comment: Music.radioPlaying ? "stop radio" : "play station 1", action: () => Music.radioPlaying ? Music.stopRadio() : Music.startStation(1) },
        ];
        let out = [];
        for (const a of acts) {
            if (q === "" || a.name.toLowerCase().includes(q) || a.comment.toLowerCase().includes(q))
                out.push(a);
        }
        const entries = DesktopEntries.applications.values;
        for (const e of entries) {
            if (e.noDisplay)
                continue;
            const hay = (e.name + " " + (e.comment ?? "")).toLowerCase();
            if (q === "" || hay.includes(q))
                out.push({ name: e.name, comment: e.comment ?? "", entry: e });
            if (out.length > 40)
                break;
        }
        results = out;
        selectedIndex = Math.min(selectedIndex, Math.max(out.length - 1, 0));
    }

    Border {
        id: panel

        readonly property real uiScale: Math.max(1, Math.min(1.6, root.width / 2560))

        anchors {
            top: parent.top
            topMargin: Math.round(80 * uiScale)
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.min(Math.round(560 * uiScale), root.width * 0.9)
        height: Math.min(Math.round(420 * uiScale), 400)
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // input row
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(40 * panel.uiScale)
                color: Theme.bg2
                border.color: searchField.activeFocus ? Theme.accent : Theme.bg3
                border.width: 1

                TextInput {
                    id: searchField
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(16 * panel.uiScale)
                    color: Theme.fg
                    cursorVisible: true
                    onTextChanged: root.updateResults()
                    onAccepted: root.activate()

                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape)
                            Ui.launcherVisible = false;
                        else if (e.key === Qt.Key_Down) {
                            root.selectedIndex = Math.min(root.selectedIndex + 1, root.results.length - 1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Up) {
                            root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                            e.accepted = true;
                        }
                    }
                }
            }

            // results
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.results.length
                spacing: 2

                // scroll to keep the keyboard selection in view
                Connections {
                    target: root
                    function onSelectedIndexChanged() {
                        if (root.selectedIndex >= 0)
                            list.positionViewAtIndex(root.selectedIndex,
                                ListView.Contain);
                    }
                }

                delegate: Rectangle {
                    required property int index
                    readonly property var item: root.results[index] ?? null
                    width: list.width
                    height: Math.round(36 * panel.uiScale)
                    color: index === root.selectedIndex ? Theme.accent2 : "transparent"

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        text: parent.item ? parent.item.name : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(14 * panel.uiScale)
                        color: Theme.fg
                        smooth: false
                    }
                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        text: parent.item && parent.item.action ? "shell" : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(11 * panel.uiScale)
                        color: Theme.fg2
                        smooth: false
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selectedIndex = index
                        onClicked: {
                            root.selectedIndex = index;
                            root.activate();
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: updateResults()
}
