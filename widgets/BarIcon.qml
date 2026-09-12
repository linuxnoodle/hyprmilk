import QtQuick
import ".."

// monochrome bar icon drawn in the milk-red palette — replaces color emoji
// (🔊 🔔) whose fixed emoji colors clash with the theme. `active` picks the
// bright accent (Theme.fg), otherwise the dimmer Theme.fg2, same as text.
Canvas {
    id: root

    property string kind: "speaker"   // "speaker" | "bubble" | "battery" | "bell"
    property bool active: false
    property bool muted: false        // speaker/bubble: slash state
    property real level: -1           // battery: charge fill 0..1 (<0 = n/a)

    width: 16
    height: 16
    antialiasing: true

    onActiveChanged: requestPaint()
    onMutedChanged: requestPaint()
    onKindChanged: requestPaint()
    onLevelChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const red = active ? Theme.fg : Theme.fg2;
        ctx.fillStyle = red;
        ctx.strokeStyle = red;
        ctx.lineWidth = 1.5;
        ctx.lineCap = "round";

        if (kind === "speaker") {
            // driver box + cone (filled polygon)
            ctx.beginPath();
            ctx.moveTo(2, 6);
            ctx.lineTo(5, 6);
            ctx.lineTo(9, 2);
            ctx.lineTo(9, 14);
            ctx.lineTo(5, 10);
            ctx.lineTo(2, 10);
            ctx.closePath();
            ctx.fill();
            if (muted) {
                // sound off: red slash pair
                ctx.beginPath();
                ctx.moveTo(11, 5);
                ctx.lineTo(15, 11);
                ctx.moveTo(15, 5);
                ctx.lineTo(11, 11);
                ctx.stroke();
            } else {
                // sound on: two wave arcs
                ctx.beginPath();
                ctx.arc(9, 8, 4, -Math.PI / 3, Math.PI / 3);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(9, 8, 6.5, -Math.PI / 3, Math.PI / 3);
                ctx.stroke();
            }
        } else if (kind === "bubble") {
            // speech bubble (Milk-chan voice toggle) — sharp pixel corners;
            // muted = outline only + slash, unmuted = filled
            ctx.beginPath();
            ctx.moveTo(2, 3);
            ctx.lineTo(14, 3);
            ctx.lineTo(14, 10);
            ctx.lineTo(7, 10);
            ctx.lineTo(4, 13);
            ctx.lineTo(4, 10);
            ctx.lineTo(2, 10);
            ctx.closePath();
            if (muted)
                ctx.stroke();
            else
                ctx.fill();
            if (muted) {
                ctx.beginPath();
                ctx.moveTo(2.5, 12.5);
                ctx.lineTo(13.5, 1.5);
                ctx.stroke();
            }
        } else if (kind === "battery") {
            // body outline + terminal nub + charge fill by `level` (0..1)
            ctx.lineWidth = 1.5;
            ctx.strokeRect(2, 5, 11, 6);
            ctx.fillStyle = red;
            ctx.fillRect(13.5, 7, 2, 2);
            const lvl = Math.max(0, Math.min(1, root.level));
            if (lvl > 0.02)
                ctx.fillRect(3.5, 6.5, 8 * lvl, 3);
        } else if (kind === "bell") {
            // dome with flared lip
            ctx.beginPath();
            ctx.moveTo(3, 11);
            ctx.lineTo(4, 10);
            ctx.lineTo(4, 7);
            ctx.arc(8, 7, 4, Math.PI, 0);
            ctx.lineTo(12, 10);
            ctx.lineTo(13, 11);
            ctx.closePath();
            ctx.fill();
            // clapper
            ctx.beginPath();
            ctx.arc(8, 13.5, 1.4, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
