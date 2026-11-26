import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../common"

Item {
    id: root
    required property var ctrl

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 16

        // ── Left column: Album Art + Info + Scrubber + Transport ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: ctrl.lyricsOpen ? 245 : 390
            spacing: 7

            // Top section: Album art + Title / Artist + Lyrics toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Clickable Album Art (clicks cycle MPRIS players like Nusa 1.2!)
                Rectangle {
                    id: artBox
                    Layout.preferredWidth: ctrl.lyricsOpen ? 50 : 58
                    Layout.preferredHeight: ctrl.lyricsOpen ? 50 : 58
                    radius: 13
                    color: "#17171f"
                    border.color: artHover.containsMouse ? Qt.rgba(1, 1, 1, 0.32) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    clip: true

                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Image {
                        anchors.fill: parent
                        source: ctrl.trackArtUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: ctrl.trackArtUrl !== "" && status === Image.Ready
                    }

                    // Minimal vector music note fallback
                    Canvas {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        visible: ctrl.trackArtUrl === ""
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = "#5e9cff";
                            ctx.strokeStyle = "#5e9cff";
                            ctx.lineWidth = 2.2;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.moveTo(9, 17); ctx.lineTo(9, 6); ctx.lineTo(19, 4); ctx.lineTo(19, 15);
                            ctx.stroke();
                            ctx.beginPath(); ctx.arc(6.5, 17.5, 2.8, 0, Math.PI * 2); ctx.fill();
                            ctx.beginPath(); ctx.arc(16.5, 15.5, 2.8, 0, Math.PI * 2); ctx.fill();
                        }
                    }

                    MouseArea {
                        id: artHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: ctrl.players.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: ctrl.cyclePlayer()
                    }
                }

                // Track title + artist + lyrics chip
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: ctrl.trackTitle
                        font { family: Appearance.fontFamily; pixelSize: 14; weight: Font.Bold }
                        color: "#ffffff"
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: ctrl.trackArtist
                        font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Medium }
                        color: Qt.rgba(1, 1, 1, 0.56)
                        elide: Text.ElideRight
                    }

                    // Subtle Lyrics toggle pill
                    RowLayout {
                        Layout.topMargin: 2
                        spacing: 6
                        visible: ctrl.hasMedia

                        Rectangle {
                            height: 18
                            width: lyrTxt.implicitWidth + 14
                            radius: 9
                            color: ctrl.lyricsOpen ? Qt.rgba(ctrl.artAccent.r, ctrl.artAccent.g, ctrl.artAccent.b, 0.28) : (lyrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                            border.color: ctrl.lyricsOpen ? ctrl.artAccent : "transparent"
                            border.width: 1

                            Text {
                                id: lyrTxt
                                anchors.centerIn: parent
                                text: ctrl.lyricsOpen ? "Lyrics ON" : "Lyrics"
                                font { family: Appearance.fontFamily; pixelSize: 9; weight: Font.DemiBold }
                                color: ctrl.lyricsOpen ? "#ffffff" : Qt.rgba(1, 1, 1, 0.74)
                            }

                            MouseArea {
                                id: lyrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctrl.lyricsOpen = !ctrl.lyricsOpen
                            }
                        }

                        Text {
                            visible: ctrl.playerName !== "" && !ctrl.lyricsOpen
                            text: ctrl.playerName
                            font { family: Appearance.fontFamily; pixelSize: 9 }
                            color: Qt.rgba(1, 1, 1, 0.36)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Scrubber row: elapsed — interactive bar with hover/drag timestamp preview — remaining
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: ctrl.fmtTime(ctrl.displayPosition)
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Medium }
                    color: Qt.rgba(1, 1, 1, 0.64)
                    Layout.preferredWidth: 32
                }

                Item {
                    id: scrubTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    readonly property bool canScrub: ctrl.trackLength > 1 && ctrl.activePlayer && ctrl.activePlayer.canSeek
                    readonly property real ratio: ctrl.trackLength > 1
                        ? Math.max(0, Math.min(1, ctrl.displayPosition / ctrl.trackLength)) : 0
                    property real hoverX: 0
                    readonly property real hoverSec: ctrl.trackLength > 1
                        ? Math.max(0, Math.min(ctrl.trackLength, (hoverX / Math.max(1, width)) * ctrl.trackLength)) : 0
                    readonly property bool activeScrub: scrubTrack.canScrub && (scrubMa.containsMouse || ctrl.scrubbing)

                    // Floating exact-minute preview bubble above cursor on hover / drag
                    Rectangle {
                        visible: scrubTrack.activeScrub && ctrl.trackLength > 0
                        z: 10
                        x: Math.max(0, Math.min(parent.width - width, (ctrl.scrubbing ? parent.width * scrubTrack.ratio : scrubTrack.hoverX) - width / 2))
                        y: -17
                        width: tipTimeTxt.implicitWidth + 10
                        height: 16
                        radius: 8
                        color: Qt.rgba(0.08, 0.08, 0.12, 0.92)
                        border.color: Qt.rgba(1, 1, 1, 0.24)
                        border.width: 1

                        Text {
                            id: tipTimeTxt
                            anchors.centerIn: parent
                            text: ctrl.fmtTime(ctrl.scrubbing ? ctrl.scrubPosition : scrubTrack.hoverSec)
                            font { family: Appearance.fontFamily; pixelSize: 9; weight: Font.Bold }
                            color: "#ffffff"
                        }
                    }

                    Rectangle {
                        id: trackBg
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: scrubTrack.activeScrub ? 6 : 4
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.18)
                        Behavior on height { NumberAnimation { duration: 120 } }

                        Rectangle {
                            id: fillBar
                            width: Math.max(0, Math.min(parent.width, parent.width * scrubTrack.ratio))
                            height: parent.height
                            radius: height / 2
                            color: ctrl.hasMedia ? ctrl.artAccent : "#ffffff"
                            Behavior on color { ColorAnimation { duration: 450 } }
                        }
                    }

                    // Crisp glowing scrub knob locked to the exact right edge of fillBar
                    Rectangle {
                        visible: ctrl.trackLength > 0 && scrubTrack.activeScrub
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, fillBar.width - width / 2))
                        width: ctrl.scrubbing ? 12 : 10
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        border.color: ctrl.artAccent
                        border.width: 1.5
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: scrubMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: scrubTrack.canScrub
                        preventStealing: true
                        cursorShape: scrubTrack.canScrub ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function posFromX(mx) {
                            const f = Math.max(0, Math.min(1, mx / Math.max(1, width)));
                            return f * ctrl.trackLength;
                        }
                        onPressed: (m) => {
                            if (!scrubTrack.canScrub) return;
                            scrubTrack.hoverX = m.x;
                            ctrl.scrubbing = true;
                            ctrl.scrubPosition = posFromX(m.x);
                        }
                        onPositionChanged: (m) => {
                            scrubTrack.hoverX = m.x;
                            if (ctrl.scrubbing) ctrl.scrubPosition = posFromX(m.x);
                        }
                        onReleased: (m) => {
                            if (!ctrl.scrubbing) return;
                            const target = posFromX(m.x);
                            ctrl.scrubbing = false;
                            if (scrubTrack.canScrub) ctrl.seekTo(target);
                        }
                        onCanceled: {
                            ctrl.scrubbing = false;
                        }
                    }
                }

                Text {
                    text: ctrl.fmtRemaining(ctrl.displayPosition, ctrl.trackLength)
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Medium }
                    color: Qt.rgba(1, 1, 1, 0.64)
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 36
                }
            }

            // Minimal white transport controls (crisp monochrome Canvas glyphs)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                // Previous
                Item {
                    width: 28; height: 22
                    opacity: prevMa.containsMouse ? 1.0 : 0.84
                    scale: prevMa.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Canvas {
                        anchors.centerIn: parent; width: 18; height: 14
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = "#ffffff";
                            // Two left-pointing triangles
                            ctx.beginPath(); ctx.moveTo(9, 2); ctx.lineTo(2, 7); ctx.lineTo(9, 12); ctx.closePath(); ctx.fill();
                            ctx.beginPath(); ctx.moveTo(16, 2); ctx.lineTo(9, 7); ctx.lineTo(16, 12); ctx.closePath(); ctx.fill();
                        }
                    }
                    MouseArea {
                        id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (ctrl.activePlayer) ctrl.activePlayer.previous()
                    }
                }

                // Play / Pause
                Item {
                    width: 30; height: 24
                    opacity: playMa.containsMouse ? 1.0 : 0.92
                    scale: playMa.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Canvas {
                        id: playCanvas
                        anchors.centerIn: parent; width: 16; height: 16
                        property bool playing: ctrl.isPlaying
                        onPlayingChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = "#ffffff";
                            if (playing) {
                                ctx.fillRect(3, 2, 3.5, 12);
                                ctx.fillRect(9.5, 2, 3.5, 12);
                            } else {
                                ctx.beginPath();
                                ctx.moveTo(4, 2); ctx.lineTo(14, 8); ctx.lineTo(4, 14);
                                ctx.closePath(); ctx.fill();
                            }
                        }
                    }
                    MouseArea {
                        id: playMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (ctrl.activePlayer && ctrl.activePlayer.canTogglePlaying)
                                ctrl.activePlayer.togglePlaying();
                        }
                    }
                }

                // Next
                Item {
                    width: 28; height: 22
                    opacity: nextMa.containsMouse ? 1.0 : 0.84
                    scale: nextMa.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Canvas {
                        anchors.centerIn: parent; width: 18; height: 14
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = "#ffffff";
                            ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(9, 7); ctx.lineTo(2, 12); ctx.closePath(); ctx.fill();
                            ctx.beginPath(); ctx.moveTo(9, 2); ctx.lineTo(16, 7); ctx.lineTo(9, 12); ctx.closePath(); ctx.fill();
                        }
                    }
                    MouseArea {
                        id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (ctrl.activePlayer) ctrl.activePlayer.next()
                    }
                }
            }
        }

        // ── Right column: Synced Lyrics (3-line Nusa cascade) ─────
        Item {
            visible: ctrl.lyricsOpen
            Layout.fillHeight: true
            Layout.preferredWidth: 265
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                width: 1
                color: Qt.rgba(1, 1, 1, 0.10)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 4
                spacing: 6

                Item { Layout.fillHeight: true }

                // Previous lyric line (click to jump back to this line!)
                Text {
                    Layout.fillWidth: true
                    text: ctrl.prevLyricText
                    visible: text.length > 0
                    font { family: Appearance.fontFamily; pixelSize: 12; weight: Font.Medium }
                    color: prevLyrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(1, 1, 1, 0.36)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    MouseArea {
                        id: prevLyrMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: ctrl.lyricsSynced ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: ctrl.jumpToLyricOffset(-1)
                    }
                }

                // Current active lyric line (bright bold white)
                Text {
                    id: activeLyricLabel
                    Layout.fillWidth: true
                    text: ctrl.currentLyricText
                    font { family: Appearance.fontFamily; pixelSize: 14; weight: Font.Bold }
                    color: "#ffffff"
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 1.15

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: activeLyricLabel; property: "opacity"; to: 0.45; duration: 70 }
                            PropertyAction { target: activeLyricLabel; property: "text" }
                            NumberAnimation { target: activeLyricLabel; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Upcoming lyric line (click to jump forward to this line!)
                Text {
                    Layout.fillWidth: true
                    text: ctrl.nextLyricText
                    visible: text.length > 0
                    font { family: Appearance.fontFamily; pixelSize: 12; weight: Font.Medium }
                    color: nextLyrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.76) : Qt.rgba(1, 1, 1, 0.40)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    MouseArea {
                        id: nextLyrMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: ctrl.lyricsSynced ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: ctrl.jumpToLyricOffset(1)
                    }
                }

                // Small retry pill if no lyrics were found
                Rectangle {
                    visible: !ctrl.lyricsLoading && ctrl.lyricsLines.length === 0 && ctrl.hasMedia
                    Layout.alignment: Qt.AlignLeft
                    height: 20
                    width: retryTxt.implicitWidth + 14
                    radius: 10
                    color: retryMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.10)
                    Text {
                        id: retryTxt; anchors.centerIn: parent
                        text: "↻ Retry search"
                        font { family: Appearance.fontFamily; pixelSize: 9; weight: Font.DemiBold }
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: retryMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.fetchLyricsIfNeeded(true)
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── Multi-Source Audio Switcher Bar (ONLY visible when 2+ sources play simultaneously) ──
    RowLayout {
        visible: ctrl.showMultiSources
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        spacing: 6

        Repeater {
            model: ctrl.players
            delegate: Rectangle {
                id: srcPill
                required property var modelData
                required property int index
                readonly property bool isSelected: index === ctrl.playerIndex
                readonly property bool isSrcPlaying: modelData && modelData.playbackState === MprisPlaybackState.Playing
                readonly property string srcTitle: (modelData && modelData.trackTitle) ? String(modelData.trackTitle) : ctrl.playerLabel(modelData)
                readonly property string srcArt: (modelData && modelData.trackArtUrl) ? String(modelData.trackArtUrl) : ""

                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 10
                color: isSelected
                    ? Qt.rgba(ctrl.artAccent.r, ctrl.artAccent.g, ctrl.artAccent.b, 0.24)
                    : (srcMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                border.width: 1
                border.color: isSelected
                    ? Qt.rgba(ctrl.artAccent.r, ctrl.artAccent.g, ctrl.artAccent.b, 0.65)
                    : (isSrcPlaying ? Qt.rgba(0.19, 0.82, 0.35, 0.45) : Qt.rgba(1, 1, 1, 0.10))
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: srcMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.selectPlayer(srcPill.index)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 4
                    spacing: 6

                    // Mini cover art + live green dot when playing
                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18

                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: "#1b1b24"
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: srcPill.srcArt
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                visible: srcPill.srcArt !== "" && status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: srcPill.srcArt === ""
                                text: "♪"
                                font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                                color: "#5e9cff"
                            }
                        }

                        Rectangle {
                            visible: srcPill.isSrcPlaying
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -1
                            anchors.bottomMargin: -1
                            width: 6
                            height: 6
                            radius: 3
                            color: "#30d158"
                            border.width: 1
                            border.color: "#09090e"
                        }
                    }

                    // Track title + source tag
                    Text {
                        Layout.fillWidth: true
                        text: srcPill.srcTitle
                        font { family: Appearance.fontFamily; pixelSize: 10; weight: srcPill.isSelected ? Font.Bold : Font.Medium }
                        color: srcPill.isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.76)
                        elide: Text.ElideRight
                    }

                    // Inline Play / Pause button for THIS specific player
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: srcPlayMa.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.26)
                            : (srcPill.isSrcPlaying ? Qt.rgba(0.19, 0.82, 0.35, 0.24) : Qt.rgba(1, 1, 1, 0.10))
                        scale: srcPlayMa.pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }

                        Canvas {
                            id: miniPlayIco
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            property bool playing: srcPill.isSrcPlaying
                            onPlayingChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.fillStyle = playing ? "#30d158" : "#ffffff";
                                if (playing) {
                                    ctx.fillRect(2, 1.5, 2.2, 7);
                                    ctx.fillRect(5.8, 1.5, 2.2, 7);
                                } else {
                                    ctx.beginPath();
                                    ctx.moveTo(2.5, 1.5);
                                    ctx.lineTo(8.5, 5);
                                    ctx.lineTo(2.5, 8.5);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                        }

                        MouseArea {
                            id: srcPlayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctrl.togglePlayerAt(srcPill.index)
                        }
                    }
                }
            }
        }

        // Quick "Solo" button when 2+ sources are playing simultaneously -> pauses all others
        Rectangle {
            visible: ctrl.playingCount > 1
            Layout.preferredWidth: soloTxt.implicitWidth + 12
            Layout.preferredHeight: 28
            radius: 10
            color: soloMa.containsMouse ? Qt.rgba(1.0, 0.27, 0.23, 0.34) : Qt.rgba(1.0, 0.27, 0.23, 0.18)
            border.width: 1
            border.color: Qt.rgba(1.0, 0.27, 0.23, 0.45)

            Text {
                id: soloTxt
                anchors.centerIn: parent
                text: "Solo"
                font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                color: "#ff6961"
            }

            MouseArea {
                id: soloMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ctrl.pauseOtherPlayers(ctrl.playerIndex)
            }
        }
    }
    }
}
