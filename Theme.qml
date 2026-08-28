pragma Singleton

import QtQuick

QtObject {
    readonly property color accent: "#ac3232"
    readonly property color accent2: "#52263e"
    readonly property color bg: "#0d0d14"
    readonly property color bg2: "#31363b"
    readonly property color bg3: "#3b4045"
    readonly property color fg: "#ffffff"
    readonly property color fg2: "#c4c4c4"
    readonly property color purple: "#7d128d" // mom / shopkeeper text, game uses this

    readonly property string fontFamily: "BigBlueTermPlus Nerd Font Mono"
    readonly property int fontSize: 14

    readonly property int barHeight: 28
    readonly property int barMargin: 8
    readonly property int barExclusive: 42

    readonly property int animFast: 150
    readonly property int animMed: 250
    readonly property int animSlow: 400
}
