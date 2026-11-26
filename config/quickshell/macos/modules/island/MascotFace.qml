import QtQuick
import "../common"

Item {
    id: mascot

    property bool active: true
    property bool hovered: false
    // Moods: "awake" | "greet" | "yawn" | "sleep" | "wink" | "happy" | "curious" | "sparkle"
    property string mood: "awake"
    property bool blinking: false
    property real lookX: 0
    property real lookY: 0
    property int idleTicks: 0
    property int rotationStep: 0

    // Exposed for NotchShape aura tinting
    readonly property bool isSleeping: mood === "sleep"
    readonly property bool isJoyful: mood === "greet" || mood === "happy" || mood === "wink" || mood === "sparkle"

    function cycleMood() {
        const order = ["greet", "happy", "wink", "curious", "sparkle", "yawn", "sleep", "awake"];
        const idx = order.indexOf(mood);
        mood = order[(idx + 1) % order.length];
        idleTicks = 0;
        moodReturnTimer.restart();
        faceCanvas.requestPaint();
    }

    function wakeUp() {
        idleTicks = 0;
        if (mood === "sleep" || mood === "yawn") {
            mood = "greet";
            moodReturnTimer.interval = 2600;
            moodReturnTimer.restart();
            faceCanvas.requestPaint();
        }
    }

    onHoveredChanged: {
        if (hovered) wakeUp();
    }

    onActiveChanged: {
        if (active) {
            idleTicks = 0;
            if (mood === "sleep") {
                mood = "greet";
                moodReturnTimer.interval = 2400;
                moodReturnTimer.restart();
            }
            faceCanvas.requestPaint();
        }
    }

    onMoodChanged: faceCanvas.requestPaint()
    onBlinkingChanged: faceCanvas.requestPaint()

    // Start with signature glowing open eyes, then rotate smoothly through all animations
    Component.onCompleted: {
        mood = "awake";
        faceCanvas.requestPaint();
    }

    // ── Return from temporary expression to awake/sleep ───────────
    Timer {
        id: moodReturnTimer
        interval: 2800
        running: false
        onTriggered: {
            if (!mascot.active) return;
            if (mascot.mood === "yawn") {
                mascot.mood = "sleep";
                mascot.lookX = 0;
                mascot.lookY = 0;
            } else if (mascot.mood !== "sleep") {
                mascot.mood = "awake";
            }
        }
    }

    // ── Natural blink timer (when awake / curious) ────────────────
    Timer {
        id: blinkTimer
        interval: 3400
        running: mascot.active && (mascot.mood === "awake" || mascot.mood === "curious")
        repeat: true
        onTriggered: {
            mascot.blinking = true;
            blinkEndTimer.restart();
            // Occasional natural double-blink
            if (Math.random() < 0.28) doubleBlinkTimer.restart();
            interval = 2600 + Math.floor(Math.random() * 3400);
        }
    }

    Timer {
        id: blinkEndTimer
        interval: 115
        onTriggered: mascot.blinking = false
    }

    Timer {
        id: doubleBlinkTimer
        interval: 250
        onTriggered: {
            if (mascot.mood === "awake") {
                mascot.blinking = true;
                blinkEndTimer.restart();
            }
        }
    }

    // ── Autonomous life rotation: mostly open eyes, rotating cleanly through every animation ──
    Timer {
        id: lifeTimer
        interval: 4600
        running: mascot.active
        repeat: true
        onTriggered: {
            mascot.idleTicks += 1;

            // Sleeping stays peaceful for 4 ticks (~18s), then wakes up with a friendly wave & back to open eyes
            if (mascot.mood === "sleep") {
                if (mascot.idleTicks >= 4) {
                    mascot.idleTicks = 0;
                    mascot.mood = "greet";
                    moodReturnTimer.interval = 2400;
                    moodReturnTimer.restart();
                }
                return;
            }

            if (mascot.mood !== "awake") return;

            // On odd ticks, stay in open eyes with a subtle curious glance so open eyes remain the star
            if (mascot.idleTicks % 2 === 1) {
                const xs = [-4.5, -2.5, 0, 2.5, 4.5];
                const ys = [-1.0, 0, 0, 0.8];
                mascot.lookX = xs[Math.floor(Math.random() * xs.length)];
                mascot.lookY = ys[Math.floor(Math.random() * ys.length)];
                return;
            }

            // On even ticks, rotate cleanly through every expression in sequence and return to open eyes!
            const cycle = ["greet", "curious", "wink", "happy", "sparkle", "yawn"];
            const nextAnim = cycle[mascot.rotationStep % cycle.length];
            mascot.rotationStep += 1;
            mascot.lookX = (nextAnim === "curious") ? (Math.random() < 0.5 ? -4 : 4) : 0;
            mascot.lookY = 0;
            mascot.mood = nextAnim;
            if (nextAnim === "yawn") {
                mascot.idleTicks = 0;
                moodReturnTimer.interval = 1700; // yawn transitions automatically into sleep (- - zZ)
            } else {
                moodReturnTimer.interval = (nextAnim === "greet") ? 2500 : 2200;
            }
            moodReturnTimer.restart();
        }
    }

    // ── Animated face container (gentle bounce / tilt / breathing) ──
    Item {
        id: faceGroup
        anchors.centerIn: parent
        width: 84
        height: 24

        property real bobY: 0
        property real tiltDeg: 0

        transform: [
            Translate {
                x: mascot.lookX
                y: mascot.lookY + faceGroup.bobY
                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            },
            Rotation {
                origin.x: faceGroup.width / 2
                origin.y: faceGroup.height / 2
                angle: mascot.mood === "wink" ? -5 : (mascot.mood === "curious" ? (mascot.lookX > 0 ? 4 : -4) : 0)
                Behavior on angle { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            }
        ]

        // ── Vector Expressive Eyes + Yawn Mouth (painted only on state change -> 0% idle CPU!) ──
        Canvas {
            id: faceCanvas
            anchors.centerIn: parent
            width: 54
            height: 22

            property real animPhase: 0.65

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "#ffffff";
                ctx.strokeStyle = "#ffffff";
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                var lx = 20; // left eye center X
                var rx = 34; // right eye center X
                var cy = 12.2; // slightly lower, glowing right over the aurora fade

                function drawOvalEye(cx, ey, ew, eh) {
                    // Exact luminous glowing white oval eye from Nusa close-up
                    ctx.save();
                    ctx.shadowColor = "rgba(215, 232, 255, 0.85)";
                    ctx.shadowBlur = 7;
                    ctx.beginPath();
                    ctx.roundedRect(cx - ew / 2, ey - eh / 2, ew, eh, ew / 2, ew / 2);
                    ctx.fill();
                    ctx.restore();
                }

                function drawHappyArc(cx, ey) {
                    ctx.lineWidth = 2.4;
                    ctx.beginPath();
                    ctx.moveTo(cx - 4.2, ey + 1.5);
                    ctx.quadraticCurveTo(cx, ey - 4.2, cx + 4.2, ey + 1.5);
                    ctx.stroke();
                }

                function drawSleepLine(cx, ey) {
                    ctx.lineWidth = 2.1;
                    ctx.beginPath();
                    ctx.moveTo(cx - 4.2, ey + 0.5);
                    ctx.quadraticCurveTo(cx, ey + 3.0, cx + 4.2, ey + 0.5);
                    ctx.stroke();
                }

                function drawFlatDash(cx, ey) {
                    ctx.lineWidth = 2.1;
                    ctx.beginPath();
                    ctx.moveTo(cx - 4.0, ey);
                    ctx.lineTo(cx + 4.0, ey);
                    ctx.stroke();
                }

                function drawStar(cx, ey, r) {
                    ctx.beginPath();
                    for (var i = 0; i < 8; i++) {
                        var rad = (i % 2 === 0) ? r : r * 0.36;
                        var a = (Math.PI / 4) * i - Math.PI / 2;
                        var px = cx + Math.cos(a) * rad;
                        var py = ey + Math.sin(a) * rad;
                        if (i === 0) ctx.moveTo(px, py);
                        else ctx.lineTo(px, py);
                    }
                    ctx.closePath();
                    ctx.fill();
                }

                if (mascot.mood === "sleep") {
                    // Peaceful closed eyes (- -)
                    drawSleepLine(lx, cy);
                    drawSleepLine(rx, cy);
                } else if (mascot.mood === "yawn") {
                    // Squinting - - eyes + cute animated yawning mouth
                    drawFlatDash(lx, cy - 2);
                    drawFlatDash(rx, cy - 2);
                    var mr = 1.6 + animPhase * 2.2;
                    ctx.beginPath();
                    ctx.ellipse(27 - mr * 0.8, cy + 3.2 - mr, mr * 1.6, mr * 2.0);
                    ctx.fill();
                } else if (mascot.mood === "greet" || mascot.mood === "happy") {
                    // Joyful ^ ^ eyes
                    drawHappyArc(lx, cy);
                    drawHappyArc(rx, cy);
                } else if (mascot.mood === "wink") {
                    // Left eye bright oval, right eye playful wink arc
                    drawOvalEye(lx, cy, 5.6, 9.2);
                    drawHappyArc(rx, cy + 0.3);
                } else if (mascot.mood === "curious") {
                    // Asymmetric curious eyes (o O)
                    if (mascot.blinking) {
                        drawFlatDash(lx, cy);
                        drawFlatDash(rx, cy);
                    } else {
                        drawOvalEye(lx, cy + 0.5, 5.2, 6.2);
                        drawOvalEye(rx, cy - 0.3, 6.2, 10.6);
                    }
                } else if (mascot.mood === "sparkle") {
                    // Twinkling 4-point star eyes
                    var sr = 4.2 + animPhase * 1.3;
                    drawStar(lx, cy, sr);
                    drawStar(rx, cy, sr);
                } else {
                    // Normal awake glowing oval eyes (exact Nusa close-up proportions)
                    if (mascot.blinking) {
                        drawFlatDash(lx, cy);
                        drawFlatDash(rx, cy);
                    } else {
                        drawOvalEye(lx, cy, 5.2, 9.0);
                        drawOvalEye(rx, cy, 5.2, 9.0);
                    }
                }
            }
        }

        // ── Waving Hand (single gentle wave on "greet", no infinite 144Hz loop) ──
        Item {
            id: waveHand
            visible: mascot.mood === "greet"
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 2
            width: 16
            height: 16

            property real waveAngle: 0
            SequentialAnimation on waveAngle {
                running: mascot.active && mascot.mood === "greet"
                loops: 2
                NumberAnimation { to: 20; duration: 170; easing.type: Easing.InOutSine }
                NumberAnimation { to: -16; duration: 170; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 160; easing.type: Easing.OutSine }
            }

            transform: Rotation {
                origin.x: 8
                origin.y: 13
                angle: waveHand.waveAngle
            }

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "#ffffff";
                    // Minimalist cute rounded waving paw/hand silhouette
                    ctx.beginPath();
                    ctx.roundedRect(4.5, 6.5, 7, 6.5, 3, 3);
                    ctx.fill();
                    // Fingers
                    ctx.beginPath(); ctx.roundedRect(4.2, 2.2, 1.9, 5.5, 1, 1); ctx.fill();
                    ctx.beginPath(); ctx.roundedRect(6.5, 1.4, 1.9, 6.0, 1, 1); ctx.fill();
                    ctx.beginPath(); ctx.roundedRect(8.8, 2.2, 1.9, 5.5, 1, 1); ctx.fill();
                    // Thumb
                    ctx.beginPath(); ctx.roundedRect(10.6, 6.0, 2.2, 3.8, 1.1, 1.1); ctx.fill();
                }
            }
        }

        // ── Static Subtle "z Z" Sleep Indicator (zero 144Hz CPU during sleep) ──
        Item {
            visible: mascot.mood === "sleep"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 24

            Text {
                text: "z"
                font { family: Appearance.fontFamily; pixelSize: 8; weight: Font.Bold }
                color: "#9ecbff"
                opacity: 0.72
                x: 4; y: 10
            }
            Text {
                text: "Z"
                font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                color: "#9ecbff"
                opacity: 0.92
                x: 11; y: 2
            }
        }

        // ── Tiny Twinkle Dot on Wink (static crisp sparkle, zero infinite loop) ──
        Text {
            visible: mascot.mood === "wink"
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.top: parent.top
            anchors.topMargin: 2
            text: "✦"
            font.pixelSize: 9
            color: "#7cc7ff"
        }
    }
}
