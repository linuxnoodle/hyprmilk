import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import ".."
import "../widgets"

// notification toasts, top-right stack
PanelWindow {
    id: root

    // set from shell.qml
    required property NotificationServer server

    screen: Quickshell.primaryScreen ?? Quickshell.screens[0]
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    implicitHeight: column.implicitHeight
    implicitWidth: column.implicitWidth
    mask: Region {
        item: null // fully input-transparent
    }

    readonly property var toasts: []

    function push(n) {
        const c = toastComp.createObject(column);
        c.notif = n;
        c.width = Qt.binding(() => column.toastWidth);
        toasts.unshift(c);
        // cap at 4 visible
        while (toasts.length > 4) {
            toasts.pop().destroy(300);
        }
    }

    Component {
        id: toastComp

        Border {
            id: toast

            property var notif: null
            property real uiScale: 1.15

            height: Math.round(76 * uiScale)
            opacity: 0

            Component.onCompleted: {
                showAnim.start();
                hideTimer.start();
                notif.tracked = true;
            }

            Connections {
                target: toast.notif

                function onClosed() {
                    toast.hideTimer.stop();
                    hideAnim.start();
                }
            }

            SequentialAnimation {
                id: showAnim
                NumberAnimation { target: toast; property: "opacity"; to: 1; duration: Theme.animFast }
            }
            SequentialAnimation {
                id: hideAnim
                NumberAnimation { target: toast; property: "opacity"; to: 0; duration: Theme.animMed }
                ScriptAction { script: toast.destroy() }
            }
            Timer {
                id: hideTimer
                interval: 5000
                onTriggered: hideAnim.start()
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 10
                    leftMargin: 14
                }
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: toast.notif?.appName ?? "milk"
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(10 * toast.uiScale)
                    color: Theme.accent
                    smooth: false
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: toast.notif?.summary ?? ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(13 * toast.uiScale)
                    color: Theme.fg
                    smooth: false
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: toast.notif?.body ?? ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(11 * toast.uiScale)
                    color: Theme.fg2
                    smooth: false
                }
            }

            // accent strip
            Rectangle {
                width: 3
                color: Theme.accent
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    toast.notif?.dismiss();
                    toast.hideTimer.stop();
                    toast.hideAnim.start();
                }
            }
        }
    }

    Column {
        id: column

        property int toastWidth: 360

        spacing: 8
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 56
            rightMargin: 12
        }
    }
}
