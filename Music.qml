pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQml.Models
import QtQuick

// music: MPRIS players (spotify/browser/...) + in-game radio via mpv
Singleton {
    id: root

    // ---------------- MPRIS ----------------
    property MprisPlayer trackedPlayer: null
    readonly property MprisPlayer activePlayer:
        trackedPlayer ?? Mpris.players.values[0] ?? null
    readonly property bool hasTrack: (activePlayer?.trackTitle ?? "") !== ""
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property string title: activePlayer?.trackTitle ?? ""
    readonly property string artist: activePlayer?.trackArtist ?? ""

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: {
                if (root.trackedPlayer == null || modelData.isPlaying)
                    root.trackedPlayer = modelData;
            }

            Component.onDestruction: {
                if (root.trackedPlayer == null || !root.trackedPlayer.isPlaying)
                    root.trackedPlayer = Mpris.players.values[0] ?? null;
            }

            function onPlaybackStateChanged() {
                root.trackedPlayer = modelData;
            }
        }
    }

    function togglePlaying() {
        if (activePlayer?.canTogglePlaying)
            activePlayer.togglePlaying();
    }
    function next() {
        if (activePlayer?.canGoNext)
            activePlayer.next();
    }
    function previous() {
        if (activePlayer?.canGoPrevious)
            activePlayer.previous();
    }

    // ---------------- game radio (mpv) ----------------
    property int station: 0          // 0 = off, 1..3
    property bool radioPlaying: station > 0
    property int trackIndex: 0
    readonly property var stations: ({
        1: "radio1", 2: "radio2", 3: "radio3",
    })

    // filled by tools/gen_manifests-style listing embedded here via dir read
    // fallback: known counts probed at runtime are unnecessary; use manifest
    readonly property var radioManifest: RoomState.manifest.radio ?? {}

    property var _proc: null

    function stationTracks(st: int): var {
        return radioManifest[String(st)] ?? [];
    }

    function radioPath(st: int, idx: int): string {
        const tracks = stationTracks(st);
        const f = tracks[idx % Math.max(tracks.length, 1)];
        return f ? `assets/audio/radio/${root.stations[st]}/${f}` : "";
    }

    function startStation(st: int) {
        if (station === st) {
            stopRadio();
            return;
        }
        station = st;
        trackIndex = Math.floor(Math.random() * Math.max(stationTracks(st).length, 1));
        _play();
    }

    function _play() {
        if (station < 1)
            return;
        _stopProc();
        const p = Qt.createQmlObject(
            "import Quickshell.Io; Process { property bool done: false }", root);
        p.command = ["mpv", "--no-video", "--really-quiet", "--idle=no",
                     Qt.resolvedUrl(radioPath(station, trackIndex)).toString().replace("file://", "")];
        p.exited.connect(() => {
            // gapless-ish: advance on track end
            if (root.station > 0 && p === root._proc) {
                root.trackIndex++;
                root._play();
            }
        });
        _proc = p;
        p.running = true;
    }

    function nextTrack() {
        if (station < 1)
            return;
        trackIndex++;
        _play();
    }

    function stopRadio() {
        station = 0;
        _stopProc();
    }

    function _stopProc() {
        if (_proc) {
            const proc = _proc;
            _proc = null;
            proc.running = false;
            proc.destroy();
        }
    }

    IpcHandler {
        target: "music"

        function playPause(): void {
            root.togglePlaying();
        }
        function next(): void {
            root.next();
        }
        function previous(): void {
            root.previous();
        }
        function station(st: int): void {
            root.startStation(st);
        }
        function stopRadio(): void {
            root.stopRadio();
        }
        function nextTrack(): void {
            root.nextTrack();
        }
    }
}
