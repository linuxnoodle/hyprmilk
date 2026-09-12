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
    property bool controlVisible: false

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

        function toggleControl(): void {
            root.controlVisible = !root.controlVisible;
        }

        function cycleWallpaper(): void {
            RoomState.cycleWallpaper();
        }

        function toggleGirl(): void {
            RoomState.toggleGirl();
        }

        function toggleAutoTalk(): void {
            RoomState.toggleAutoTalk();
        }

        function nextState(): void {
            RoomState.nextState();
        }

        function sayLine(): void {
            RoomState.sayRandom();
        }
    }
}
