import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import "../../services"
import "../common"

Item {
    id: state

    // ── Navigation & expansion ────────────────────────────────────
    // Pages: 0=Music, 1=Pomodoro, 2=Water, 3=Todo, 4=Shelf&Clipboard
    property int currentPage: 0
    readonly property int pageCount: 5
    property bool expanded: false
    property bool lyricsOpen: false
    property bool addingTodo: false
    property bool waterSettingsOpen: false
    property string statusRingMode: "battery" // "battery" | "water"

    // ── Active HUD toast ──────────────────────────────────────────
    // hudType: "" | "battery" | "volume" | "brightness" | "water" | "player" | "clipboard"
    property string hudType: ""
    property string hudTitle: ""
    property string hudSubtitle: ""
    property string hudValueText: ""
    property real hudProgress: 0
    property color hudAccent: "#30d158"
    property bool hudActionDrink: false

    function showHud(type, title, subtitle, valueText, progress, accent, durationMs, actionDrink) {
        state.hudType = type;
        state.hudTitle = title || "";
        state.hudSubtitle = subtitle || "";
        state.hudValueText = valueText || "";
        state.hudProgress = Math.max(0, Math.min(1, progress || 0));
        state.hudAccent = accent || "#30d158";
        state.hudActionDrink = !!actionDrink;
        hudTimer.interval = durationMs || 2200;
        hudTimer.restart();
    }

    function clearHud() {
        hudTimer.stop();
        state.hudType = "";
        state.hudActionDrink = false;
    }

    Timer {
        id: hudTimer
        interval: 2200
        onTriggered: state.clearHud()
    }

    // ── Notifications ─────────────────────────────────────────────
    property var activeNotif: null
    property string activeNotifIcon: ""
    property var activeNotifActions: []
    property bool activeNotifCanReply: false
    property string activeNotifReplyPlaceholder: "Reply…"
    property bool replyingNotif: false
    property bool notifVisible: false
    property real notifProgress: 1.0
    property bool notifPaused: false
    property real _notifStep: 0.015 // ~3.3s default

    Connections {
        target: Notifications
        function onNotify(n) {
            if (!n || Notifications.doNotDisturb) return;
            // Don't interrupt the user while they are typing an inline reply
            if (state.replyingNotif) return;
            state.activeNotif = n;
            state.activeNotifIcon = Notifications.iconFor(n);
            state.activeNotifActions = Notifications.buttons(n);
            let canReply = !!(n.hasInlineReply);
            if (!canReply && n.actions) {
                for (let i = 0; i < n.actions.length; ++i) {
                    if (n.actions[i].identifier === "inline-reply") {
                        canReply = true;
                        break;
                    }
                }
            }
            state.activeNotifCanReply = canReply;
            state.activeNotifReplyPlaceholder = (n.inlineReplyPlaceholder && String(n.inlineReplyPlaceholder).trim().length > 0)
                ? String(n.inlineReplyPlaceholder) : "Escribe tu respuesta…";
            state.replyingNotif = false;
            const txt = ((n.appName || "") + " " + (n.summary || "")).toLowerCase();
            const isQuick = txt.includes("screenshot") || txt.includes("hyprshot") || txt.includes("grim") || txt.includes("captura") || txt.includes("clipboard");
            // Quick screenshot/system notifications auto-close in ~2.2s; replyable messages stay ~8s so you can click Reply
            state._notifStep = state.activeNotifCanReply ? (50 / 8000) : (isQuick ? (50 / 2200) : (50 / 4000));
            state.notifPaused = false;
            state.notifVisible = true;
            state.notifProgress = 1.0;
            notifCountdown.restart();
        }
        function onDiscard(id) {
            if (state.activeNotif && state.activeNotif.id === id) {
                state.dismissNotif(false);
            }
        }
    }

    function sendNotifReply(replyText) {
        const clean = (replyText || "").trim();
        const n = state.activeNotif;
        if (!clean || !n || !state.activeNotifCanReply) return;
        const appTitle = n.appName || "Mensaje";
        try {
            if (typeof n.sendInlineReply === "function") {
                n.sendInlineReply(clean);
            }
        } catch (e) {
            console.warn("[island] inline reply failed:", e);
        }
        state.dismissNotif(true);
        state.showHud("reply", "Respondido", appTitle + ": " + clean.slice(0, 36), "✓", 1.0, "#30d158", 1800, false);
    }

    function dismissNotif(closeServer) {
        notifCountdown.stop();
        const n = state.activeNotif;
        // Always hide immediately first so UI never gets stuck
        state.notifVisible = false;
        state.notifPaused = false;
        state.replyingNotif = false;
        state.activeNotifCanReply = false;
        state.notifProgress = 0;
        state.activeNotif = null;
        state.activeNotifIcon = "";
        state.activeNotifActions = [];
        try { Notifications.dismissToast(); } catch (e) {}
        if (closeServer && n) {
            try { Notifications.safeDismiss(n); } catch (e) {}
        }
    }

    Timer {
        id: notifCountdown
        interval: 50
        repeat: true
        running: false
        onTriggered: {
            if (state.notifPaused || state.replyingNotif) return;
            state.notifProgress = Math.max(0, state.notifProgress - state._notifStep);
            if (state.notifProgress <= 0) {
                state.dismissNotif(false);
            }
        }
    }

    // ── MPRIS Media & Multi-Player Switcher ───────────────────────
    property var players: []
    property int playerIndex: 0
    property var activePlayer: null
    property bool _userPinnedPlayer: false
    property double position: 0
    property bool scrubbing: false
    property double scrubPosition: 0
    property double _seekHoldUntil: 0

    readonly property bool hasMedia: activePlayer !== null && !!activePlayer.trackTitle
    readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false
    readonly property int playingCount: {
        let c = 0;
        for (let i = 0; i < players.length; i++) {
            if (players[i] && players[i].playbackState === MprisPlaybackState.Playing) c++;
        }
        return c;
    }
    readonly property bool anyPlaying: playingCount > 0
    property bool sourcesMenuOpen: false
    property bool _keepMultiWhileExpanded: false
    readonly property bool showMultiSources: (playingCount > 1) || (expanded && _keepMultiWhileExpanded && players.length > 1)

    onPlayingCountChanged: {
        if (playingCount > 1) _keepMultiWhileExpanded = true;
    }
    onExpandedChanged: {
        if (!expanded) {
            _keepMultiWhileExpanded = false;
            sourcesMenuOpen = false;
            // If user paused their pinned player and another is playing, let pickPlayers auto-follow again
            if (activePlayer && activePlayer.playbackState !== MprisPlaybackState.Playing && anyPlaying) {
                _userPinnedPlayer = false;
                pickPlayers();
            }
        }
    }
    readonly property string trackTitle: {
        if (!activePlayer || !activePlayer.trackTitle) return "No Media Playing";
        return String(activePlayer.trackTitle).replace(/[\r\n]+/g, " ").replace(/\s{2,}/g, " ").trim() || "No Media Playing";
    }
    readonly property string trackArtist: {
        if (!activePlayer) return "Play something to see it here";
        const a = activePlayer.trackArtists;
        if (Array.isArray(a) && a.length > 0) return a.join(", ");
        if (typeof a === "string" && a.trim().length > 0) return a.trim();
        if (activePlayer.trackArtist && String(activePlayer.trackArtist).trim().length > 0)
            return String(activePlayer.trackArtist).trim();
        return activePlayer.identity || "";
    }
    readonly property string trackAlbum: activePlayer ? (activePlayer.trackAlbum || "") : ""
    readonly property string trackArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property double trackLength: activePlayer ? (activePlayer.length || 0) : 0
    readonly property string playerName: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media") : ""
    readonly property double displayPosition: scrubbing ? scrubPosition : position

    // Dynamic palette extracted from album artwork
    property color artColor1: "#0e86a8"
    property color artColor2: "#205ce8"
    property color artColor3: "#6c30d0"
    property color artAccent: "#5eb0ff"
    property string _lastArtUrl: ""

    onTrackArtUrlChanged: {
        const u = (trackArtUrl || "").trim();
        if (u === _lastArtUrl) return;
        _lastArtUrl = u;
        if (u === "") {
            artColor1 = "#0e86a8";
            artColor2 = "#205ce8";
            artColor3 = "#6c30d0";
            artAccent = "#5eb0ff";
            return;
        }
        paletteProc.running = false;
        paletteProc.command = [
            "python3",
            "__USER_HOME__/.config/quickshell/macos/modules/island/art_palette.py",
            u
        ];
        paletteProc.running = true;
    }

    Process {
        id: paletteProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text.trim());
                    if (p.c1) state.artColor1 = p.c1;
                    if (p.c2) state.artColor2 = p.c2;
                    if (p.c3) state.artColor3 = p.c3;
                    if (p.accent) state.artAccent = p.accent;
                } catch (e) {}
            }
        }
        stderr: StdioCollector {}
    }

    function fmtTime(t) {
        const s = Math.max(0, Math.floor(t || 0));
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2);
    }

    function fmtRemaining(pos, len) {
        if (!len || len <= 0) return "0:00";
        const rem = Math.max(0, Math.floor(len - (pos || 0)));
        return "-" + Math.floor(rem / 60) + ":" + ("0" + (rem % 60)).slice(-2);
    }

    function playerLabel(p) {
        if (!p) return "Media";
        const id = String(p.identity || p.desktopEntry || "").trim();
        const dbus = String(p.dbusName || "").toLowerCase();
        if (id.toLowerCase().indexOf("youtube") >= 0) return "YT Music";
        if (id.toLowerCase().indexOf("chromium") >= 0 || dbus.indexOf("chromium") >= 0) return "YT Music";
        if (id.toLowerCase().indexOf("firefox") >= 0 || dbus.indexOf("firefox") >= 0) return "Firefox";
        if (id.toLowerCase().indexOf("spotify") >= 0 || dbus.indexOf("spotify") >= 0) return "Spotify";
        if (id.toLowerCase().indexOf("vlc") >= 0) return "VLC";
        if (id.toLowerCase().indexOf("mpv") >= 0) return "mpv";
        return id || "Media";
    }

    function isIgnoredPlayer(p) {
        if (!p) return true;
        if (p.identity === "playerctld" || p.desktopEntry === "playerctld") return true;
        const dbus = String(p.dbusName || "").toLowerCase();
        const id = String(p.identity || p.desktopEntry || "").toLowerCase();
        const isFirefox = dbus.indexOf("firefox") >= 0 || id.indexOf("firefox") >= 0;
        if (!isFirefox) return false;

        const rawTitle = String(p.trackTitle || "");
        const url = (p.metadata && p.metadata["xesam:url"]) ? String(p.metadata["xesam:url"]).toLowerCase() : "";
        const hasArt = String(p.trackArtUrl || "").trim().length > 0;

        // Ignore X.com / Twitter feed autoplay videos & silent clips in Firefox
        if (url.indexOf("x.com") >= 0 || url.indexOf("twitter.com") >= 0) return true;
        if (/(?:^|\s)\/\s*x\s*$/i.test(rawTitle.trim())) return true;
        if (/(?:https?:\/\/)?(?:t\.co|x\.com|twitter\.com)\//i.test(rawTitle)) return true;
        if (!hasArt && (rawTitle.indexOf("\n") >= 0 || rawTitle.length > 80 || (p.length > 0 && p.length <= 180))) return true;
        return false;
    }

    function pickPlayers() {
        const list = Mpris.players.values.filter(p =>
            !state.isIgnoredPlayer(p)
            && (!!p.trackTitle || p.playbackState === MprisPlaybackState.Playing));
        state.players = list;
        if (list.length === 0) {
            state.activePlayer = null;
            state.playerIndex = 0;
            state._userPinnedPlayer = false;
            state.position = 0;
            return;
        }
        let chosen = (state.activePlayer && list.indexOf(state.activePlayer) !== -1) ? state.activePlayer : null;
        if (!chosen) {
            state._userPinnedPlayer = false;
        }
        // Respect manual user selection; otherwise auto-follow any playing player
        if (!state._userPinnedPlayer && (!chosen || chosen.playbackState !== MprisPlaybackState.Playing)) {
            const playing = list.find(p => p.playbackState === MprisPlaybackState.Playing && p.trackTitle);
            if (playing) chosen = playing;
        }
        if (!chosen) chosen = list.find(p => !!p.trackTitle) || list[0];
        state.playerIndex = Math.max(0, list.indexOf(chosen));
        if (state.activePlayer !== chosen) {
            state.activePlayer = chosen;
        }
        if (state.activePlayer && !state.scrubbing && Date.now() >= state._seekHoldUntil) {
            state.position = state.activePlayer.position || 0;
        }
    }

    function selectPlayer(idx) {
        if (idx < 0 || idx >= state.players.length) return;
        const p = state.players[idx];
        if (!p) return;
        state.playerIndex = idx;
        state.activePlayer = p;
        state._userPinnedPlayer = true;
        state._seekHoldUntil = 0;
        state.position = p.position || 0;
        if (state.lyricsOpen || state.expanded) lyricsFetchDelay.restart();
    }

    function togglePlayerAt(idx) {
        if (idx < 0 || idx >= state.players.length) return;
        const p = state.players[idx];
        if (p && p.canTogglePlaying) {
            p.togglePlaying();
        }
    }

    function pauseOtherPlayers(keepIdx) {
        for (let i = 0; i < state.players.length; i++) {
            if (i === keepIdx) continue;
            const p = state.players[i];
            if (p && p.playbackState === MprisPlaybackState.Playing && p.canPause) {
                try { p.pause(); } catch (e) {}
            }
        }
    }

    function focusPlayer(p) {
        if (!p) return;
        const dbus = String(p.dbusName || "");
        const id = String(p.identity || "");
        const entry = String(p.desktopEntry || "");
        const title = String(p.trackTitle || "").replace(/[\r\n]+/g, " ").trim();
        state.sourcesMenuOpen = false;
        state.expanded = false;
        Quickshell.execDetached([
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/macos/modules/island/focus_player.py",
            dbus, id, entry, title
        ]);
    }

    function focusActivePlayer() {
        focusPlayer(state.activePlayer);
    }

    function cyclePlayer() {
        if (state.players.length <= 1) return;
        const nextIdx = (state.playerIndex + 1) % state.players.length;
        state.selectPlayer(nextIdx);
        if (state.activePlayer) {
            state.showHud("player", state.playerLabel(state.activePlayer), state.trackTitle,
                (state.playerIndex + 1) + "/" + state.players.length,
                (state.playerIndex + 1) / state.players.length, "#5e9cff", 1400, false);
        }
    }

    function seekTo(sec) {
        if (!state.activePlayer || state.trackLength <= 0) return;
        const clamped = Math.max(0, Math.min(state.trackLength, sec));
        state.position = clamped;
        state.scrubPosition = clamped;
        state._seekHoldUntil = Date.now() + 1400;

        // Send a SINGLE authoritative seek (sending both MPRIS + playerctl back-to-back
        // causes double-seek jumps / resets on browsers!)
        let sent = false;
        try {
            if (state.activePlayer.canSeek) {
                state.activePlayer.position = clamped;
                sent = true;
            }
        } catch (e) {}

        if (!sent) {
            const pId = (state.activePlayer.dbusName || "")
                .replace(/^org\.mpris\.MediaPlayer2\./, "");
            const secStr = clamped.toFixed(2);
            seekProc.command = pId.length > 0
                ? ["playerctl", "-p", pId, "position", secStr]
                : ["playerctl", "position", secStr];
            seekProc.running = false;
            seekProc.running = true;
        }

        if (state.lyricsLines.length > 0) {
            state.updateCurrentLyric();
        }
    }

    function seekRelative(deltaSec) {
        if (!state.activePlayer || state.trackLength <= 0) return;
        state.seekTo(state.displayPosition + deltaSec);
    }

    Process {
        id: seekProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { state.pickPlayers(); }
    }

    // Fast position tick (150ms) only when playing or expanded -> smooth lyrics & scrubber, 0 CPU when idle
    Timer {
        interval: 150
        running: state.isPlaying || state.expanded
        repeat: true
        onTriggered: {
            const holding = Date.now() < state._seekHoldUntil;
            if (state.activePlayer && !state.scrubbing && !holding) {
                state.position = state.activePlayer.position || 0;
            } else if (state.isPlaying && holding && state.trackLength > 0) {
                state.position = Math.min(state.trackLength, state.position + 0.15);
            }
            if (state.lyricsLines.length > 0) {
                state.updateCurrentLyric();
            }
        }
    }

    // Slow player discovery poll (2s)
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: state.pickPlayers()
    }

    // ── Synced Lyrics (LRCLIB) ────────────────────────────────────
    property var lyricsLines: []
    property bool lyricsSynced: false
    property bool lyricsLoading: false
    property int currentLyricIndex: -1
    property string _lastLyricsKey: ""

    readonly property string prevLyricText: {
        if (currentLyricIndex > 0 && currentLyricIndex - 1 < lyricsLines.length)
            return lyricsLines[currentLyricIndex - 1].text;
        return "";
    }
    readonly property string currentLyricText: {
        if (lyricsLoading) return "Searching synced lyrics…";
        if (lyricsLines.length === 0) return "No synced lyrics found";
        if (currentLyricIndex >= 0 && currentLyricIndex < lyricsLines.length)
            return lyricsLines[currentLyricIndex].text;
        return lyricsLines[0].text;
    }
    readonly property string nextLyricText: {
        if (currentLyricIndex >= 0 && currentLyricIndex + 1 < lyricsLines.length)
            return lyricsLines[currentLyricIndex + 1].text;
        if (currentLyricIndex === -1 && lyricsLines.length > 1)
            return lyricsLines[1].text;
        return "";
    }

    function updateCurrentLyric() {
        if (state.lyricsLines.length === 0) {
            state.currentLyricIndex = -1;
            return;
        }
        if (state.lyricsSynced) {
            const pos = state.displayPosition + 0.12;
            let idx = -1;
            for (let i = 0; i < state.lyricsLines.length; i++) {
                if (state.lyricsLines[i].t <= pos) idx = i;
                else break;
            }
            state.currentLyricIndex = idx;
        } else if (state.trackLength > 0) {
            // Smooth proportional scroll for plain (unsynced) lyrics fallback!
            const ratio = Math.max(0, Math.min(0.999, state.displayPosition / state.trackLength));
            state.currentLyricIndex = Math.floor(ratio * state.lyricsLines.length);
        }
    }

    readonly property string lyricsTrackKey: state.hasMedia
        ? (state.trackTitle + "|" + state.trackArtist + "|" + state.trackAlbum + "|" + Math.round((state.trackLength || 0) / 3)).toLowerCase()
        : ""

    Timer {
        id: lyricsFetchDelay
        interval: 450
        repeat: false
        onTriggered: state.fetchLyricsIfNeeded(false)
    }

    function fetchLyricsIfNeeded(force) {
        if (!state.hasMedia) {
            state.lyricsLines = [];
            state.lyricsSynced = false;
            state.currentLyricIndex = -1;
            state._lastLyricsKey = "";
            return;
        }
        const key = state.lyricsTrackKey;
        if (!force && key === state._lastLyricsKey) return;
        state._lastLyricsKey = key;
        state.lyricsLines = [];
        state.lyricsSynced = false;
        state.currentLyricIndex = -1;
        state.lyricsLoading = true;
        lyricsProc.running = false;
        const cmd = [
            "python3",
            "__USER_HOME__/.config/quickshell/macos/modules/island/lyrics_fetch.py",
            state.trackTitle,
            state.trackArtist,
            String(Math.round(state.trackLength || 0)),
            state.trackAlbum
        ];
        if (force) cmd.push("--force");
        lyricsProc.command = cmd;
        lyricsProc.running = true;
    }

    function jumpToLyricOffset(delta) {
        if (!state.lyricsSynced || state.lyricsLines.length === 0) return;
        const idx = Math.max(0, Math.min(state.lyricsLines.length - 1, state.currentLyricIndex + delta));
        if (state.lyricsLines[idx] && state.lyricsLines[idx].t >= 0) {
            state.seekTo(state.lyricsLines[idx].t);
        }
    }

    onTrackTitleChanged: {
        state.position = state.activePlayer ? (state.activePlayer.position || 0) : 0;
        state._seekHoldUntil = 0;
    }
    onLyricsTrackKeyChanged: {
        if (state.lyricsOpen || state.expanded) lyricsFetchDelay.restart();
        else state._lastLyricsKey = "";
    }
    onLyricsOpenChanged: {
        if (state.lyricsOpen) lyricsFetchDelay.restart();
    }

    Process {
        id: lyricsProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                state.lyricsLoading = false;
                try {
                    const data = JSON.parse(text.trim());
                    state.lyricsSynced = !!data.synced;
                    state.lyricsLines = Array.isArray(data.lines) ? data.lines : [];
                    state.currentLyricIndex = state.lyricsLines.length > 0 ? 0 : -1;
                    if (state.lyricsSynced) state.updateCurrentLyric();
                } catch (e) {
                    state.lyricsLines = [];
                    state.lyricsSynced = false;
                }
            }
        }
        stderr: StdioCollector {}
    }

    // ── Pomodoro Focus Timer ──────────────────────────────────────
    property string pomoMode: "focus" // "focus" | "break"
    property int pomoFocusSec: 25 * 60
    property int pomoBreakSec: 5 * 60
    property int pomoRemaining: 25 * 60
    property bool pomoRunning: false
    readonly property int pomoTotal: pomoMode === "focus" ? pomoFocusSec : pomoBreakSec
    readonly property real pomoProgress: pomoTotal > 0 ? (1.0 - pomoRemaining / pomoTotal) : 0
    readonly property string pomoText: {
        const m = Math.floor(pomoRemaining / 60);
        const s = pomoRemaining % 60;
        return ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2);
    }

    function setPomoMode(mode) {
        state.pomoRunning = false;
        state.pomoMode = mode;
        state.pomoRemaining = (mode === "focus") ? state.pomoFocusSec : state.pomoBreakSec;
    }
    function togglePomo() {
        if (state.pomoRemaining <= 0) {
            state.pomoRemaining = state.pomoTotal;
        }
        state.pomoRunning = !state.pomoRunning;
    }
    function resetPomo() {
        state.pomoRunning = false;
        state.pomoRemaining = state.pomoTotal;
    }

    Timer {
        interval: 1000
        running: state.pomoRunning
        repeat: true
        onTriggered: {
            if (state.pomoRemaining > 0) {
                state.pomoRemaining -= 1;
            } else {
                state.pomoRunning = false;
                const finishedFocus = (state.pomoMode === "focus");
                state.showHud(
                    "pomodoro",
                    finishedFocus ? "Focus Complete!" : "Break Over",
                    finishedFocus ? "Time for a short break" : "Ready for the next round",
                    finishedFocus ? "5:00" : "25:00",
                    1.0,
                    finishedFocus ? "#30d158" : "#ff3b5c",
                    4500,
                    false
                );
            }
        }
    }

    // ── Water Reminder & Hourly Chart ─────────────────────────────
    property int waterMl: 0
    property int waterGoalMl: 1500
    property int waterCupMl: 250
    property bool waterReminderOn: true
    property int waterIntervalMin: 45
    property string waterNextTime: ""
    property var waterHourly: ({}) // {"9": 250, "12": 250, ...}
    property string waterDateKey: ""

    readonly property real waterProgress: waterGoalMl > 0 ? Math.min(1.0, waterMl / waterGoalMl) : 0
    readonly property string waterLitersText: (waterMl / 1000.0).toFixed(1)
    readonly property string waterGoalLitersText: (waterGoalMl / 1000.0).toFixed(1)

    function todayKey() {
        const d = new Date();
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }

    function updateNextWaterTime() {
        const d = new Date(Date.now() + state.waterIntervalMin * 60000);
        state.waterNextTime = ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
    }

    function addWater(ml) {
        const key = todayKey();
        if (state.waterDateKey !== key) {
            state.waterDateKey = key;
            state.waterMl = 0;
            state.waterHourly = {};
        }
        const amount = ml || state.waterCupMl;
        state.waterMl += amount;
        const h = String(new Date().getHours());
        const copy = Object.assign({}, state.waterHourly);
        copy[h] = (copy[h] || 0) + amount;
        state.waterHourly = copy;
        updateNextWaterTime();
        waterReminderTimer.restart();
        saveState();
    }

    function resetWaterToday() {
        state.waterDateKey = todayKey();
        state.waterMl = 0;
        state.waterHourly = {};
        updateNextWaterTime();
        saveState();
    }

    Timer {
        id: waterReminderTimer
        interval: Math.max(5, state.waterIntervalMin) * 60000
        running: state.waterReminderOn
        repeat: true
        onTriggered: {
            state.updateNextWaterTime();
            state.showHud(
                "water",
                "Hydration Check",
                state.waterLitersText + " / " + state.waterGoalLitersText + " L today",
                Math.round(state.waterProgress * 100) + "%",
                state.waterProgress,
                "#3b82f6",
                5000,
                true
            );
        }
    }

    // ── TodoList ──────────────────────────────────────────────────
    property var todos: [
        { id: 1, text: "Finish desktop rice polish", done: true },
        { id: 2, text: "Test synced lyrics in Nusa notch", done: false },
        { id: 3, text: "Drink water & stretch", done: false }
    ]

    readonly property int todosDoneCount: {
        let c = 0;
        for (let i = 0; i < todos.length; i++) if (todos[i].done) c++;
        return c;
    }

    function toggleTodo(id) {
        const arr = state.todos.map(t => t.id === id ? { id: t.id, text: t.text, done: !t.done } : t);
        state.todos = arr;
        saveState();
    }

    function addTodo(text) {
        const clean = (text || "").trim();
        if (!clean) return;
        const arr = state.todos.slice();
        arr.push({ id: Date.now(), text: clean, done: false });
        state.todos = arr;
        saveState();
    }

    function removeTodo(id) {
        state.todos = state.todos.filter(t => t.id !== id);
        saveState();
    }

    // ── File Shelf & Clipboard History ────────────────────────────
    property var shelfItems: [] // [{path, name, sizeText, isImage}]
    property var clipItems: []  // [{id, preview}]
    property bool draggingShelfOut: false

    function addShelfPaths(urls) {
        if (!urls || urls.length === 0) return;
        const paths = [];
        for (let i = 0; i < urls.length; i++) {
            let p = String(urls[i]);
            if (p.startsWith("file://")) p = decodeURIComponent(p.slice(7));
            if (p.length > 0) paths.push(p);
        }
        if (paths.length === 0) return;
        shelfStatProc.command = [
            "python3", "-c",
            "import os,sys,json\nout=[]\nfor p in sys.argv[1:]:\n if not os.path.exists(p): continue\n sz=os.path.getsize(p) if os.path.isfile(p) else 0\n u='B'\n v=float(sz)\n for unit in ['B','KB','MB','GB']:\n  u=unit\n  if v<1024 or unit=='GB': break\n  v/=1024.0\n st=('Folder' if os.path.isdir(p) else (f'{v:.1f} {u}' if u!='B' else f'{int(v)} B'))\n ext=os.path.splitext(p)[1].lower()\n img=ext in ('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')\n out.append({'path':p,'name':os.path.basename(p.rstrip('/')) or p,'sizeText':st,'isImage':img})\nprint(json.dumps(out))",
        ].concat(paths);
        shelfStatProc.running = true;
    }

    function removeShelfItem(path) {
        state.shelfItems = state.shelfItems.filter(it => it.path !== path);
        saveState();
    }

    function openShelfItem(path) {
        runDetached("xdg-open " + shellQuote(path));
    }

    function filePathToUri(path) {
        const raw = String(path || "");
        if (raw.startsWith("file://")) return raw;
        return "file://" + encodeURI(raw).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function copyShelfFile(path) {
        const uri = filePathToUri(path);
        const base = String(path || "").split("/").pop() || path;
        clipCopyProc.running = false;
        clipCopyProc.command = ["bash", "-c", "printf '%s\\r\\n' " + shellQuote(uri) + " | wl-copy --type text/uri-list"];
        clipCopyProc.running = true;
        state.showHud("clipboard", "Archivo copiado", base.slice(0, 40), "✓", 1.0, "#30d158", 1600, false);
    }

    function copyText(txt) {
        clipCopyProc.command = ["wl-copy", "--", String(txt)];
        clipCopyProc.running = true;
        state.showHud("clipboard", "Copied", String(txt).slice(0, 42), "✓", 1.0, "#30d158", 1400, false);
    }

    function refreshClipboard() {
        if (!clipListProc.running) clipListProc.running = true;
    }

    function copyClipId(entryId, preview) {
        clipCopyProc.command = ["bash", "-c", "cliphist decode " + shellQuote(entryId) + " | wl-copy"];
        clipCopyProc.running = true;
        state.showHud("clipboard", "Copied to Clipboard", preview.slice(0, 44), "✓", 1.0, "#5e9cff", 1400, false);
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function runDetached(cmd) {
        detachProc.command = ["bash", "-c", "setsid -f " + cmd + " >/dev/null 2>&1"];
        detachProc.running = true;
    }

    Process {
        id: shelfStatProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const added = JSON.parse(text.trim());
                    let list = state.shelfItems.slice();
                    for (const item of added) {
                        list = list.filter(x => x.path !== item.path);
                        list.unshift(item);
                    }
                    state.shelfItems = list.slice(0, 12);
                    state.saveState();
                } catch (e) {}
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: clipListProc
        running: false
        command: ["bash", "-c", "cliphist list 2>/dev/null | head -n 8"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0);
                const out = [];
                for (const line of lines) {
                    const tab = line.indexOf("\t");
                    if (tab > 0) {
                        out.push({
                            id: line.slice(0, tab).trim(),
                            preview: line.slice(tab + 1).replace(/\s+/g, " ").trim()
                        });
                    }
                }
                state.clipItems = out;
            }
        }
        stderr: StdioCollector {}
    }

    Process { id: clipCopyProc; running: false }
    Process { id: detachProc; running: false }

    Timer {
        interval: 2500
        running: state.expanded && state.currentPage === 4
        repeat: true
        triggeredOnStart: true
        onTriggered: state.refreshClipboard()
    }

    // ── System HUD Watchers (AC/Battery, Volume, Brightness, CapsLock, Bluetooth, Privacy) ──
    property bool _hwSeeded: false
    property int _lastAcOnline: -1
    property int _lastBatPct: -1
    property bool _lowBatWarned: false
    property real _lastVol: -1
    property bool _lastMuted: false
    property real brightness: 1.0
    property real _lastBrightness: -1
    property int _lastCaps: -1
    property var _lastBtDevices: []
    property bool _btSeeded: false
    property bool micActive: false
    property bool recActive: false

    // ── Live Screen Recording (gpu-screen-recorder) in Dynamic Island ──
    property bool gsrRecording: false
    property double gsrStartTs: 0
    property int gsrElapsedSec: 0
    property string lastRecordingPath: ""
    readonly property string gsrElapsedText: {
        const sTotal = Math.max(0, gsrElapsedSec);
        const h = Math.floor(sTotal / 3600);
        const m = Math.floor((sTotal % 3600) / 60);
        const s = sTotal % 60;
        if (h > 0) return h + ":" + ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2);
        return ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2);
    }

    function stopRecording() {
        runDetached("bash ~/.config/hypr/scripts/record_screen.sh screen");
    }

    function openLastRecording() {
        const p = (state.lastRecordingPath || "").trim();
        if (!p) return;
        state.clearHud();
        runDetached("mpv " + shellQuote(p));
    }

    Timer {
        id: gsrTickTimer
        interval: 500
        running: state.gsrRecording
        repeat: true
        onTriggered: {
            if (state.gsrStartTs > 0) {
                state.gsrElapsedSec = Math.max(0, Math.floor(Date.now() / 1000 - state.gsrStartTs));
            }
        }
    }

    // Instant UI reaction when volume changes from our own wheel/controls
    Connections {
        target: Audio
        function onVolumeChanged() {
            if (!state._hwSeeded) return;
            if (Math.abs(Audio.volume - state._lastVol) < 0.008) return;
            state._lastVol = Audio.volume;
            const pct = Math.round(Audio.volume * 100);
            state.showHud("volume", Audio.muted ? "Muted" : "Volume", "Audio output", pct + "%", Audio.volume, Audio.muted ? "#ff453a" : "#ffffff", 1800, false);
        }
        function onMutedChanged() {
            if (!state._hwSeeded) return;
            if (Audio.muted === state._lastMuted) return;
            state._lastMuted = Audio.muted;
            const pct = Math.round(Audio.volume * 100);
            state.showHud("volume", Audio.muted ? "Muted" : "Unmuted", "Audio output", Audio.muted ? "OFF" : (pct + "%"), Audio.muted ? 0 : Audio.volume, Audio.muted ? "#ff453a" : "#ffffff", 1800, false);
        }
    }

    // Lightweight kernel/sysfs watcher (1100ms): AC charger, Battery %, CapsLock, Brightness, Volume, Recording
    Timer {
        interval: 1100
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!hwFastProc.running) hwFastProc.running = true;
        }
    }

    Process {
        id: hwFastProc
        running: false
        command: ["sh", "-c",
            "ac=$(cat /sys/class/power_supply/ACAD/online /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online 2>/dev/null | head -n1); " +
            "bp=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); " +
            "bs=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); " +
            "cl=$(cat /sys/class/leds/*::capslock/brightness 2>/dev/null | head -n1); " +
            "br=$(brightnessctl g 2>/dev/null || echo -1); bm=$(brightnessctl m 2>/dev/null || echo 1); " +
            "vo=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo ''); " +
            "gsr=$(pidof -s gpu-screen-recorder 2>/dev/null || true); " +
            "gst=$([ -n \"$gsr\" ] && cat \"$HOME/.cache/gsr_start_ts\" 2>/dev/null || echo 0); " +
            "gsv=$([ -z \"$gsr\" ] && [ -f \"$HOME/.cache/gsr_last_saved\" ] && cat \"$HOME/.cache/gsr_last_saved\" 2>/dev/null || echo ''); " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$ac\" \"$bp\" \"$bs\" \"$cl\" \"$br\" \"$bm\" \"$vo\" \"$gsr\" \"$gst\" \"$gsv\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                if (parts.length < 7) return;
                const ac = parts[0] !== "" ? parseInt(parts[0]) : -1;
                const bp = parts[1] !== "" ? parseInt(parts[1]) : Math.round(Battery.percentage * 100);
                const bs = (parts[2] || "").trim();
                const cl = parts[3] !== "" ? parseInt(parts[3]) : -1;
                const br = parseFloat(parts[4]);
                const bm = parseFloat(parts[5]);
                const vo = parts[6] || "";
                const gsrPid = parts.length > 7 ? (parts[7] || "").trim() : "";
                const gsrTs = parts.length > 8 ? parseFloat(parts[8]) : 0;
                const gsrSaved = parts.length > 9 ? (parts[9] || "").trim() : "";

                // Live Screen Recording tracking (gpu-screen-recorder)
                const isRecNow = gsrPid.length > 0;
                if (isRecNow) {
                    if (!state.gsrRecording) {
                        state.gsrStartTs = (!isNaN(gsrTs) && gsrTs > 0) ? gsrTs : Math.floor(Date.now() / 1000);
                        state.gsrElapsedSec = Math.max(0, Math.floor(Date.now() / 1000 - state.gsrStartTs));
                        state.gsrRecording = true;
                    }
                } else if (state.gsrRecording) {
                    const durText = state.gsrElapsedText;
                    state.gsrRecording = false;
                    state.gsrStartTs = 0;
                    state.gsrElapsedSec = 0;
                    state.lastRecordingPath = gsrSaved;
                    const shortName = gsrSaved.length > 0 ? gsrSaved.split("/").pop() : ("Duración " + durText);
                    state.showHud(
                        "record_saved",
                        "Grabación guardada",
                        shortName,
                        "✓",
                        1.0,
                        "#30d158",
                        6000,
                        false
                    );
                }

                let vol = -1, muted = false;
                const vm = vo.match(/([\d.]+)/);
                if (vm) vol = Math.max(0, Math.min(1.5, parseFloat(vm[1])));
                muted = vo.includes("MUTED");

                let bRatio = -1;
                if (!isNaN(br) && !isNaN(bm) && br >= 0 && bm > 0) {
                    bRatio = Math.max(0, Math.min(1, br / bm));
                    state.brightness = bRatio;
                }

                if (!state._hwSeeded) {
                    state._lastAcOnline = ac;
                    state._lastBatPct = bp;
                    state._lastCaps = cl;
                    state._lastBrightness = bRatio;
                    state._lastVol = vol;
                    state._lastMuted = muted;
                    state._hwSeeded = true;
                    return;
                }

                // 1. Charger plugged / unplugged (instant via /sys/class/power_supply/ACAD/online!)
                if (ac !== -1 && ac !== state._lastAcOnline) {
                    state._lastAcOnline = ac;
                    const pct = isNaN(bp) ? Math.round(Battery.percentage * 100) : bp;
                    if (ac === 1) {
                        state._lowBatWarned = false;
                        const isFull = bs === "Full" || pct >= 100;
                        state.showHud(
                            "battery",
                            isFull ? "Fully Charged" : "Charging",
                            "Charger connected",
                            pct + "%",
                            pct / 100.0,
                            "#34d399",
                            3200,
                            false
                        );
                    } else {
                        state.showHud(
                            "battery_off",
                            "On Battery",
                            "Charger disconnected",
                            pct + "%",
                            pct / 100.0,
                            pct <= 20 ? "#ff453a" : "#ff9f0a",
                            2600,
                            false
                        );
                    }
                } else if (ac === 0 && !isNaN(bp) && bp <= 20 && !state._lowBatWarned) {
                    state._lowBatWarned = true;
                    state.showHud("battery_off", "Low Battery", "Plug in charger soon", bp + "%", bp / 100.0, "#ff453a", 3800, false);
                }

                // 2. Caps Lock toggle
                if (cl !== -1 && cl !== state._lastCaps) {
                    state._lastCaps = cl;
                    state.showHud(
                        "capslock",
                        "Caps Lock",
                        cl === 1 ? "Uppercase enabled" : "Uppercase disabled",
                        cl === 1 ? "ON" : "OFF",
                        cl === 1 ? 1.0 : 0.0,
                        cl === 1 ? "#5e9cff" : "#8e8e98",
                        1600,
                        false
                    );
                }

                // 3. Brightness change
                if (bRatio >= 0 && state._lastBrightness >= 0 && Math.abs(bRatio - state._lastBrightness) >= 0.01) {
                    state._lastBrightness = bRatio;
                    state.showHud("brightness", "Brightness", "Display", Math.round(bRatio * 100) + "%", bRatio, "#ffd60a", 1800, false);
                }

                // 4. Volume / Mute change (catches hardware keyboard volume keys immediately!)
                if (vol >= 0 && state._lastVol >= 0) {
                    const volChanged = Math.abs(vol - state._lastVol) >= 0.008;
                    const muteChanged = muted !== state._lastMuted;
                    if (volChanged || muteChanged) {
                        state._lastVol = vol;
                        state._lastMuted = muted;
                        const pct = Math.round(vol * 100);
                        state.showHud(
                            "volume",
                            muted ? "Muted" : "Volume",
                            "Audio output",
                            muted ? "OFF" : (pct + "%"),
                            muted ? 0 : Math.min(1, vol),
                            muted ? "#ff453a" : "#ffffff",
                            1800,
                            false
                        );
                    }
                }
            }
        }
        stderr: StdioCollector {}
    }

    // ── Real-time BlueZ Bluetooth watcher (Connecting / Connected / Disconnected + Battery) ──
    readonly property var btAdapter: Bluetooth.defaultAdapter
    property var _btStateMap: ({})

    function _btDeviceName(dev) {
        if (!dev) return "Bluetooth";
        const n = String(dev.name || dev.deviceName || "").trim();
        return n.length > 0 ? n : "Bluetooth";
    }

    function _handleBtDeviceState(dev) {
        if (!dev) return;
        const key = String(dev.address || dev.name || "");
        if (!key) return;
        const cur = dev.state;
        const prev = state._btStateMap[key];
        const nextMap = Object.assign({}, state._btStateMap);
        nextMap[key] = cur;
        state._btStateMap = nextMap;

        // First observation (initial seed) — don't spam HUD on startup
        if (prev === undefined || prev === cur) return;

        const name = _btDeviceName(dev);
        if (cur === BluetoothDeviceState.Connecting) {
            state.showHud("bluetooth_connecting", name, "Conectando…", "•••", 0.35, "#38bdf8", 12000, false);
        } else if (cur === BluetoothDeviceState.Connected) {
            const hasBat = !!dev.batteryAvailable && !isNaN(dev.battery) && dev.battery > 0;
            const batRatio = hasBat ? Math.max(0.05, Math.min(1.0, dev.battery > 1 ? dev.battery / 100.0 : dev.battery)) : 1.0;
            const batText = hasBat ? (Math.round(batRatio * 100) + "%") : "✓";
            const accentCol = hasBat ? (batRatio <= 0.2 ? "#ff9f0a" : "#30d158") : "#3b9eff";
            state.showHud("bluetooth", name, "Conectado", batText, batRatio, accentCol, 3800, false);
        } else if (cur === BluetoothDeviceState.Disconnected && (prev === BluetoothDeviceState.Connected || prev === BluetoothDeviceState.Disconnecting)) {
            state.showHud("bluetooth_off", name, "Desconectado", "OFF", 0.0, "#8e8e98", 2400, false);
        } else if (cur === BluetoothDeviceState.Disconnected && prev === BluetoothDeviceState.Connecting) {
            state.showHud("bluetooth_off", name, "No se pudo conectar", "✕", 0.0, "#ff453a", 2400, false);
        }
    }

    // Watch adapter discovery ("Buscando dispositivos…")
    Connections {
        target: state.btAdapter
        ignoreUnknownSignals: true
        function onDiscoveringChanged() {
            if (!state.btAdapter) return;
            if (state.btAdapter.discovering) {
                state.showHud("bluetooth_connecting", "Bluetooth", "Buscando dispositivos…", "•••", 0.35, "#38bdf8", 6000, false);
            } else if (state.hudType === "bluetooth_connecting" && state.hudTitle === "Bluetooth") {
                state.clearHud();
            }
        }
    }

    // Watch every known BlueZ device in real time for Connecting / Connected / Disconnected
    Instantiator {
        model: state.btAdapter ? state.btAdapter.devices : null
        delegate: QtObject {
            required property var modelData
            Component.onCompleted: {
                if (modelData) {
                    const key = String(modelData.address || modelData.name || "");
                    if (key) {
                        const m = Object.assign({}, state._btStateMap);
                        m[key] = modelData.state;
                        state._btStateMap = m;
                    }
                }
            }
            property var _conn: Connections {
                target: modelData
                function onStateChanged() {
                    state._handleBtDeviceState(modelData);
                }
                function onBatteryChanged() {
                    if (modelData && modelData.state === BluetoothDeviceState.Connected
                        && state.hudType === "bluetooth" && state.hudTitle === state._btDeviceName(modelData)
                        && modelData.batteryAvailable && modelData.battery > 0) {
                        const r = Math.max(0.05, Math.min(1.0, modelData.battery > 1 ? modelData.battery / 100.0 : modelData.battery));
                        state.hudProgress = r;
                        state.hudValueText = Math.round(r * 100) + "%";
                        state.hudAccent = r <= 0.2 ? "#ff9f0a" : "#30d158";
                    }
                }
            }
        }
    }

    // Demo helper to preview Connecting -> Connected animation
    Timer {
        id: btDemoStep2
        interval: 2200
        repeat: false
        onTriggered: {
            state.showHud("bluetooth", "AirPods Pro", "Conectado", "85%", 0.85, "#30d158", 3400, false);
        }
    }
    function demoBluetoothAnimation() {
        state.showHud("bluetooth_connecting", "AirPods Pro", "Conectando…", "•••", 0.35, "#38bdf8", 3000, false);
        btDemoStep2.restart();
    }

    // Privacy watcher (mic / screen recording dots, 2.2s)
    Timer {
        interval: 2200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!btPrivacyProc.running) btPrivacyProc.running = true;
        }
    }

    Process {
        id: btPrivacyProc
        running: false
        command: ["bash", "-c",
            "mic=$(pactl list source-outputs 2>/dev/null | grep -c 'Source Output #' || echo 0); " +
            "rec=$(pw-dump 2>/dev/null | grep -ciE '\"(media.name|media.class)\": \"[^\"]*(screencast|screen cast|screen-capture|screen capture)\"' || echo 0); " +
            "gsr=$(pidof gpu-screen-recorder >/dev/null 2>&1 && echo 1 || echo 0); " +
            "rec=$((rec + gsr)); " +
            "echo \"PRIV|$mic|$rec\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                for (const line of lines) {
                    if (line.startsWith("PRIV|")) {
                        const p = line.split("|");
                        if (p.length >= 3) {
                            state.micActive = parseInt(p[1]) > 0;
                            state.recActive = parseInt(p[2]) > 0;
                        }
                    }
                }
            }
        }
        stderr: StdioCollector {}
    }

    // ── Local JSON State Persistence ──────────────────────────────
    readonly property string statePath: "__USER_HOME__/.local/share/quickshell/island/state.json"

    function loadState() {
        loadProc.running = true;
    }

    function saveState() {
        const payload = JSON.stringify({
            waterDateKey: state.waterDateKey || todayKey(),
            waterMl: state.waterMl,
            waterGoalMl: state.waterGoalMl,
            waterReminderOn: state.waterReminderOn,
            waterIntervalMin: state.waterIntervalMin,
            waterHourly: state.waterHourly,
            todos: state.todos,
            shelfItems: state.shelfItems,
            statusRingMode: state.statusRingMode
        });
        saveProc.command = [
            "python3", "-c",
            "import os,sys\np=sys.argv[1]\nos.makedirs(os.path.dirname(p),exist_ok=True)\nwith open(p,'w',encoding='utf-8') as f: f.write(sys.argv[2])",
            state.statePath,
            payload
        ];
        saveProc.running = true;
    }

    Process {
        id: loadProc
        running: false
        command: ["bash", "-c", "cat " + state.statePath + " 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim() || "{}");
                    const today = state.todayKey();
                    if (d.waterDateKey === today) {
                        if (typeof d.waterMl === "number") state.waterMl = d.waterMl;
                        if (d.waterHourly && typeof d.waterHourly === "object") state.waterHourly = d.waterHourly;
                        state.waterDateKey = today;
                    } else {
                        state.waterDateKey = today;
                        state.waterMl = 0;
                        state.waterHourly = {};
                    }
                    if (typeof d.waterGoalMl === "number" && d.waterGoalMl >= 500) state.waterGoalMl = d.waterGoalMl;
                    if (typeof d.waterReminderOn === "boolean") state.waterReminderOn = d.waterReminderOn;
                    if (typeof d.waterIntervalMin === "number" && d.waterIntervalMin >= 10) state.waterIntervalMin = d.waterIntervalMin;
                    if (Array.isArray(d.todos)) state.todos = d.todos;
                    if (Array.isArray(d.shelfItems)) state.shelfItems = d.shelfItems;
                    if (d.statusRingMode === "battery" || d.statusRingMode === "water") state.statusRingMode = d.statusRingMode;
                } catch (e) {}
                state.updateNextWaterTime();
            }
        }
        stderr: StdioCollector {}
    }

    Process { id: saveProc; running: false }

    Component.onCompleted: {
        state.pickPlayers();
        state.loadState();
        state.updateNextWaterTime();
    }
}
