import QtQuick
import ".."

// stylized game outline — the same hand-drawn crimson frame as gui/frame.png
// (pre-sliced to assets/gui/frame9/* by tools/slice_frame.py), laid over a
// dark fill. Use like a Rectangle: `Border { ...content... }`.
Rectangle {
    id: borderRoot

    // window frames use fillColor: "transparent" (outline only)
    property color fillColor: Theme.bg

    color: borderRoot.fillColor

    Image {
        id: tl
        z: 2
        anchors { top: parent.top; left: parent.left }
        source: "../assets/gui/frame9/tl.png"
        smooth: false
    }
    Image {
        id: tr
        z: 2
        anchors { top: parent.top; right: parent.right }
        source: "../assets/gui/frame9/tr.png"
        smooth: false
    }
    Image {
        id: bl
        z: 2
        anchors { bottom: parent.bottom; left: parent.left }
        source: "../assets/gui/frame9/bl.png"
        smooth: false
    }
    Image {
        id: br
        z: 2
        anchors { bottom: parent.bottom; right: parent.right }
        source: "../assets/gui/frame9/br.png"
        smooth: false
    }
    // edges tile between the corners
    Image {
        id: tEdge
        z: 2
        anchors {
            top: parent.top
            left: tl.right
            right: tr.left
        }
        height: tl.height
        fillMode: Image.TileHorizontally
        source: "../assets/gui/frame9/t.png"
        smooth: false
    }
    Image {
        id: bEdge
        z: 2
        anchors {
            bottom: parent.bottom
            left: bl.right
            right: br.left
        }
        height: bl.height
        fillMode: Image.TileHorizontally
        source: "../assets/gui/frame9/b.png"
        smooth: false
    }
    Image {
        id: lEdge
        z: 2
        anchors {
            left: parent.left
            top: tl.bottom
            bottom: bl.top
        }
        width: tl.width
        fillMode: Image.TileVertically
        source: "../assets/gui/frame9/l.png"
        smooth: false
    }
    Image {
        id: rEdge
        z: 2
        anchors {
            right: parent.right
            top: tr.bottom
            bottom: br.top
        }
        width: tr.width
        fillMode: Image.TileVertically
        source: "../assets/gui/frame9/r.png"
        smooth: false
    }
}