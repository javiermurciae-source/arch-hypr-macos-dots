import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../services"
import "../common"

Item {
    id: root

    Layout.preferredWidth: collapsedPill.width
    Layout.preferredHeight: parent ? parent.height : 28
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    width: collapsedPill.width
    height: parent ? parent.height : 28

    // ── state ─────────────────────────────────────────────────────
    property bool expanded: false
    property bool showNotification: false
    property var barWindow: null

    // ── media ─────────────────────────────────────────────────────
    property var activePlayer: null
    property double position: 0

    function pickPlayer() {
        const players = Mpris.players.values.filter(p =>
            p && p.identity !== "playerctld" && p.desktopEntry !== "playerctld");
        const playing = players.find(p => p.playbackState === MprisPlaybackState.Playing && p.trackTitle);
        const chosen = playing || players.find(p => !!p.trackTitle) || null;
        if (activePlayer !== chosen) activePlayer = chosen;
        if (activePlayer) root.position = activePlayer.position;
    }

    function fmtTime(t) {
        const s = Math.max(0, Math.floor(t || 0));
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2);
    }

    readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "No Media Playing") : "macOS Tahoe"
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtists ? activePlayer.trackArtists.join(", ") : "") : "Quickshell"
    readonly property string trackArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property double trackLength: activePlayer ? (activePlayer.length || 0) : 0

    Component.onCompleted: pickPlayer()

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.pickPlayer() }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.pickPlayer();
            if (root.activePlayer) root.position = root.activePlayer.position;
            if (root.isPlaying && !root.showNotification) root.expanded = true;
        }
    }

    onIsPlayingChanged: {
        if (!showNotification) {
            if (isPlaying) {
                root.expanded = true;
                autoCollapseTimer.restart();
            } else {
                root.expanded = false;
            }
        }
    }

    onShowNotificationChanged: {
        if (!showNotification && isPlaying) {
            root.expanded = true;
            autoCollapseTimer.restart();
        }
    }

    // ── notification ──────────────────────────────────────────────
    readonly property var notif: Notifications.latest
    readonly property string notifIcon: notif ? Notifications.iconFor(notif) : ""
    readonly property var notifActions: notif ? Notifications.buttons(notif) : []

    // expand on song change
    onTrackTitleChanged: {
        if (isPlaying && !showNotification) {
            root.expanded = true
            autoCollapseTimer.restart()
        }
    }

    // expand on new notification
    Connections {
        target: Notifications
        function onNotify() {
            root.showNotification = true
            root.expanded = true
            notifTimer.restart()
        }
    }

    Timer {
        id: autoCollapseTimer
        interval: 3500
        onTriggered: {
            if (!root.isPlaying && !pillMouseArea.containsMouse)
                root.expanded = false
        }
    }

    Timer {
        id: notifTimer
        interval: 5000
        onTriggered: {
            if (!pillMouseArea.containsMouse) {
                root.showNotification = false
                root.expanded = false
                Notifications.dismissToast()
            }
        }
    }

    // ─── Collapsed Pill ──────────────────────────────────────────
    Rectangle {
        id: collapsedPill
        anchors.centerIn: parent

        width: {
            if (root.showNotification && root.notif)
                return Math.min(Math.max(notifTitleMetrics.width + 70, 160), 260)
            if (root.isPlaying)
                return Math.min(Math.max(titleMetrics.width + 65, 150), 220)
            return 120
        }
        height: 24
        radius: 12

        color: "#0a0a0c"
        border.color: root.expanded ? "#315bdc" : Qt.rgba(1, 1, 1, 0.18)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        TextMetrics {
            id: titleMetrics
            text: root.trackTitle
            font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
        }

        TextMetrics {
            id: notifTitleMetrics
            text: root.notif ? root.notif.summary : ""
            font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
        }

        MouseArea {
            id: pillMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.expanded = true
            onExited: {
                if (!autoCollapseTimer.running && !notifTimer.running)
                    root.expanded = false
            }
            onClicked: root.expanded = !root.expanded
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            // icon
            Rectangle {
                width: 14; height: 14; radius: 7
                color: root.showNotification ? "#e74c3c" : (root.isPlaying ? "#315bdc" : "#44444c")
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.showNotification ? root.notifIcon : ""
                    fillMode: Image.PreserveAspectFit
                    visible: root.showNotification && status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.showNotification
                    text: root.isPlaying ? "🎵" : ""
                    font.pixelSize: 9
                }
            }

            // label
            Text {
                Layout.fillWidth: true
                text: root.showNotification && root.notif
                    ? root.notif.summary.replace(/\s*\n\s*/g, " ")
                    : root.trackTitle
                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                color: "#ffffff"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // equalizer (media only)
            Row {
                spacing: 2
                visible: root.isPlaying && !root.showNotification
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: 2
                        height: index === 1 ? 10 : (index === 0 ? 6 : 8)
                        radius: 1
                        color: "#315bdc"

                        SequentialAnimation on height {
                            running: root.isPlaying
                            loops: Animation.Infinite
                            NumberAnimation { to: 12; duration: 300 + index * 100 }
                            NumberAnimation { to: 4; duration: 300 + index * 100 }
                        }
                    }
                }
            }

            // close btn (notification)
            Rectangle {
                width: 14; height: 14; radius: 7
                color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                visible: root.showNotification
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 8
                    color: "#a0a0a8"
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.notif) Notifications.dismiss(root.notif)
                        root.showNotification = false
                        root.expanded = false
                    }
                }
            }
        }
    }

    // ─── Expanded Popup ──────────────────────────────────────────

}
