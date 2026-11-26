import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    property real earSize: 14
    property real bottomRadius: 24
    property color fillColor: "#000000"
    property color borderColor: Qt.rgba(1, 1, 1, 0.07)
    property color glowColor: "#00000000"
    property real glowOpacity: 0.0
    property string artUrl: ""
    property real artGlowOpacity: 0.0
    property color artColor1: "#0e86a8"
    property color artColor2: "#205ce8"
    property color artColor3: "#6c30d0"
    property bool idleAura: false
    property real idleAuraStrength: 0.92

    Behavior on artColor1 { ColorAnimation { duration: 550; easing.type: Easing.OutCubic } }
    Behavior on artColor2 { ColorAnimation { duration: 550; easing.type: Easing.OutCubic } }
    Behavior on artColor3 { ColorAnimation { duration: 550; easing.type: Easing.OutCubic } }

    readonly property real e: Math.max(4, Math.min(earSize, height * 0.32, width * 0.12))
    readonly property real r: Math.max(4, Math.min(bottomRadius, height * 0.44, (width - 2 * e) * 0.42))

    // ── Soft drop shadow behind notch ─────────────────────────────
    Shape {
        id: shadowSilhouette
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.58)
            shadowBlur: 0.55
            shadowVerticalOffset: 5
            shadowHorizontalOffset: 0
        }

        ShapePath {
            fillColor: root.fillColor
            strokeWidth: 0
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathCubic {
                x: root.width - root.e; y: root.e
                control1X: root.width - root.e * 0.45; control1Y: 0
                control2X: root.width - root.e; control2Y: root.e * 0.45
            }
            PathLine { x: root.width - root.e; y: root.height - root.r }
            PathCubic {
                x: root.width - root.e - root.r; y: root.height
                control1X: root.width - root.e; control1Y: root.height - root.r * 0.45
                control2X: root.width - root.e - root.r * 0.45; control2Y: root.height
            }
            PathLine { x: root.e + root.r; y: root.height }
            PathCubic {
                x: root.e; y: root.height - root.r
                control1X: root.e + root.r * 0.45; control1Y: root.height
                control2X: root.e; control2Y: root.height - root.r * 0.45
            }
            PathLine { x: root.e; y: root.e }
            PathCubic {
                x: 0; y: 0
                control1X: root.e; control1Y: root.e * 0.45
                control2X: root.e * 0.45; control2Y: 0
            }
        }
    }

    // ── Vector mask for interior glows/album art wash ─────────────
    Item {
        id: notchMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ffffff"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathCubic {
                    x: root.width - root.e; y: root.e
                    control1X: root.width - root.e * 0.45; control1Y: 0
                    control2X: root.width - root.e; control2Y: root.e * 0.45
                }
                PathLine { x: root.width - root.e; y: root.height - root.r }
                PathCubic {
                    x: root.width - root.e - root.r; y: root.height
                    control1X: root.width - root.e; control1Y: root.height - root.r * 0.45
                    control2X: root.width - root.e - root.r * 0.45; control2Y: root.height
                }
                PathLine { x: root.e + root.r; y: root.height }
                PathCubic {
                    x: root.e; y: root.height - root.r
                    control1X: root.e + root.r * 0.45; control1Y: root.height
                    control2X: root.e; control2Y: root.height - root.r * 0.45
                }
                PathLine { x: root.e; y: root.e }
                PathCubic {
                    x: 0; y: 0
                    control1X: root.e; control1Y: root.e * 0.45
                    control2X: root.e * 0.45; control2Y: 0
                }
            }
        }
    }

    // Smooth vertical alpha mask matching Nusa's exact curved pitch-black -> jewel aurora fade
    Item {
        id: auraFadeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 0.24; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 0.46; color: Qt.rgba(1, 1, 1, 0.26) }
                GradientStop { position: 0.74; color: Qt.rgba(1, 1, 1, 0.68) }
                GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.96) }
            }
        }
    }

    // ── Masked interior: seamless OLED black + smooth bottom glows ─
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: notchMask
        }

        // Seamless pure OLED black base
        Rectangle {
            anchors.fill: parent
            color: root.fillColor
        }

        // Dynamic curved radial album-art color gradient (painted only when colors or size change -> 0% idle CPU!)
        Canvas {
            id: artAuroraCanvas
            anchors.fill: parent
            opacity: root.artGlowOpacity
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

            property color c1: root.artColor1
            property color c2: root.artColor2
            property color c3: root.artColor3
            property real drift: 0.5

            onC1Changed: requestPaint()
            onC2Changed: requestPaint()
            onC3Changed: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (width <= 0 || height <= 0) return;

                var d = (drift - 0.5) * width * 0.07;

                function rgbaStr(col, a) {
                    return "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + "," + Math.round(col.b * 255) + "," + a + ")";
                }

                function drawOrb(cx, cy, rx, ry, col, coreA, midA) {
                    ctx.save();
                    ctx.translate(cx, cy);
                    ctx.scale(1.0, ry / Math.max(1, rx));
                    var g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx);
                    g.addColorStop(0.00, rgbaStr(col, coreA));
                    g.addColorStop(0.46, rgbaStr(col, midA));
                    g.addColorStop(0.80, rgbaStr(col, midA * 0.24));
                    g.addColorStop(1.00, "rgba(0,0,0,0)");
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(0, 0, rx, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();
                }

                ctx.globalCompositeOperation = "lighter";

                // 1. Primary album-cover glow curving up from bottom-left behind artwork
                drawOrb(width * 0.18 + d * 0.6, height * 1.04, width * 0.44, height * 1.05, c1, 0.62, 0.30);

                // 2. Secondary album-cover dome curving gently across bottom-center
                drawOrb(width * 0.54 - d * 0.5, height * 1.08, width * 0.44, height * 1.00, c2, 0.54, 0.25);

                // 3. Tertiary deep tone curving up on bottom-right (illuminates lyrics / waveform)
                drawOrb(width * 0.88 + d * 0.4, height * 1.06, width * 0.40, height * 0.96, c3, 0.52, 0.24);
            }
        }

        // Organic radial aurora orbs (painted once on resize -> 0% idle CPU!)
        Canvas {
            id: auroraCanvas
            anchors.fill: parent
            opacity: root.idleAura ? root.idleAuraStrength : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

            property real drift: 0.5
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (width <= 0 || height <= 0) return;

                var d = (drift - 0.5) * width * 0.08;

                // Helper: elliptical radial orb via vertical scale so glow curves organically like an aurora
                function drawOrb(cx, cy, rx, ry, c0, c1, c2) {
                    ctx.save();
                    ctx.translate(cx, cy);
                    ctx.scale(1.0, ry / Math.max(1, rx));
                    var g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx);
                    g.addColorStop(0.00, c0);
                    g.addColorStop(0.48, c1);
                    g.addColorStop(0.78, c2);
                    g.addColorStop(1.00, "rgba(0,0,0,0)");
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(0, 0, rx, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();
                }

                // Use lighter additive blending so the 3 curved orbs melt seamlessly into each other
                ctx.globalCompositeOperation = "lighter";

                // 1. Left oceanic teal-cyan soft radial orb (curved, low opacity, zero linear cut)
                drawOrb(
                    width * 0.14 + d * 0.6,
                    height * 1.05,
                    width * 0.38,
                    height * 0.96,
                    "rgba(14, 134, 168, 0.56)",
                    "rgba(10, 88, 128, 0.26)",
                    "rgba(5, 36, 64, 0.07)"
                );

                // 2. Center cobalt-blue dome curving gently up behind the eyes
                drawOrb(
                    width * 0.50 - d * 0.5,
                    height * 1.00,
                    width * 0.34,
                    height * 1.12,
                    "rgba(32, 92, 232, 0.54)",
                    "rgba(20, 56, 174, 0.26)",
                    "rgba(8, 22, 84, 0.06)"
                );

                // 3. Right violet-indigo soft radial orb
                drawOrb(
                    width * 0.88 + d * 0.5,
                    height * 1.05,
                    width * 0.36,
                    height * 0.94,
                    "rgba(108, 48, 208, 0.54)",
                    "rgba(66, 26, 148, 0.24)",
                    "rgba(24, 10, 68, 0.06)"
                );
            }
        }

        // Contextual accent ambient wash (Pomodoro coral / Water blue / Todo green / HUD)
        Rectangle {
            anchors.fill: parent
            opacity: root.glowOpacity
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 320 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.52; color: "transparent" }
                GradientStop { position: 1.0; color: root.glowColor }
            }
        }
    }

    // Smooth rim mask so top bezel edge melts cleanly into screen edge
    Item {
        id: rimFadeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 1.00) }
            }
        }
    }

    // ── Subtle specular rim along sides & bottom only ─────────────
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: rimFadeMask
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.borderColor
            strokeWidth: 1
            startX: root.width - 0.5; startY: 0.5
            PathCubic {
                x: root.width - root.e - 0.5; y: root.e
                control1X: root.width - root.e * 0.45; control1Y: 0.5
                control2X: root.width - root.e - 0.5; control2Y: root.e * 0.45
            }
            PathLine { x: root.width - root.e - 0.5; y: root.height - root.r }
            PathCubic {
                x: root.width - root.e - root.r; y: root.height - 0.5
                control1X: root.width - root.e - 0.5; control1Y: root.height - root.r * 0.45
                control2X: root.width - root.e - root.r * 0.45; control2Y: root.height - 0.5
            }
            PathLine { x: root.e + root.r; y: root.height - 0.5 }
            PathCubic {
                x: root.e + 0.5; y: root.height - root.r
                control1X: root.e + root.r * 0.45; control1Y: root.height - 0.5
                control2X: root.e + 0.5; control2Y: root.height - root.r * 0.45
            }
            PathLine { x: root.e + 0.5; y: root.e }
            PathCubic {
                x: 0.5; y: 0.5
                control1X: root.e + 0.5; control1Y: root.e * 0.45
                control2X: root.e * 0.45; control2Y: 0.5
            }
        }
    }
}
