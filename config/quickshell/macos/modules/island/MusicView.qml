import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../common"

Item {
    id: root
    required property var ctrl
    clip: true

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // ── Left column: Album Art + Info + Scrubber + Transport ──
        Item {
            id: leftPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: ctrl.lyricsOpen ? 245 : 390

            ColumnLayout {
                anchors.fill: parent
                spacing: 7

                // Top section: Album art + Title / Artist + Lyrics & Source dropdown pills
                RowLayout {
                    id: topMediaRow
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
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: ctrl.hasMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: (m) => {
                            if (m.button === Qt.RightButton) {
                                ctrl.cyclePlayer();
                            } else if (ctrl.hasMedia) {
                                ctrl.focusActivePlayer();
                            }
                        }
                    }
                }

                // Track title + artist + lyrics & source dropdown pills
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: trackTextCol.implicitHeight

                        ColumnLayout {
                            id: trackTextCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: ctrl.trackTitle
                                font { family: Appearance.fontFamily; pixelSize: 14; weight: Font.Bold }
                                color: trackInfoMa.containsMouse ? ctrl.artAccent : "#ffffff"
                                Behavior on color { ColorAnimation { duration: 130 } }
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: ctrl.trackArtist
                                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Medium }
                                color: trackInfoMa.containsMouse ? Qt.rgba(1, 1, 1, 0.80) : Qt.rgba(1, 1, 1, 0.56)
                                Behavior on color { ColorAnimation { duration: 130 } }
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: trackInfoMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: ctrl.hasMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (ctrl.hasMedia) ctrl.focusActivePlayer()
                        }
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

                        // Interactive Source Dropdown Pill (replaces plain source text, preserves clean layout)
                        Rectangle {
                            id: sourcePill
                            visible: ctrl.hasMedia && ctrl.activePlayer !== null
                            readonly property bool multi: ctrl.players.length > 1
                            readonly property bool multiPlaying: ctrl.playingCount > 1
                            readonly property string labelText: ctrl.playerLabel(ctrl.activePlayer)

                            Layout.maximumWidth: ctrl.lyricsOpen ? 112 : 180
                            implicitWidth: Math.min(Layout.maximumWidth, srcPillRow.implicitWidth + 12)
                            height: 18
                            radius: 9
                            color: ctrl.sourcesMenuOpen
                                ? Qt.rgba(ctrl.artAccent.r, ctrl.artAccent.g, ctrl.artAccent.b, 0.26)
                                : (srcPillMa.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.14)
                                    : (multi ? Qt.rgba(1, 1, 1, 0.08) : "transparent"))
                            border.width: (ctrl.sourcesMenuOpen || multiPlaying) ? 1 : 0
                            border.color: ctrl.sourcesMenuOpen
                                ? Qt.rgba(ctrl.artAccent.r, ctrl.artAccent.g, ctrl.artAccent.b, 0.72)
                                : Qt.rgba(0.19, 0.82, 0.35, 0.55)
                            Behavior on color { ColorAnimation { duration: 130 } }

                            Row {
                                id: srcPillRow
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    visible: sourcePill.multiPlaying
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: "#30d158"
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: sourcePill.multi
                                        ? (sourcePill.labelText + " · " + ctrl.players.length)
                                        : sourcePill.labelText
                                    font { family: Appearance.fontFamily; pixelSize: 9; weight: sourcePill.multi || ctrl.sourcesMenuOpen ? Font.DemiBold : Font.Medium }
                                    color: (ctrl.sourcesMenuOpen || srcPillMa.containsMouse)
                                        ? "#ffffff"
                                        : (sourcePill.multi ? Qt.rgba(1, 1, 1, 0.76) : Qt.rgba(1, 1, 1, 0.44))
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ctrl.sourcesMenuOpen ? "▴" : "▾"
                                    font { family: Appearance.fontFamily; pixelSize: 8; weight: Font.Bold }
                                    color: (ctrl.sourcesMenuOpen || srcPillMa.containsMouse)
                                        ? "#ffffff"
                                        : (sourcePill.multi ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(1, 1, 1, 0.34))
                                }
                            }

                            MouseArea {
                                id: srcPillMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctrl.sourcesMenuOpen = !ctrl.sourcesMenuOpen
                            }
                        }

                        Item { Layout.fillWidth: true }
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

            // Click-outside catcher to dismiss sources dropdown
            MouseArea {
                visible: ctrl.sourcesMenuOpen
                anchors.fill: parent
                z: 40
                onClicked: ctrl.sourcesMenuOpen = false
            }

            // Sleek Dropdown Source Selector anchored right below the top media row
            Rectangle {
                id: sourcesDropdown
                visible: ctrl.sourcesMenuOpen
                z: 50
                anchors.left: parent.left
                anchors.right: parent.right
                y: topMediaRow.y + topMediaRow.height + 5
                height: Math.min(parent.height - y - 2, dropdownCol.implicitHeight + 10)
                radius: 12
                color: Qt.rgba(0.08, 0.08, 0.12, 0.96)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
                clip: true

                opacity: ctrl.sourcesMenuOpen ? 1.0 : 0.0
                scale: ctrl.sourcesMenuOpen ? 1.0 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: dropdownCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 5
                    spacing: 4

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(104, sourcesListCol.implicitHeight)
                        contentWidth: width
                        contentHeight: sourcesListCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: sourcesListCol
                            width: parent.width
                            spacing: 3

                            Repeater {
                                model: ctrl.players
                                delegate: Rectangle {
                                    id: dropItem
                                    required property var modelData
                                    required property int index
                                    readonly property bool isSelected: index === ctrl.playerIndex
                                    readonly property bool isSrcPlaying: modelData && modelData.playbackState === MprisPlaybackState.Playing
                                    readonly property string srcTitle: (modelData && modelData.trackTitle)
                                        ? String(modelData.trackTitle).replace(/[\r\n]+/g, " ").replace(/\s{2,}/g, " ").trim()
                                        : ctrl.playerLabel(modelData)
                                    readonly property string srcLabel: ctrl.playerLabel(modelData)
                                    readonly property string srcArt: (modelData && modelData.trackArtUrl) ? String(modelData.trackArtUrl) : ""

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: 8
                                    color: isSelected
                                        ? Qt.rgba(ctrl.artAccent.r, ctrl.artAccent.g, ctrl.artAccent.b, 0.22)
                                        : (dropRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.04))
                                    border.width: isSelected ? 1 : 0
                                    border.color: Qt.rgba(ctrl.artAccent.r, ctrl.artAccent.g, ctrl.artAccent.b, 0.55)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    MouseArea {
                                        id: dropRowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ctrl.selectPlayer(dropItem.index);
                                            ctrl.sourcesMenuOpen = false;
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 7

                                        // Mini cover art + live green dot
                                        Item {
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 5
                                                color: "#1b1b24"
                                                clip: true
                                                Image {
                                                    anchors.fill: parent
                                                    source: dropItem.srcArt
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    smooth: true
                                                    visible: dropItem.srcArt !== "" && status === Image.Ready
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: dropItem.srcArt === ""
                                                    text: "♪"
                                                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                                                    color: "#5e9cff"
                                                }
                                            }

                                            Rectangle {
                                                visible: dropItem.isSrcPlaying
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

                                        // Track title + source & status subtitle
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                Layout.fillWidth: true
                                                text: dropItem.srcTitle
                                                font { family: Appearance.fontFamily; pixelSize: 10; weight: dropItem.isSelected ? Font.Bold : Font.Medium }
                                                color: dropItem.isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.84)
                                                maximumLineCount: 1
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: dropItem.srcLabel + (dropItem.isSrcPlaying ? " · Sonando" : " · En pausa")
                                                font { family: Appearance.fontFamily; pixelSize: 9; weight: Font.Medium }
                                                color: dropItem.isSrcPlaying ? "#30d158" : Qt.rgba(1, 1, 1, 0.44)
                                                maximumLineCount: 1
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Inline Play/Pause button for this specific source
                                        Rectangle {
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            radius: 10
                                            color: dropPlayMa.containsMouse
                                                ? Qt.rgba(1, 1, 1, 0.24)
                                                : (dropItem.isSrcPlaying ? Qt.rgba(0.19, 0.82, 0.35, 0.22) : Qt.rgba(1, 1, 1, 0.10))
                                            scale: dropPlayMa.pressed ? 0.88 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80 } }

                                            Canvas {
                                                anchors.centerIn: parent
                                                width: 10
                                                height: 10
                                                property bool playing: dropItem.isSrcPlaying
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
                                                id: dropPlayMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ctrl.togglePlayerAt(dropItem.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Footer "Solo esta" button when 2+ sources play simultaneously
                    Rectangle {
                        visible: ctrl.playingCount > 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 7
                        color: soloDropMa.containsMouse ? Qt.rgba(1.0, 0.27, 0.23, 0.28) : Qt.rgba(1.0, 0.27, 0.23, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 0.27, 0.23, 0.38)

                        Text {
                            anchors.centerIn: parent
                            text: "Pausar las demás fuentes"
                            font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                            color: "#ff6961"
                        }

                        MouseArea {
                            id: soloDropMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ctrl.pauseOtherPlayers(ctrl.playerIndex);
                                ctrl.sourcesMenuOpen = false;
                            }
                        }
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
}
