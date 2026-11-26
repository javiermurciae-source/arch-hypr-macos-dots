import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../services"
import "../common"

PanelWindow {
    id: root

    screen: Quickshell.screens[0]
    anchors { top: true }
    margins { top: 0 }
    implicitWidth: 660
    implicitHeight: 235
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.namespace: "macos:island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: islandState.replyingNotif
        ? WlrKeyboardFocus.Exclusive
        : (islandState.addingTodo ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

    // Note: Wayland WlSessionLock natively covers all overlay layers while locked,
    // so we never tie Island visibility to ShellController.locked.
    readonly property bool hiddenByContext: ShellController.spotlightOpen
        || (ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false)

    // Keep the Wayland layer surface permanently mapped so Hyprland never drops it
    // after WlSessionLock unlock or fullscreen transitions; hide visual + input mask instead.
    visible: true

    // Exact click-through mask matching the animated notch bounds (0x0 when hidden)
    mask: Region { item: notchHitBox }

    IslandState {
        id: islandState
    }

    IpcHandler {
        target: "island"
        function testBluetooth(): void { islandState.demoBluetoothAnimation() }
    }

    // ── Active visual mode ────────────────────────────────────────
    readonly property string mode: {
        if (islandState.expanded) return "expanded";
        if (islandState.notifVisible && islandState.activeNotif) return "notif";
        if (islandState.hudType !== "") return "hud";
        if (islandState.gsrRecording) return "recCompact";
        if (islandState.pomoRunning) return "pomoCompact";
        if (islandState.anyPlaying) return "mediaCompact";
        return "idle";
    }

    readonly property real targetWidth: {
        if (mode === "expanded") {
            return (islandState.currentPage === 0 && islandState.lyricsOpen) ? 608 : 472;
        }
        if (mode === "notif") return 396;
        if (mode === "hud") {
            if (islandState.hudType === "record_saved") return 368;
            if (islandState.hudType === "bluetooth_connecting" || islandState.hudType === "bluetooth") return 346;
            return 320;
        }
        if (mode === "recCompact") return 224;
        if (mode === "pomoCompact") return 196;
        if (mode === "mediaCompact") return islandState.showMultiSources ? 280 : 254;
        return 146; // idle mascot (sleek Nusa proportions)
    }

    readonly property real targetHeight: {
        if (mode === "expanded") {
            if (islandState.currentPage === 0 && islandState.showMultiSources) return 204;
            return (islandState.currentPage === 3 && islandState.addingTodo) ? 182 : 168;
        }
        if (mode === "notif") {
            if (islandState.replyingNotif) return 124;
            return (islandState.activeNotifActions.length > 0 || islandState.activeNotifCanReply) ? 114 : 84;
        }
        if (mode === "hud") return 62;
        if (mode === "recCompact" || mode === "pomoCompact" || mode === "mediaCompact") return 31;
        return 27;
    }

    readonly property real targetRadius: {
        if (mode === "expanded") return 24;
        if (mode === "notif") return 22;
        if (mode === "hud") return 20;
        return 10;
    }

    readonly property real targetEar: {
        if (mode === "expanded") return 16;
        if (mode === "notif") return 14;
        if (mode === "hud") return 13;
        return 8;
    }

    readonly property color contextualGlow: {
        if (mode === "hud") return Qt.rgba(islandState.hudAccent.r, islandState.hudAccent.g, islandState.hudAccent.b, 0.28);
        if (mode === "expanded") {
            if (islandState.currentPage === 1) {
                return islandState.pomoMode === "focus"
                    ? Qt.rgba(1.0, 0.23, 0.36, 0.20)
                    : Qt.rgba(0.19, 0.82, 0.35, 0.20);
            }
            if (islandState.currentPage === 2) return Qt.rgba(0.18, 0.56, 1.0, 0.22);
            if (islandState.currentPage === 3) return Qt.rgba(0.19, 0.82, 0.35, 0.16);
            if (islandState.currentPage === 4) return Qt.rgba(0.28, 0.48, 0.95, 0.16);
        }
        if (mode === "recCompact") return Qt.rgba(1.0, 0.22, 0.22, 0.34);
        if (mode === "pomoCompact") return Qt.rgba(1.0, 0.23, 0.36, 0.28);
        return "#00000000";
    }

    readonly property real contextualGlowAlpha: {
        if (mode === "hud") {
            if (islandState.hudType === "bluetooth_connecting") return 0.62;
            if (islandState.hudType === "bluetooth") return 0.50;
            return 0.14;
        }
        if (mode === "recCompact") return 0.85;
        if (mode === "pomoCompact") return 0.75;
        if (mode === "expanded" && islandState.currentPage > 0) return 0.85;
        return 0.0;
    }

    function prevPage() {
        islandState.addingTodo = false;
        islandState.waterSettingsOpen = false;
        islandState.currentPage = (islandState.currentPage - 1 + islandState.pageCount) % islandState.pageCount;
    }

    function nextPage() {
        islandState.addingTodo = false;
        islandState.waterSettingsOpen = false;
        islandState.currentPage = (islandState.currentPage + 1) % islandState.pageCount;
    }

    // Smooth hover-intent expand & delayed collapse
    Timer {
        id: hoverExpandTimer
        interval: 150
        onTriggered: {
            if (notchHover.hovered && !islandState.expanded && !recStopMa.containsMouse && islandState.hudType !== "record_saved") {
                if (islandState.notifVisible) islandState.notifPaused = true;
                else islandState.expanded = true;
            }
        }
    }

    Timer {
        id: hoverCollapseTimer
        interval: 380
        onTriggered: {
            if (!notchHover.hovered && !islandState.addingTodo && !islandState.replyingNotif && !islandState.scrubbing && !islandState.waterSettingsOpen && !dragRevealArea.containsDrag) {
                islandState.expanded = false;
                islandState.notifPaused = false;
            }
        }
    }

    Timer {
        id: replyFocusTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (islandState.replyingNotif) {
                replyField.forceActiveFocus();
            }
        }
    }

    // Track hit region for Wayland input mask (0x0 click-through when hidden)
    Item {
        id: notchHitBox
        x: notchBox.x
        y: 0
        width: root.hiddenByContext ? 0 : notchBox.width
        height: root.hiddenByContext ? 0 : (notchBox.height + 4)
    }

    // ── Main Morphing Notch Container ─────────────────────────────
    Item {
        id: notchBox
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.targetWidth
        height: root.targetHeight
        visible: !root.hiddenByContext

        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.55 }
        }
        Behavior on height {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        // Hover tracking across entire notch
        HoverHandler {
            id: notchHover
            onHoveredChanged: {
                if (hovered) {
                    hoverCollapseTimer.stop();
                    if (islandState.notifVisible) {
                        islandState.notifPaused = true;
                    } else if (!islandState.expanded) {
                        hoverExpandTimer.restart();
                    }
                } else {
                    hoverExpandTimer.stop();
                    if (!islandState.replyingNotif) {
                        islandState.notifPaused = false;
                    }
                    if (islandState.expanded) {
                        hoverCollapseTimer.restart();
                    }
                }
            }
        }

        // Dragging a file near the collapsed notch auto-opens Shelf!
        DropArea {
            id: dragRevealArea
            anchors.fill: parent
            z: 20
            enabled: !islandState.expanded
            onEntered: {
                islandState.currentPage = 4;
                islandState.expanded = true;
            }
        }

        // Wheel navigation & volume + click toggle when collapsed (right-click cycles mascot animation!)
        MouseArea {
            anchors.fill: parent
            z: 1
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            propagateComposedEvents: true
            onClicked: (m) => {
                if (m.button === Qt.RightButton) {
                    if (root.mode === "idle") {
                        mascotFace.cycleMood();
                        return;
                    }
                    m.accepted = false;
                    return;
                }
                if (m.button === Qt.MiddleButton) {
                    if (islandState.activePlayer && islandState.activePlayer.canTogglePlaying)
                        islandState.activePlayer.togglePlaying();
                    return;
                }
                if (root.mode === "notif") {
                    if (islandState.replyingNotif) {
                        m.accepted = false;
                        return;
                    }
                    if (islandState.activeNotif) Notifications.activate(islandState.activeNotif);
                    islandState.dismissNotif(false);
                    return;
                }
                if (!islandState.expanded) {
                    if (root.mode === "hud" && islandState.hudType === "record_saved" && islandState.lastRecordingPath.length > 0) {
                        islandState.openLastRecording();
                        return;
                    }
                    islandState.clearHud();
                    islandState.expanded = true;
                } else {
                    m.accepted = false;
                }
            }
            onWheel: (w) => {
                if (islandState.expanded) {
                    if (w.angleDelta.y > 0) root.prevPage();
                    else if (w.angleDelta.y < 0) root.nextPage();
                } else {
                    const step = w.angleDelta.y > 0 ? 0.05 : -0.05;
                    Audio.setVolume(Audio.volume + step);
                }
            }
        }

        // Vector Concave-Ear Notch Shape + OLED & Glows
        NotchShape {
            id: notchSurface
            anchors.fill: parent
            earSize: root.targetEar
            bottomRadius: root.targetRadius
            idleAura: root.mode === "idle"
            idleAuraStrength: mascotFace.isSleeping ? 0.52 : (mascotFace.isJoyful ? 0.98 : 0.90)
            glowColor: root.contextualGlow
            glowOpacity: root.contextualGlowAlpha
            artUrl: islandState.trackArtUrl
            artColor1: islandState.artColor1
            artColor2: islandState.artColor2
            artColor3: islandState.artColor3
            artGlowOpacity: {
                if (root.mode === "mediaCompact") return 0.72;
                if (root.mode === "expanded" && islandState.currentPage === 0 && islandState.hasMedia) {
                    return islandState.lyricsOpen ? 0.94 : 0.82;
                }
                return 0.0;
            }

            Behavior on bottomRadius { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on earSize { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }

        // ==========================================================
        // 1. IDLE MASCOT ("Say hi to Nusa" - dynamic living animations)
        // ==========================================================
        Item {
            id: idleMascot
            anchors.fill: parent
            anchors.leftMargin: notchSurface.e + 6
            anchors.rightMargin: notchSurface.e + 6
            opacity: root.mode === "idle" ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Optional privacy dots (orange mic / purple screen share)
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Rectangle {
                    visible: islandState.micActive
                    width: 6; height: 6; radius: 3; color: "#ff9500"
                }
                Rectangle {
                    visible: islandState.recActive
                    width: 6; height: 6; radius: 3; color: "#bf5af2"
                }
            }

            MascotFace {
                id: mascotFace
                anchors.fill: parent
                active: root.mode === "idle" && !root.hiddenByContext
                hovered: notchHover.hovered
            }
        }

        // ==========================================================
        // 2. COMPACT MEDIA PILL (Mini art + title + 5-bar waveform)
        // ==========================================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: notchSurface.e + 10
            anchors.rightMargin: notchSurface.e + 10
            spacing: 8
            opacity: root.mode === "mediaCompact" ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                radius: 5
                color: "#1b1b24"
                clip: true

                Image {
                    anchors.fill: parent
                    source: islandState.trackArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: islandState.trackArtUrl !== "" && status === Image.Ready
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: "#5e9cff"
                    visible: islandState.trackArtUrl === ""
                }
            }

            Text {
                Layout.fillWidth: true
                text: islandState.trackTitle
                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                color: "#ffffff"
                elide: Text.ElideRight
            }

            // Multi-source badge ONLY when 2+ sources are playing simultaneously
            Rectangle {
                visible: islandState.showMultiSources
                Layout.preferredWidth: multiBadgeTxt.implicitWidth + 10
                Layout.preferredHeight: 16
                radius: 8
                color: Qt.rgba(0.19, 0.82, 0.35, 0.28)
                border.width: 1
                border.color: Qt.rgba(0.19, 0.82, 0.35, 0.65)

                Text {
                    id: multiBadgeTxt
                    anchors.centerIn: parent
                    text: islandState.playingCount + "▶"
                    font { family: Appearance.fontFamily; pixelSize: 9; weight: Font.Bold }
                    color: "#30d158"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: islandState.cyclePlayer()
                }
            }

            // 5-bar lively equalizer (stepped ~6.5 FPS instead of 144 FPS -> 20x lower CPU & Hyprland load!)
            Row {
                id: compactWaveRow
                spacing: 2
                Layout.alignment: Qt.AlignVCenter
                property int waveTick: 0
                Timer {
                    interval: 155
                    repeat: true
                    running: root.mode === "mediaCompact" && islandState.anyPlaying
                    onTriggered: compactWaveRow.waveTick = (compactWaveRow.waveTick + 1) % 8
                }
                Repeater {
                    model: [
                        [4, 8, 12, 7, 5, 10, 6, 9],
                        [11, 6, 9, 13, 8, 5, 11, 7],
                        [7, 13, 5, 9, 12, 7, 4, 10],
                        [12, 8, 11, 5, 9, 13, 8, 6],
                        [5, 9, 6, 11, 4, 8, 10, 6]
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 2
                        height: (root.mode === "mediaCompact" && islandState.anyPlaying)
                            ? modelData[compactWaveRow.waveTick]
                            : 4
                        radius: 1
                        color: islandState.artAccent
                        Behavior on color { ColorAnimation { duration: 450 } }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ==========================================================
        // 3. COMPACT POMODORO LIVE ACTIVITY (Breathing dot + timer)
        // ==========================================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: notchSurface.e + 12
            anchors.rightMargin: notchSurface.e + 12
            spacing: 8
            opacity: root.mode === "pomoCompact" ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle {
                id: breathDot
                width: 9; height: 9; radius: 4.5
                color: islandState.pomoMode === "focus" ? "#ff3b5c" : "#30d158"
                SequentialAnimation on opacity {
                    running: root.mode === "pomoCompact"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: islandState.pomoMode === "focus" ? "Focus" : "Break"
                font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Medium }
                color: Qt.rgba(1, 1, 1, 0.65)
                Layout.fillWidth: true
            }

            Text {
                text: islandState.pomoText
                font { family: Appearance.fontFamily; pixelSize: 12; weight: Font.Bold }
                color: islandState.pomoMode === "focus" ? "#ff5c77" : "#4ae072"
            }
        }

        // ==========================================================
        // 3b. COMPACT SCREEN RECORDING LIVE ACTIVITY (REC dot + timer + stop)
        // ==========================================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: notchSurface.e + 12
            anchors.rightMargin: notchSurface.e + 10
            spacing: 7
            z: 6
            opacity: root.mode === "recCompact" ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.mode === "recCompact"
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Pulsing red recording dot with soft halo
            Item {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 6
                    color: Qt.rgba(1.0, 0.23, 0.19, 0.30)
                    SequentialAnimation on scale {
                        running: root.mode === "recCompact"
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.35; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.9; duration: 750; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 7.5; height: 7.5; radius: 3.75
                    color: "#ff3b30"
                    SequentialAnimation on opacity {
                        running: root.mode === "recCompact"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                    }
                }
            }

            Text {
                text: "Recording"
                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                color: Qt.rgba(1, 1, 1, 0.86)
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: islandState.gsrElapsedText
                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Bold }
                color: "#ff5c54"
            }

            // Clickable stop button right inside the pill
            Rectangle {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                radius: 9
                color: recStopMa.containsMouse ? "#ff3b30" : Qt.rgba(1.0, 0.23, 0.19, 0.28)
                border.color: Qt.rgba(1.0, 0.36, 0.32, 0.65)
                border.width: 1

                Rectangle {
                    anchors.centerIn: parent
                    width: 6.5; height: 6.5; radius: 1.5
                    color: "#ffffff"
                }

                MouseArea {
                    id: recStopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: islandState.stopRecording()
                }
            }
        }

        // ==========================================================
        // 4. COMPACT HUD TOAST (Exact 1:1 Nusa "Charging 70%" design)
        // ==========================================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: notchSurface.e + 16
            anchors.rightMargin: notchSurface.e + 18
            spacing: 13
            z: 5
            opacity: root.mode === "hud" ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Thick glowing circular ring with crisp white center glyph + Bluetooth radar/pulse animations
            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter

                // Expanding radar wave while connecting Bluetooth
                Rectangle {
                    visible: islandState.hudType === "bluetooth_connecting"
                    anchors.centerIn: parent
                    width: 34; height: 34; radius: 17
                    color: "transparent"
                    border.width: 2
                    border.color: islandState.hudAccent
                    property real pulse: 0
                    scale: 0.92 + pulse * 0.42
                    opacity: (1.0 - pulse) * 0.72
                    NumberAnimation on pulse {
                        running: root.mode === "hud" && islandState.hudType === "bluetooth_connecting"
                        from: 0; to: 1; duration: 1150; loops: Animation.Infinite
                        easing.type: Easing.OutCubic
                    }
                }

                // Celebration glow burst on Bluetooth connected
                Rectangle {
                    id: btConnectBurst
                    visible: opacity > 0.01
                    anchors.centerIn: parent
                    width: 36; height: 36; radius: 18
                    color: "transparent"
                    border.width: 2.5
                    border.color: islandState.hudAccent
                    scale: 0.85
                    opacity: 0
                    ParallelAnimation {
                        id: btBurstAnim
                        NumberAnimation { target: btConnectBurst; property: "scale"; from: 0.85; to: 1.48; duration: 650; easing.type: Easing.OutCubic }
                        NumberAnimation { target: btConnectBurst; property: "opacity"; from: 0.85; to: 0.0; duration: 650; easing.type: Easing.OutCubic }
                    }
                    Connections {
                        target: islandState
                        function onHudTypeChanged() {
                            if (islandState.hudType === "bluetooth") {
                                hudRing.animProg = 0;
                                hudRing.animProg = islandState.hudProgress;
                                btBurstAnim.restart();
                            }
                        }
                    }
                }

                Canvas {
                    id: hudRing
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    property real prog: islandState.hudProgress
                    property real animProg: prog
                    property color acc: islandState.hudAccent
                    property string kind: islandState.hudType
                    property real spinAngle: 0

                    Behavior on animProg {
                        NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                    }

                    NumberAnimation on spinAngle {
                        running: root.mode === "hud" && islandState.hudType === "bluetooth_connecting"
                        from: 0; to: Math.PI * 2; duration: 1050; loops: Animation.Infinite
                    }

                    onProgChanged: { animProg = prog; requestPaint(); }
                    onAnimProgChanged: requestPaint()
                    onSpinAngleChanged: requestPaint()
                    onAccChanged: requestPaint()
                    onKindChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var cx = width / 2, cy = height / 2, r = 13.5;

                        // Subtle ring track
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.strokeStyle = Qt.rgba(acc.r, acc.g, acc.b, 0.22);
                        ctx.lineWidth = 3.6;
                        ctx.stroke();

                        // Luminous progress arc (or spinning radar arc when connecting!)
                        ctx.save();
                        ctx.shadowColor = Qt.rgba(acc.r, acc.g, acc.b, 0.65);
                        ctx.shadowBlur = 6;
                        ctx.beginPath();
                        if (kind === "bluetooth_connecting") {
                            ctx.arc(cx, cy, r, spinAngle, spinAngle + Math.PI * 0.85);
                        } else {
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.08, animProg));
                        }
                        ctx.strokeStyle = acc;
                        ctx.lineWidth = 3.6;
                        ctx.lineCap = "round";
                        ctx.stroke();
                        ctx.restore();

                        // Crisp pure white icon centered inside ring
                        ctx.fillStyle = "#ffffff";
                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 1.8;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";

                        if (kind === "battery" || kind === "battery_off") {
                            ctx.beginPath();
                            ctx.moveTo(cx + 1.2, cy - 6.8);
                            ctx.lineTo(cx - 4.4, cy + 0.8);
                            ctx.lineTo(cx - 0.2, cy + 0.8);
                            ctx.lineTo(cx - 1.2, cy + 6.8);
                            ctx.lineTo(cx + 4.4, cy - 0.8);
                            ctx.lineTo(cx + 0.2, cy - 0.8);
                            ctx.closePath();
                            ctx.fill();
                        } else if (kind === "brightness") {
                            ctx.beginPath(); ctx.arc(cx, cy, 3.6, 0, Math.PI * 2); ctx.fill();
                            for (var a = 0; a < 8; a++) {
                                var ang = a * Math.PI / 4;
                                ctx.beginPath();
                                ctx.moveTo(cx + Math.cos(ang) * 5.6, cy + Math.sin(ang) * 5.6);
                                ctx.lineTo(cx + Math.cos(ang) * 7.4, cy + Math.sin(ang) * 7.4);
                                ctx.stroke();
                            }
                        } else if (kind === "volume") {
                            ctx.beginPath();
                            ctx.moveTo(cx - 5, cy - 2.2);
                            ctx.lineTo(cx - 2, cy - 2.2);
                            ctx.lineTo(cx + 1.5, cy - 5.2);
                            ctx.lineTo(cx + 1.5, cy + 5.2);
                            ctx.lineTo(cx - 2, cy + 2.2);
                            ctx.lineTo(cx - 5, cy + 2.2);
                            ctx.closePath();
                            ctx.fill();
                            if (prog > 0.01) {
                                ctx.beginPath();
                                ctx.arc(cx + 2.2, cy, 3.5, -0.7, 0.7);
                                ctx.stroke();
                            }
                        } else if (kind === "bluetooth" || kind === "bluetooth_connecting" || kind === "bluetooth_off") {
                            // Crisp headphones arc + earcups
                            ctx.beginPath();
                            ctx.arc(cx, cy + 0.5, 5.5, Math.PI, 0);
                            ctx.stroke();
                            ctx.fillRect(cx - 6.5, cy, 2.6, 5);
                            ctx.fillRect(cx + 3.9, cy, 2.6, 5);
                            if (kind === "bluetooth_off") {
                                ctx.strokeStyle = "#ff453a";
                                ctx.lineWidth = 1.6;
                                ctx.beginPath();
                                ctx.moveTo(cx - 6, cy - 5);
                                ctx.lineTo(cx + 6, cy + 6);
                                ctx.stroke();
                            }
                        } else if (kind === "capslock") {
                            ctx.beginPath();
                            ctx.moveTo(cx, cy - 5.5);
                            ctx.lineTo(cx - 5, cy + 0.5);
                            ctx.lineTo(cx - 2, cy + 0.5);
                            ctx.lineTo(cx - 2, cy + 4);
                            ctx.lineTo(cx + 2, cy + 4);
                            ctx.lineTo(cx + 2, cy + 0.5);
                            ctx.lineTo(cx + 5, cy + 0.5);
                            ctx.closePath();
                            ctx.fill();
                            ctx.fillRect(cx - 3.5, cy + 5.4, 7, 1.4);
                        } else if (kind === "water") {
                            ctx.beginPath();
                            ctx.moveTo(cx, cy - 5.5);
                            ctx.quadraticCurveTo(cx + 4.4, cy + 0.8, cx + 4.4, cy + 3);
                            ctx.arc(cx, cy + 3, 4.4, 0, Math.PI);
                            ctx.quadraticCurveTo(cx - 4.4, cy + 0.8, cx, cy - 5.5);
                            ctx.fill();
                        } else if (kind === "record_saved") {
                            ctx.beginPath();
                            ctx.moveTo(cx - 3.2, cy - 4.8);
                            ctx.lineTo(cx + 5.2, cy);
                            ctx.lineTo(cx - 3.2, cy + 4.8);
                            ctx.closePath();
                            ctx.fill();
                        } else {
                            ctx.beginPath(); ctx.arc(cx, cy, 3.6, 0, Math.PI * 2); ctx.fill();
                        }
                    }
                }
            }

            // Title + Subtitle (plus sleek inline bar for volume/brightness)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: islandState.hudTitle
                    font { family: Appearance.fontFamily; pixelSize: 14; weight: Font.Bold }
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                Text {
                    visible: islandState.hudType !== "volume" && islandState.hudType !== "brightness"
                    Layout.fillWidth: true
                    text: islandState.hudSubtitle
                    font { family: Appearance.fontFamily; pixelSize: 11 }
                    color: Qt.rgba(1, 1, 1, 0.50)
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: islandState.hudType === "volume" || islandState.hudType === "brightness"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4.5
                    Layout.topMargin: 3
                    radius: 2.25
                    color: Qt.rgba(1, 1, 1, 0.16)
                    Rectangle {
                        width: Math.max(5, parent.width * islandState.hudProgress)
                        height: parent.height
                        radius: 2.25
                        color: islandState.hudAccent
                        Behavior on width { NumberAnimation { duration: 140 } }
                    }
                }
            }

            // Optional quick "+250ml" pill on water reminder toast
            Rectangle {
                visible: islandState.hudActionDrink
                Layout.preferredHeight: 24
                Layout.preferredWidth: 64
                radius: 12
                color: "#1c64d4"
                Text {
                    anchors.centerIn: parent; text: "+250 ml"
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                    color: "#ffffff"
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { islandState.addWater(islandState.waterCupMl); islandState.clearHud(); }
                }
            }

            // Direct "▶ mpv" pill right after stopping a screen recording
            Rectangle {
                visible: islandState.hudType === "record_saved" && islandState.lastRecordingPath.length > 0
                Layout.preferredHeight: 26
                Layout.preferredWidth: hudPlayLbl.implicitWidth + 20
                radius: 13
                color: hudPlayMa.containsMouse ? "#30d158" : Qt.rgba(0.19, 0.82, 0.35, 0.28)
                border.color: Qt.rgba(0.29, 0.90, 0.45, 0.72)
                border.width: 1
                Text {
                    id: hudPlayLbl
                    anchors.centerIn: parent
                    text: "▶ mpv"
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                    color: "#ffffff"
                }
                MouseArea {
                    id: hudPlayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: islandState.openLastRecording()
                }
            }

            // Animated 3 bouncing dots when Bluetooth is connecting/searching
            Row {
                visible: islandState.hudType === "bluetooth_connecting"
                spacing: 4
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 6; height: 6; radius: 3
                        color: "#38bdf8"
                        property real bounce: 0
                        opacity: 0.45 + bounce * 0.55
                        scale: 0.8 + bounce * 0.35
                        SequentialAnimation on bounce {
                            running: root.mode === "hud" && islandState.hudType === "bluetooth_connecting"
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 140 }
                            NumberAnimation { to: 1.0; duration: 320; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.0; duration: 320; easing.type: Easing.InOutSine }
                            PauseAnimation { duration: (2 - index) * 140 }
                        }
                    }
                }
            }

            Text {
                visible: !islandState.hudActionDrink
                    && islandState.hudType !== "bluetooth_connecting"
                    && !(islandState.hudType === "record_saved" && islandState.lastRecordingPath.length > 0)
                text: islandState.hudValueText
                font { family: Appearance.fontFamily; pixelSize: 20; weight: Font.Normal }
                color: islandState.hudType === "bluetooth" ? islandState.hudAccent : "#ffffff"
            }
        }

        // ==========================================================
        // 5. NOTIFICATION TOAST IN NOTCH
        // ==========================================================
        Item {
            id: notifToast
            anchors.fill: parent
            anchors.leftMargin: notchSurface.e + 14
            anchors.rightMargin: notchSurface.e + 14
            anchors.topMargin: 9
            anchors.bottomMargin: 9
            z: 6
            opacity: root.mode === "notif" ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.mode === "notif"
            clip: true
            Behavior on opacity { NumberAnimation { duration: 170 } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                // Top Row: App Icon + Title/Body + Close button
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 11

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        Layout.alignment: Qt.AlignVCenter
                        radius: 11
                        color: "#181822"
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: islandState.activeNotifIcon
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: islandState.activeNotifIcon.length > 0 && status === Image.Ready
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 12; height: 12; radius: 6
                            color: "#3b9eff"
                            visible: islandState.activeNotifIcon.length === 0
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: islandState.activeNotif ? (islandState.activeNotif.appName || "Notification") : ""
                            font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                            color: Qt.rgba(1, 1, 1, 0.52)
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: islandState.activeNotif ? (islandState.activeNotif.summary || "").replace(/\s*\n\s*/g, " ") : ""
                            font { family: Appearance.fontFamily; pixelSize: 12; weight: Font.Bold }
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: islandState.activeNotif && !!islandState.activeNotif.body
                            text: islandState.activeNotif ? (islandState.activeNotif.body || "").replace(/\s*\n\s*/g, " ") : ""
                            font { family: Appearance.fontFamily; pixelSize: 11 }
                            color: Qt.rgba(1, 1, 1, 0.72)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Close button
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignTop
                        radius: 11
                        color: nCloseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: Qt.rgba(1, 1, 1, 0.65) }
                        MouseArea {
                            id: nCloseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: islandState.dismissNotif(true)
                        }
                    }
                }

                // Dedicated Action Row: Native Inline Reply + Action Chips (never overlaps text!)
                RowLayout {
                    visible: !islandState.replyingNotif && (islandState.activeNotifActions.length > 0 || islandState.activeNotifCanReply)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    spacing: 6

                    // Reply trigger pill
                    Rectangle {
                        visible: islandState.activeNotifCanReply
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: repBtnLbl.implicitWidth + 20
                        radius: 12
                        color: repBtnMa.containsMouse ? "#2584ff" : Qt.rgba(0.18, 0.56, 1.0, 0.34)
                        border.color: Qt.rgba(0.38, 0.72, 1.0, 0.70)
                        border.width: 1
                        Text {
                            id: repBtnLbl
                            anchors.centerIn: parent
                            text: "↩ Responder"
                            font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                            color: "#ffffff"
                        }
                        MouseArea {
                            id: repBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                islandState.replyingNotif = true;
                                islandState.notifPaused = true;
                                replyField.text = "";
                                replyField.forceActiveFocus();
                                replyFocusTimer.restart();
                            }
                        }
                    }

                    Repeater {
                        model: islandState.activeNotifActions
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: Math.min(actLbl.implicitWidth + 18, 120)
                            radius: 12
                            color: actMa.containsMouse ? "#2584ff" : Qt.rgba(1, 1, 1, 0.14)
                            Text {
                                id: actLbl
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.text
                                font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: actMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Notifications.invokeAction(islandState.activeNotif, modelData);
                                    islandState.dismissNotif(false);
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Inline Reply Input Row (replaces Action Row cleanly in the exact same slot!)
                RowLayout {
                    visible: islandState.replyingNotif
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 15
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.color: "#3b9eff"
                        border.width: 1

                        TextInput {
                            id: replyField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#ffffff"
                            selectionColor: "#3b9eff"
                            font { family: Appearance.fontFamily; pixelSize: 11 }
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: islandState.activeNotifReplyPlaceholder
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font: replyField.font
                                visible: replyField.text.length === 0
                            }

                            Keys.onReturnPressed: {
                                const msg = replyField.text;
                                replyField.text = "";
                                islandState.sendNotifReply(msg);
                            }
                            Keys.onEnterPressed: {
                                const msg = replyField.text;
                                replyField.text = "";
                                islandState.sendNotifReply(msg);
                            }
                            Keys.onEscapePressed: {
                                replyField.text = "";
                                islandState.replyingNotif = false;
                            }
                        }
                    }

                    // Send button
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 15
                        color: replyField.text.trim().length > 0 ? "#2584ff" : Qt.rgba(1, 1, 1, 0.12)
                        Text {
                            anchors.centerIn: parent
                            text: "➤"
                            font.pixelSize: 12
                            color: "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const msg = replyField.text;
                                replyField.text = "";
                                islandState.sendNotifReply(msg);
                            }
                        }
                    }
                }

                // Auto-dismiss progress bar (pauses on hover or while typing reply)
                Rectangle {
                    visible: !islandState.replyingNotif
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Rectangle {
                        width: parent.width * islandState.notifProgress
                        height: parent.height
                        radius: 1
                        color: "#3b9eff"
                    }
                }
            }
        }

        // ==========================================================
        // 6. EXPANDED NUSA 5-PAGE LIVING NOTCH HUB
        // ==========================================================
        Item {
            anchors.fill: parent
            anchors.leftMargin: notchSurface.e + 12
            anchors.rightMargin: notchSurface.e + 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            z: 5
            opacity: root.mode === "expanded" ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.mode === "expanded"
            Behavior on opacity { NumberAnimation { duration: 190 } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 4

                // ── Top Shared Header (Page Title | Status Ring + Date/Time | Waveform) ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    // Left: Page Title (hidden on Music page for clean album-art alignment)
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: islandState.currentPage !== 0

                        Text {
                            text: {
                                if (islandState.currentPage === 1) return "Pomodoro";
                                if (islandState.currentPage === 2) return "Water";
                                if (islandState.currentPage === 3) return "TodoList";
                                return "Shelf";
                            }
                            font { family: Appearance.fontFamily; pixelSize: 12; weight: Font.Bold }
                            color: "#ffffff"
                        }
                        Text {
                            visible: islandState.currentPage === 2
                            text: "Reminder"
                            font { family: Appearance.fontFamily; pixelSize: 12; weight: Font.Bold }
                            color: "#3b9eff"
                        }
                    }

                    // Center: Clickable Status Ring (Battery / Water) + Date & Bold Time
                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Canvas {
                            id: statusRing
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            property real pct: islandState.statusRingMode === "water"
                                ? islandState.waterProgress
                                : Battery.percentage
                            property color col: islandState.statusRingMode === "water"
                                ? "#3b9eff"
                                : (Battery.percentage <= 0.2 ? "#ff453a" : "#30d158")
                            onPctChanged: requestPaint()
                            onColChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var cx = width / 2, cy = height / 2, r = 5;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.26);
                                ctx.lineWidth = 2.2;
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.05, pct));
                                ctx.strokeStyle = col;
                                ctx.lineWidth = 2.2;
                                ctx.lineCap = "round";
                                ctx.stroke();
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    islandState.statusRingMode = (islandState.statusRingMode === "battery") ? "water" : "battery";
                                    islandState.saveState();
                                }
                            }
                        }

                        Text {
                            text: Time.dateShort
                            font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Medium }
                            color: Qt.rgba(1, 1, 1, 0.72)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Time.timeShort
                            font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Bold }
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Right: Mini 5-bar waveform (click jumps to Music)
                    Item {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: waveRow.implicitWidth + 6
                        height: 18

                        Row {
                            id: waveRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: [5, 10, 7, 11, 6]
                                delegate: Rectangle {
                                    required property int modelData
                                    required property int index
                                    width: 1.8
                                    height: islandState.isPlaying ? 4 : Math.max(3, modelData * 0.45)
                                    radius: 1
                                    color: islandState.isPlaying ? "#ffffff" : Qt.rgba(1, 1, 1, 0.35)
                                    anchors.verticalCenter: parent.verticalCenter

                                    SequentialAnimation on height {
                                        running: root.mode === "expanded" && islandState.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { to: modelData; duration: 250 + index * 70; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 3; duration: 250 + index * 70; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: islandState.currentPage = 0
                        }
                    }
                }

                // ── Middle Content Row (< chevron | Active Page | > chevron) ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    // Left page chevron
                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter
                        radius: 9
                        color: prevPageMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            font { family: Appearance.fontFamily; pixelSize: 13; weight: Font.Bold }
                            color: Qt.rgba(1, 1, 1, 0.78)
                        }
                        MouseArea {
                            id: prevPageMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevPage()
                        }
                    }

                    // Active page container
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        MusicView {
                            anchors.fill: parent
                            ctrl: islandState
                            visible: islandState.currentPage === 0
                        }
                        PomodoroView {
                            anchors.fill: parent
                            ctrl: islandState
                            visible: islandState.currentPage === 1
                        }
                        WaterView {
                            anchors.fill: parent
                            ctrl: islandState
                            visible: islandState.currentPage === 2
                        }
                        TodoView {
                            anchors.fill: parent
                            ctrl: islandState
                            visible: islandState.currentPage === 3
                        }
                        ShelfView {
                            anchors.fill: parent
                            ctrl: islandState
                            visible: islandState.currentPage === 4
                        }
                    }

                    // Right page chevron
                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter
                        radius: 9
                        color: nextPageMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            font { family: Appearance.fontFamily; pixelSize: 13; weight: Font.Bold }
                            color: Qt.rgba(1, 1, 1, 0.78)
                        }
                        MouseArea {
                            id: nextPageMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextPage()
                        }
                    }
                }

                // ── Bottom Page Indicator Dots (— • • • •) ──
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 5

                    Repeater {
                        model: islandState.pageCount
                        delegate: Rectangle {
                            required property int index
                            readonly property bool active: islandState.currentPage === index
                            width: active ? 14 : 4.5
                            height: 4.5
                            radius: 2.25
                            color: active ? "#ffffff" : Qt.rgba(1, 1, 1, 0.28)
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 160 } }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    islandState.addingTodo = false;
                                    islandState.waterSettingsOpen = false;
                                    islandState.currentPage = index;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
