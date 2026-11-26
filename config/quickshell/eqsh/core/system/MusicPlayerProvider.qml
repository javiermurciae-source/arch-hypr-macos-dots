pragma Singleton

import QtQuick
import qs
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: mpris
    // playerctld is a proxy that also registers on MPRIS (often empty, and it
    // may sort last), so it never counts as a player of its own.
    property var players: Mpris.players.values.filter(p => String(p.dbusName || "").indexOf("playerctld") < 0)
    // the playing player wins; otherwise the last one used, otherwise any with a track
    property var lastPlayer: null
    property var activePlayer: {
        const ps = mpris.players;
        for (let i = ps.length - 1; i >= 0; i--)
            if (ps[i].isPlaying) return ps[i];
        if (mpris.lastPlayer && ps.indexOf(mpris.lastPlayer) >= 0) return mpris.lastPlayer;
        for (let i = ps.length - 1; i >= 0; i--)
            if (ps[i].trackTitle) return ps[i];
        return ps.length ? ps[ps.length - 1] : null;
    }
    onActivePlayerChanged: { const p = activePlayer; if (p && p.trackTitle) Qt.callLater(() => { if (mpris.lastPlayer !== p) mpris.lastPlayer = p }) }
    property string title: mpris.activePlayer?.trackTitle || Translation.tr("Not Playing")
    property string artist: {
        const p = mpris.activePlayer;
        if (!p) return "";
        const a = p.trackArtists;
        if (Array.isArray(a) && a.length > 0) return a.join(", ");
        if (typeof a === "string" && a.trim().length > 0) return a.trim();
        if (p.trackArtist && String(p.trackArtist).trim().length > 0) return String(p.trackArtist).trim();
        return p.identity || "";
    }
    property string album: mpris.activePlayer?.trackAlbum || ""
    property url thumbnail: mpris.activePlayer?.trackArtUrl || ""
    property url hdThumbnail: thumbnail
    property string _lastHdArtKey: ""
    readonly property string hdArtKey: mpris.activePlayer
        ? (mpris.title + "|" + mpris.artist + "|" + String(mpris.thumbnail || ""))
        : ""

    onHdArtKeyChanged: {
        mpris.hdThumbnail = mpris.thumbnail;
        if (!mpris.activePlayer || !mpris.title || mpris.title === "") return;
        if (hdArtKey === _lastHdArtKey) return;
        _lastHdArtKey = hdArtKey;
        hdArtProc.running = false;
        hdArtProc.command = [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/macos/modules/island/hd_artwork.py",
            mpris.title || "",
            mpris.artist || "",
            mpris.album || "",
            String(mpris.thumbnail || "")
        ];
        hdArtProc.running = true;
    }

    Process {
        id: hdArtProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const u = (text || "").trim();
                if (u.length > 0) mpris.hdThumbnail = u;
            }
        }
        stderr: StdioCollector {}
    }

    property bool isPlaying: mpris.activePlayer?.isPlaying || false
    property int duration: mpris.activePlayer?.length || 0
    property int position: mpris.activePlayer?.position || 0
    property bool isAvailable: (mpris.activePlayer?.trackTitle || false) ? true : false
    property double _seekHoldUntil: 0

    // ~6.6x a second so synced lyrics follow the song with minimal lag
    Timer {
        interval: 150
        repeat: true
        running: !!mpris.activePlayer
        onTriggered: {
            const holding = Date.now() < mpris._seekHoldUntil;
            if (!holding) {
                const pos = mpris.activePlayer?.position || 0;
                mpris.position = pos;
                mpris.exactPosition = pos;
            } else if (mpris.isPlaying) {
                const nextPos = Math.min(mpris.duration || 99999, mpris.exactPosition + 0.15);
                mpris.exactPosition = nextPos;
                mpris.position = nextPos;
            }
        }
    }
    property real exactPosition: 0      // fractional seconds for lyrics

    function seekTo(sec) {
        const p = mpris.activePlayer;
        if (!p || mpris.duration <= 0) return;
        const clamped = Math.max(0, Math.min(mpris.duration, sec));
        mpris.exactPosition = clamped;
        mpris.position = clamped;
        mpris._seekHoldUntil = Date.now() + 900;
        try {
            if (p.canSeek) p.position = clamped;
        } catch (e) {}
        const pId = String(p.dbusName || "").replace(/^org\.mpris\.MediaPlayer2\./, "");
        const secStr = clamped.toFixed(2);
        seekProc.command = pId.length > 0
            ? ["playerctl", "-p", pId, "position", secStr]
            : ["playerctl", "position", secStr];
        seekProc.running = false;
        seekProc.running = true;
    }

    Process {
        id: seekProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // index of the line being sung (-1 before the first line)
    readonly property int lyricsIndex: {
        if (lyricsLines.length === 0) return -1;
        if (lyricsSynced) {
            const t = exactPosition + 0.12;
            let c = -1;
            for (let i = 0; i < lyricsLines.length; i++) { if (lyricsLines[i].t <= t) c = i; else break; }
            return c;
        }
        if (duration > 0) {
            const ratio = Math.max(0, Math.min(0.999, exactPosition / duration));
            return Math.floor(ratio * lyricsLines.length);
        }
        return 0;
    }
    readonly property string lyricsCurrent: lyricsIndex >= 0 && lyricsIndex < lyricsLines.length ? (lyricsLines[lyricsIndex].text || "") : ""
    property bool available: false

    // ── lyrics (smart multi-stage LRCLIB + lyrics.ovh fetcher shared with Dynamic Island) ──
    property bool lyricsWanted: false
    property var lyricsLines: []        // [{ t: seconds (-1 = not synced), text }]
    property bool lyricsSynced: false
    property string lyricsState: "idle" // idle | loading | ok | none | offline
    property int lyricsTries: 0
    readonly property string trackKey: mpris.activePlayer
        ? (mpris.title + "|" + mpris.artist + "|" + mpris.album + "|" + Math.round((mpris.duration || 0) / 3))
        : ""

    onTrackKeyChanged: {
        lyricsLines = []; lyricsSynced = false; lyricsState = "idle"; lyricsTries = 0;
        if (lyricsWanted) lyricsFetchDelay.restart();
    }
    onLyricsWantedChanged: if (lyricsWanted && (lyricsState === "idle" || lyricsLines.length === 0)) lyricsFetchDelay.restart()

    Timer { id: lyricsFetchDelay; interval: 450; onTriggered: mpris.fetchLyrics(false) }
    Timer { id: lyricsRetry; interval: 10000; onTriggered: mpris.fetchLyrics(false) }

    function fetchLyrics(force) {
        if (!lyricsWanted || !mpris.activePlayer || mpris.title === "") return;
        if (lrcProc.running && !force) return;
        lyricsState = "loading";
        const cmd = [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/macos/modules/island/lyrics_fetch.py",
            mpris.title || "",
            mpris.artist || "",
            String(Math.round(mpris.duration || 0)),
            mpris.album || ""
        ];
        if (force) cmd.push("--force");
        lrcProc.running = false;
        lrcProc.command = cmd;
        lrcProc.running = true;
    }

    Process {
        id: lrcProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse((text || "{}").trim());
                    const lines = Array.isArray(data.lines) ? data.lines : [];
                    mpris.lyricsSynced = !!data.synced;
                    mpris.lyricsLines = lines;
                    mpris.lyricsState = lines.length > 0 ? "ok" : "none";
                } catch (e) {
                    if (mpris.lyricsTries < 2) {
                        mpris.lyricsTries++;
                        mpris.lyricsState = "loading";
                        lyricsRetry.restart();
                    } else {
                        mpris.lyricsLines = [];
                        mpris.lyricsSynced = false;
                        mpris.lyricsState = "none";
                    }
                }
            }
        }
        stderr: StdioCollector {}
    }

    function togglePlay() {
        if (mpris.activePlayer) {
            if (mpris.isPlaying) {
                mpris.activePlayer.pause()
            } else {
                mpris.activePlayer.play()
            }
        }
    }
    function next() {
        if (mpris.activePlayer) {
            mpris.activePlayer.next()
        }
    }
    function previous() {
        if (mpris.activePlayer) {
            mpris.activePlayer.previous()
        }
    }

    IpcHandler {
        target: "music"
        function togglePlay() {
            mpris.togglePlay()
        }
        function next() {
            mpris.next()
        }
        function previous() {
            mpris.previous()
        }
        function getData(): object {
            return {
                "title": mpris.title,
                "artist": mpris.artist,
                "album": mpris.album,
                "thumbnail": mpris.thumbnail,
                "isPlaying": mpris.isPlaying,
                "duration": mpris.duration,
                "position": mpris.position
            }
        }
    }
}