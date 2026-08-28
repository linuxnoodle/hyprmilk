pragma Singleton

import QtQuick

QtObject {
    readonly property color accent: "#ac3232"
    readonly property color accent2: "#52263e"
    readonly property color bg: "#0d0d14"
    readonly property color bg2: "#31363b"
    readonly property color bg3: "#3b4045"
    readonly property color fg: "#ac3232"     // ALL text is the milk red now
    readonly property color fg2: "#8c2b2b"   // secondary text, dimmer red
    readonly property color purple: "#7d128d" // mom / shopkeeper text, game uses this

    // game's dialogue font (gui.text_font = 122.ttf, "Retro Gaming")
    property string gameFontFamily: ""
    readonly property string fontFamily:
        gameFontFamily !== "" ? gameFontFamily : "monospace"
    property int fontSize: 14

    readonly property int barHeight: 36
    readonly property int barMargin: 8
    readonly property int barExclusive: 56

    readonly property int animFast: 150
    readonly property int animMed: 250
    readonly property int animSlow: 400

    readonly property bool parallaxEnabled: false   // disabled: not smooth enough yet
}
