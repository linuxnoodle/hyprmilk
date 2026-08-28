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

        // room plate: static flat red/black bedroom (bg.png) on every workspace.
        // game room-scene plates are near-black; user wants no flashing/black walls.
        // layer texture: repaint-stable (Qt flicker workaround on pointer hover)
        Image {
            id: roomPlate
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: false
            layer.enabled: true
            layer.smooth: false
            layer.textureSize: Qt.size(width, height)
            source: "../assets/bg/bg.png"
        }

        // Milk-Chan, standing right of center — always in the red/black room
        MilkChan {
            scale: Math.min(1.0, parent.height / 1027 * 0.7)
            speaking: RoomState.speaking
            layer.enabled: true
            layer.smooth: false
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
        visible: RoomState.showSkybox
        source: RoomState.skyboxIndex > 0
            ? `../assets/bg/mirror/${RoomState.skyboxIndex}.png` : ""
    }

    // z-2: skybox (intro-style cloud art; hidden unless enabled via launcher)
    Image {
        id: skybox
        z: -2
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: false
        cache: false
        visible: RoomState.showSkybox
        source: RoomState.skyboxIndex > 0
            ? `../assets/bg/skybox/${RoomState.skyboxIndex}.png` : ""
    }
}
