import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.config
import qs.ui.controls.providers
import qs.core.system
import qs

// Apple Music / macOS Fullscreen Lyrics Lock Screen View
// Automatically active on the Lock Screen whenever music is detected.
Item {
    id: view

    property bool active: false
    property Item backdropItem: null
    property Item coordRoot: null
    signal closeRequested()
    signal focusPasswordRequested()

    readonly property var pl: MusicPlayerProvider.activePlayer
    readonly property real k: Math.min(Math.max(Math.min(width / 1440, height / 900), 0.78), 1.32)

    visible: opacity > 0.01
    opacity: active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

    onActiveChanged: {
        if (active) {
            MusicPlayerProvider.lyricsWanted = true;
            volReadProc.running = false;
            volReadProc.running = true;
        }
    }

    Component.onCompleted: {
        if (active) {
            MusicPlayerProvider.lyricsWanted = true;
            volReadProc.running = true;
        }
    }

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec || 0));
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2);
    }

    // ── Live PipeWire Volume Sync ─────────────────────────────────
    property real volume: 0.7
    property bool muted: false
    property bool draggingVol: false

    Process {
        id: volReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (view.draggingVol) return;
                const t = (text || "").trim();
                const m = t.match(/([\d.]+)/);
                if (m) view.volume = Math.max(0, Math.min(1.0, parseFloat(m[1])));
                view.muted = t.indexOf("MUTED") >= 0;
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: view.active && !view.draggingVol
        onTriggered: {
            if (!volReadProc.running) volReadProc.running = true;
        }
    }

    Process { id: volSetProc }
    function setVolume(v) {
        const clamped = Math.max(0, Math.min(1.0, v));
        view.volume = clamped;
        view.muted = clamped <= 0.005;
        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(2)];
        volSetProc.running = false;
        volSetProc.running = true;
    }

    // Subtle dark atmospheric veil over the flowing blurred album art
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.07, 0.12, 0.42) }
            GradientStop { position: 0.5; color: Qt.rgba(0.04, 0.06, 0.10, 0.50) }
            GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.04, 0.08, 0.62) }
        }
    }

    // ── Top-Left Close Button (switch back to standard lock screen) ──
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 28 * view.k
        anchors.leftMargin: 28 * view.k
        width: 34 * view.k
        height: 34 * view.k
        z: 10

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)
            Behavior on color { ColorAnimation { duration: 150 } }
            Image {
                anchors.centerIn: parent
                width: 12 * view.k
                height: 12 * view.k
                source: Qt.resolvedUrl("icons/close.png")
                sourceSize: Qt.size(32, 32)
                smooth: true
                opacity: 0.9
            }
        }
        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                view.closeRequested();
                view.focusPasswordRequested();
            }
        }
    }

    // ── Top-Right Retry Lyrics Button (balanced circular button) ──
    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 28 * view.k
        anchors.rightMargin: 28 * view.k
        width: 34 * view.k
        height: 34 * view.k
        z: 10

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: retryMa.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
                anchors.centerIn: parent
                text: "↻"
                color: "#ffffff"
                font.pixelSize: 15 * view.k
                font.weight: Font.Bold
                opacity: 0.92
            }
        }
        MouseArea {
            id: retryMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                MusicPlayerProvider.fetchLyrics(true);
                view.focusPasswordRequested();
            }
        }
    }

    // ── Top-Center MacSDDM Liquid Glass Clock ─────────────────────
    MacGlassClock {
        id: heroClock
        anchors.top: parent.top
        anchors.topMargin: 76 * view.k
        anchors.horizontalCenter: parent.horizontalCenter
        backdropItem: view.backdropItem
        coordRoot: view.coordRoot ? view.coordRoot : view
        scaleFactor: view.k
        clockPx: 112 * view.k
        showDate: false
        glassIntensity: 0.36
        glassRefraction: 13
        glassTint: "#DCE5F0"
    }

    // ── Main Two-Column Stage (Optically centered right beneath the clock) ──
    Item {
        id: stage
        anchors.top: heroClock.bottom
        anchors.topMargin: 36 * view.k
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 52 * view.k
        anchors.horizontalCenter: parent.horizontalCenter
        readonly property real colGap: 42 * view.k
        readonly property real artColW: Math.min(316 * view.k, parent.width * 0.28)
        readonly property real lyrColW: Math.min(480 * view.k, parent.width * 0.42)
        width: Math.min(parent.width - 96 * view.k, artColW + colGap + lyrColW)

        // ── LEFT COLUMN: Square Cover Art + Title/Artist + Glass Media Card ──
        Column {
            id: leftCol
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: stage.artColW
            spacing: 12 * view.k

            // Square Rounded Album Art
            Item {
                id: coverHolder
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real artSize: Math.min(leftCol.width, stage.height * 0.58, 306 * view.k)
                width: artSize
                height: artSize
                scale: MusicPlayerProvider.isPlaying ? 1.0 : 0.94
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

                RectangularShadow {
                    anchors.fill: parent
                    radius: coverClip.radius
                    blur: 44
                    offset.y: 16
                    color: Qt.rgba(0, 0, 0, 0.48)
                }

                ClippingRectangle {
                    id: coverClip
                    anchors.fill: parent
                    radius: 14 * view.k
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: MusicPlayerProvider.hdThumbnail || MusicPlayerProvider.thumbnail
                        sourceSize: Qt.size(1200, 1200)
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: coverImage.status !== Image.Ready
                        text: "\u266A"
                        font.pixelSize: 54 * view.k
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: coverClip.radius
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                    }
                }
            }

            // Centered Title & Artist
            Column {
                width: coverHolder.width
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2 * view.k

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: MusicPlayerProvider.title
                    color: "#ffffff"
                    font.family: Fonts.sFProDisplayRegular.family
                    font.pixelSize: 15.5 * view.k
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: MusicPlayerProvider.artist
                    color: Qt.rgba(1, 1, 1, 0.66)
                    font.family: Fonts.sFProDisplayRegular.family
                    font.pixelSize: 12.5 * view.k
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            // Frosted Glass Media Control Card (Scrubber + Transport + Volume)
            Rectangle {
                id: controlCard
                anchors.horizontalCenter: parent.horizontalCenter
                width: coverHolder.width
                height: 102 * view.k
                radius: 16 * view.k
                color: Qt.rgba(1, 1, 1, 0.085)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)

                // Subtle top highlight sheen
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.02) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.06) }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 15 * view.k
                    anchors.rightMargin: 15 * view.k
                    anchors.topMargin: 10 * view.k
                    anchors.bottomMargin: 10 * view.k
                    spacing: 7 * view.k

                    // ── Row 1: Scrubber (0:15  ───●────────  -4:36) ──
                    Item {
                        id: scrubRow
                        width: parent.width
                        height: 18 * view.k
                        readonly property real len: MusicPlayerProvider.duration || 0
                        property real dragPos: -1
                        readonly property real shown: dragPos >= 0 ? dragPos : MusicPlayerProvider.exactPosition
                        readonly property real frac: len > 0 ? Math.max(0, Math.min(1, shown / len)) : 0

                        Text {
                            id: elapsedLbl
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: view.fmt(scrubRow.shown)
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font.family: Fonts.sFProDisplayRegular.family
                            font.pixelSize: 10.5 * view.k
                            font.weight: Font.Medium
                        }

                        Text {
                            id: remainLbl
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: scrubRow.len > 0 ? "-" + view.fmt(scrubRow.len - scrubRow.shown) : "--:--"
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font.family: Fonts.sFProDisplayRegular.family
                            font.pixelSize: 10.5 * view.k
                            font.weight: Font.Medium
                        }

                        Item {
                            id: scrubTrack
                            anchors.left: elapsedLbl.right
                            anchors.leftMargin: 8 * view.k
                            anchors.right: remainLbl.left
                            anchors.rightMargin: 8 * view.k
                            anchors.verticalCenter: parent.verticalCenter
                            height: 14 * view.k

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4.5 * view.k
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.24)

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * scrubRow.frac
                                    color: Qt.rgba(1, 1, 1, 0.92)
                                }
                            }

                            // Pill knob
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: (scrubMa.containsMouse || scrubMa.pressed ? 11 : 8) * view.k
                                height: width
                                radius: width / 2
                                x: Math.max(0, Math.min(parent.width - width, parent.width * scrubRow.frac - width / 2))
                                color: "#ffffff"
                                Behavior on width { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: scrubMa
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                function at(mx) {
                                    return Math.max(0, Math.min(1, (mx - 6) / Math.max(1, scrubTrack.width))) * scrubRow.len;
                                }
                                onPressed: (m) => { if (scrubRow.len > 0) scrubRow.dragPos = at(m.x); }
                                onPositionChanged: (m) => { if (pressed && scrubRow.len > 0) scrubRow.dragPos = at(m.x); }
                                onReleased: {
                                    if (scrubRow.dragPos >= 0) {
                                        MusicPlayerProvider.seekTo(scrubRow.dragPos);
                                        scrubRow.dragPos = -1;
                                    }
                                    view.focusPasswordRequested();
                                }
                            }
                        }
                    }

                    // ── Row 2: Transport (Shuffle | Prev | Play/Pause | Next | Repeat) ──
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18 * view.k

                        // Shuffle
                        Item {
                            width: 28 * view.k; height: 28 * view.k
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property bool canShuf: !!view.pl && view.pl.shuffleSupported
                            opacity: canShuf ? (view.pl.shuffle ? 1.0 : 0.65) : 0.35
                            Rectangle {
                                anchors.fill: parent; radius: width / 2
                                color: shufMa.containsMouse && parent.canShuf ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 14 * view.k; height: 14 * view.k
                                source: Qt.resolvedUrl("icons/shuffle.png")
                                sourceSize: Qt.size(48, 48); smooth: true; mipmap: true
                            }
                            MouseArea {
                                id: shufMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: parent.canShuf ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (parent.canShuf) view.pl.shuffle = !view.pl.shuffle;
                                    view.focusPasswordRequested();
                                }
                            }
                        }

                        // Previous
                        Item {
                            width: 32 * view.k; height: 32 * view.k
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                anchors.fill: parent; radius: width / 2
                                color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 20 * view.k; height: 20 * view.k
                                source: Qt.resolvedUrl(Quickshell.shellDir + "/media/icons/music/backward.svg")
                                sourceSize: Qt.size(48, 48); smooth: true
                            }
                            MouseArea {
                                id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { MusicPlayerProvider.previous(); view.focusPasswordRequested(); }
                            }
                        }

                        // Play / Pause
                        Item {
                            width: 38 * view.k; height: 38 * view.k
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                anchors.fill: parent; radius: width / 2
                                color: playMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : "transparent"
                                scale: playMa.pressed ? 0.90 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 26 * view.k; height: 26 * view.k
                                source: Qt.resolvedUrl(Quickshell.shellDir + "/media/icons/music/" + (MusicPlayerProvider.isPlaying ? "pause.svg" : "play.svg"))
                                sourceSize: Qt.size(64, 64); smooth: true
                            }
                            MouseArea {
                                id: playMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { MusicPlayerProvider.togglePlay(); view.focusPasswordRequested(); }
                            }
                        }

                        // Next
                        Item {
                            width: 32 * view.k; height: 32 * view.k
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                anchors.fill: parent; radius: width / 2
                                color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 20 * view.k; height: 20 * view.k
                                source: Qt.resolvedUrl(Quickshell.shellDir + "/media/icons/music/forward.svg")
                                sourceSize: Qt.size(48, 48); smooth: true
                            }
                            MouseArea {
                                id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { MusicPlayerProvider.next(); view.focusPasswordRequested(); }
                            }
                        }

                        // Repeat
                        Item {
                            width: 28 * view.k; height: 28 * view.k
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property bool canLoop: !!view.pl && view.pl.loopSupported
                            opacity: canLoop ? (view.pl.loopState !== MprisLoopState.None ? 1.0 : 0.65) : 0.35
                            Rectangle {
                                anchors.fill: parent; radius: width / 2
                                color: loopMa.containsMouse && parent.canLoop ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 14 * view.k; height: 14 * view.k
                                source: Qt.resolvedUrl("icons/repeat.png")
                                sourceSize: Qt.size(48, 48); smooth: true; mipmap: true
                            }
                            MouseArea {
                                id: loopMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: parent.canLoop ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (parent.canLoop) {
                                        view.pl.loopState = view.pl.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                            : view.pl.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                                    }
                                    view.focusPasswordRequested();
                                }
                            }
                        }
                    }

                    // ── Row 3: Volume Slider (🔈 ───────●── 🔊) ──
                    Item {
                        width: parent.width
                        height: 16 * view.k

                        Canvas {
                            id: volLowIco
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13 * view.k; height: 13 * view.k
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var s = width / 14;
                                ctx.scale(s, s);
                                ctx.fillStyle = "rgba(255,255,255,0.68)";
                                ctx.beginPath();
                                ctx.moveTo(2, 5); ctx.lineTo(5, 5); ctx.lineTo(8.5, 2.2);
                                ctx.lineTo(8.5, 11.8); ctx.lineTo(5, 9); ctx.lineTo(2, 9);
                                ctx.closePath(); ctx.fill();
                            }
                        }

                        Canvas {
                            id: volHighIco
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15 * view.k; height: 13 * view.k
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var s = height / 14;
                                ctx.scale(s, s);
                                ctx.fillStyle = "rgba(255,255,255,0.78)";
                                ctx.strokeStyle = "rgba(255,255,255,0.78)";
                                ctx.lineWidth = 1.3;
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.moveTo(1, 5); ctx.lineTo(3.8, 5); ctx.lineTo(7, 2.2);
                                ctx.lineTo(7, 11.8); ctx.lineTo(3.8, 9); ctx.lineTo(1, 9);
                                ctx.closePath(); ctx.fill();
                                ctx.beginPath(); ctx.arc(8.2, 7, 2.6, -0.75, 0.75); ctx.stroke();
                                ctx.beginPath(); ctx.arc(8.2, 7, 4.8, -0.8, 0.8); ctx.stroke();
                            }
                        }

                        Item {
                            id: volTrack
                            anchors.left: volLowIco.right
                            anchors.leftMargin: 8 * view.k
                            anchors.right: volHighIco.left
                            anchors.rightMargin: 8 * view.k
                            anchors.verticalCenter: parent.verticalCenter
                            height: 14 * view.k

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4.5 * view.k
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.24)

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * (view.muted ? 0 : view.volume)
                                    color: Qt.rgba(1, 1, 1, 0.92)
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: (volMa.containsMouse || volMa.pressed ? 11 : 8) * view.k
                                height: width
                                radius: width / 2
                                x: Math.max(0, Math.min(parent.width - width, parent.width * (view.muted ? 0 : view.volume) - width / 2))
                                color: "#ffffff"
                                Behavior on width { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: volMa
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                function at(mx) { return Math.max(0, Math.min(1, (mx - 6) / Math.max(1, volTrack.width))); }
                                onPressed: (m) => { view.draggingVol = true; view.setVolume(at(m.x)); }
                                onPositionChanged: (m) => { if (pressed) view.setVolume(at(m.x)); }
                                onReleased: { view.draggingVol = false; view.focusPasswordRequested(); }
                            }
                        }
                    }
                }
            }
        }

        // ── RIGHT COLUMN: Scrolling Synced Lyrics (Aligned top-to-bottom with Left Column) ──
        Item {
            id: lyricsPane
            anchors.left: leftCol.right
            anchors.leftMargin: stage.colGap
            anchors.right: parent.right
            anchors.verticalCenter: leftCol.verticalCenter
            height: leftCol.height
            clip: true

            readonly property real targetY: {
                const L = MusicPlayerProvider.lyricsLines;
                if (L.length === 0) return 0;
                const c = Math.max(0, MusicPlayerProvider.lyricsIndex);
                const it = lyrRep.itemAt(c);
                return it ? (it.y - height * 0.37) : (-height * 0.37);
            }

            // Empty / loading / retry state
            Column {
                anchors.centerIn: parent
                visible: MusicPlayerProvider.lyricsLines.length === 0
                spacing: 12 * view.k

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: MusicPlayerProvider.lyricsState === "loading"
                        ? "Buscando letra sincronizada…"
                        : "Sin letra disponible para esta canción"
                    color: Qt.rgba(1, 1, 1, 0.56)
                    font.family: Fonts.sFProDisplayRegular.family
                    font.pixelSize: 18 * view.k
                    font.weight: Font.Medium
                }

                Rectangle {
                    visible: MusicPlayerProvider.lyricsState !== "loading"
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: retryLbl.implicitWidth + 28 * view.k
                    height: 32 * view.k
                    radius: 16 * view.k
                    color: emptyRetryMa.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                    Text {
                        id: retryLbl
                        anchors.centerIn: parent
                        text: "↻ Reintentar búsqueda"
                        color: "#ffffff"
                        font.family: Fonts.sFProDisplayRegular.family
                        font.pixelSize: 12 * view.k
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: emptyRetryMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            MusicPlayerProvider.fetchLyrics(true);
                            view.focusPasswordRequested();
                        }
                    }
                }
            }

            // Scrolling lyrics list with soft top/bottom fade
            Item {
                anchors.fill: parent
                visible: MusicPlayerProvider.lyricsLines.length > 0
                layer.enabled: true
                layer.effect: ShaderEffect {
                    fragmentShader: Qt.resolvedUrl("fade.frag.qsb")
                    property real fadeTop: 0.16
                    property real fadeBottom: 0.22
                }

                Column {
                    id: lyrCol
                    width: parent.width
                    spacing: 16 * view.k
                    transform: Translate {
                        y: -lyricsPane.targetY
                        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                    }

                    Repeater {
                        id: lyrRep
                        model: MusicPlayerProvider.lyricsLines
                        delegate: Item {
                            id: lineItem
                            required property var modelData
                            required property int index
                            readonly property int curIdx: Math.max(0, MusicPlayerProvider.lyricsIndex)
                            readonly property int rel: index - curIdx
                            readonly property bool isCurrent: rel === 0
                            readonly property bool isEmpty: (modelData.text || "").trim() === ""
                            readonly property bool clickable: MusicPlayerProvider.lyricsSynced && modelData.t >= 0

                            width: lyrCol.width
                            height: isEmpty ? 16 * view.k : lineTxt.implicitHeight

                            Text {
                                id: lineTxt
                                visible: !lineItem.isEmpty
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: lineItem.modelData.text || ""
                                wrapMode: Text.WordWrap
                                color: "#ffffff"
                                font.family: Fonts.sFProDisplayRegular.family
                                font.pixelSize: (lineItem.isCurrent ? 24.0 : 19.5) * view.k
                                font.weight: lineItem.isCurrent ? Font.Bold : Font.Medium
                                lineHeight: 1.16
                                transformOrigin: Item.Center
                                scale: lineItem.isCurrent ? 1.03 : 0.98
                                opacity: {
                                    if (lineItem.isCurrent) return 1.0;
                                    if (lineMa.containsMouse && lineItem.clickable) return 0.80;
                                    const d = Math.abs(lineItem.rel);
                                    if (d === 1) return 0.48;
                                    if (d === 2) return 0.34;
                                    if (d === 3) return 0.26;
                                    return 0.20;
                                }
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
                                Behavior on font.pixelSize { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                layer.enabled: Math.abs(lineItem.rel) >= 2 && Math.abs(lineItem.rel) <= 5
                                layer.effect: MultiEffect {
                                    blurEnabled: true
                                    blurMax: 12
                                    blur: Math.min(0.26, 0.09 * (Math.abs(lineItem.rel) - 1))
                                }
                            }

                            // Subtle musical pause dots for instrumental gap lines
                            Row {
                                visible: lineItem.isEmpty
                                anchors.centerIn: parent
                                spacing: 5 * view.k
                                opacity: lineItem.isCurrent ? 0.85 : 0.28
                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        width: 5 * view.k; height: 5 * view.k; radius: 2.5 * view.k
                                        color: "#ffffff"
                                    }
                                }
                            }

                            MouseArea {
                                id: lineMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: lineItem.clickable
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    MusicPlayerProvider.seekTo(lineItem.modelData.t);
                                    view.focusPasswordRequested();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
