pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml.Models
import QtQuick

// cross-component UI visibility + shell IPC actions
Singleton {
    id: root

    property bool launcherVisible: false
    property bool notifCenterVisible: false
    property bool playerPopupVisible: false

    signal toastRequested(string summary, string body)

    IpcHandler {
        target: "shell"

        function toggleLauncher(): void {
            root.launcherVisible = !root.launcherVisible;
        }

        function toggleCenter(): void {
            root.notifCenterVisible = !root.notifCenterVisible;
        }

        function togglePlayer(): void {
            root.playerPopupVisible = !root.playerPopupVisible;
        }

        function rerollSkybox(): void {
            RoomState.rerollSkybox();
        }

        function sayLine(): void {
            RoomState.sayRandom();
        }
    }
}
