pragma Singleton

import Quickshell
import QtQuick

// Global pointer position + focus state source. The actual work lives in a
// single python helper owned by shell.qml (socket2 listener + cursorpos/focus
// queries, self-gated on focus): it streams "C x,y" cursor samples (only
// while the wallpaper is focused — CPU idles when a window has focus) and
// "F 1/0" focus transitions into the SplitParser there. This singleton just
// carries the state.
Singleton {
    id: root

    property real gx: -1
    property real gy: -1
    readonly property bool ready: gx >= 0
}
