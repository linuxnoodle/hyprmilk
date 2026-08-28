import Quickshell
import QtQuick
import ".."

PanelWindow {
    id: bg

    required property var modelData

    screen: modelData
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    color: "transparent"

    anchors {
        top: true
        left: true
        bottom: true
        right: true
    }

    // z0 top layer stack
    Item {
        id: stage
        anchors.fill: parent

        // room plate (point-and-click scene of current workspace room)
        Image {
            id: roomPlate
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            cache: false
            source: {
                const r = RoomState.room;
                if (!r)
                    return "../assets/bg/bg.png";
                if (r.id === "hub" || r.id === "ost")
                    return "../assets/bg/bg.png";
                const plates = r.plates ?? [];
                const p = plates[RoomState.plateIndex % Math.max(plates.length, 1)];
                return p ? `../assets/rooms/${r.id}/${p}.png` : "../assets/bg/bg.png";
            }
            onSourceChanged: fadeAnim.restart()

            SequentialAnimation on opacity {
                id: fadeAnim
                running: false
                NumberAnimation { to: 0.15; duration: Theme.animFast }
                NumberAnimation { to: 1; duration: Theme.animSlow }
            }
        }

        // Milk-Chan, standing right of center — only in the hub (bedroom),
        // like the game. Other rooms are scene plates without the sprite.
        MilkChan {
            visible: RoomState.roomId === "hub"
            // girl takes ~70% of screen height (game sprite is 1959x1027)
            scale: Math.min(1.0, parent.height / 1027 * 0.7)
            speaking: RoomState.speaking
            anchors {
                bottom: parent.bottom
                right: parent.right
                rightMargin: parent.width * 0.08
            }
        }
    }

    // z-1: girl's reflection overlay (cg_mirror_gg, alpha) — pairs with skybox index,
    // visible through transparent parts of the room plate
    Image {
        id: mirror
        z: -1
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
        source: RoomState.skyboxIndex > 0
            ? `../assets/bg/mirror/${RoomState.skyboxIndex}.png` : ""
    }

    // z-2: skybox (cloud variants, random per session / re-rollable)
    Image {
        id: skybox
        z: -2
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: false
        cache: false
        source: RoomState.skyboxIndex > 0
            ? `../assets/bg/skybox/${RoomState.skyboxIndex}.png` : ""
    }

    // slow room plate pan, like the game's sequential scene states
    Timer {
        interval: 45000 + Math.random() * 30000
        running: true
        repeat: true
        onTriggered: RoomState.nextPlate()
    }
}
