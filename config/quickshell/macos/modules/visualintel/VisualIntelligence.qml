import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// macOS Visual Intelligence Contextual Menu (Shift + Super + 6)
// Select a screen region -> floating glass menu right below the cutout:
//   - Ask Antigravity (agy -p Gemini 3.8 Flash Low) with inline Markdown answer
//   - Image Search (Google Lens via local HTML POST -> Firefox)
//   - Explicar / Traducir / Copiar texto (OCR) / Copiar imagen / Detected URL
Scope {
    id: viScope

    property bool open: false
    property string phase: "select" // "select" | "menu"
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property bool dragging: false

    readonly property real selX: Math.min(startX, endX)
    readonly property real selY: Math.min(startY, endY)
    readonly property real selW: Math.abs(endX - startX)
    readonly property real selH: Math.abs(endY - startY)

    property string cropPath: "/tmp/visual_intel_crop.png"
    property string questionText: ""
    property string answerText: ""
    property bool loading: false
    property string detectedUrl: ""
    property string statusToast: ""

    readonly property string helper: Quickshell.env("HOME") + "/.config/quickshell/macos/modules/visualintel/vi_helper.py"

    function launch() {
        askProc.running = false;
        urlProc.running = false;
        viScope.phase = "select";
        viScope.dragging = false;
        viScope.startX = 0; viScope.startY = 0;
        viScope.endX = 0; viScope.endY = 0;
        viScope.questionText = "";
        viScope.answerText = "";
        viScope.loading = false;
        viScope.detectedUrl = "";
        viScope.statusToast = "";
        viScope.open = true;
    }

    function dismiss() {
        askProc.running = false;
        urlProc.running = false;
        viScope.open = false;
        viScope.phase = "select";
        viScope.loading = false;
    }

    function runCapture(nx, ny, nw, nh) {
        capProc.command = [
            "python3", viScope.helper, "capture",
            nx.toFixed(6), ny.toFixed(6), nw.toFixed(6), nh.toFixed(6),
            viScope.cropPath
        ];
        capProc.running = false;
        capProc.running = true;
    }

    function askAgy(prompt, displayLabel) {
        if (!prompt || prompt.trim() === "") return;
        viScope.questionText = displayLabel || prompt.trim();
        viScope.answerText = "";
        viScope.statusToast = "";
        viScope.loading = true;
        askProc.running = false;
        askProc.command = ["python3", viScope.helper, "ask", viScope.cropPath, prompt.trim()];
        askProc.running = true;
    }

    function runOcr() {
        viScope.questionText = "Texto extraído (copiado al portapapeles)";
        viScope.answerText = "";
        viScope.statusToast = "";
        viScope.loading = true;
        askProc.running = false;
        askProc.command = ["python3", viScope.helper, "ocr", viScope.cropPath];
        askProc.running = true;
    }

    function runGoogleLens() {
        Quickshell.execDetached(["python3", viScope.helper, "lens", viScope.cropPath]);
        viScope.dismiss();
    }

    function copyImage() {
        Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < '" + viScope.cropPath + "'"]);
        viScope.dismiss();
    }

    function copyAnswer() {
        if (!viScope.answerText) return;
        copyAnsProc.command = ["wl-copy", "--", viScope.answerText];
        copyAnsProc.running = false;
        copyAnsProc.running = true;
        viScope.statusToast = "Copiado ✓";
    }

    Process {
        id: capProc
        onExited: (code) => {
            if (code === 0 && viScope.open) {
                viScope.phase = "menu";
                urlProc.command = ["python3", viScope.helper, "quick_url", viScope.cropPath];
                urlProc.running = true;
            }
        }
    }

    Process {
        id: urlProc
        stdout: StdioCollector {
            onStreamFinished: {
                const u = (text || "").trim();
                if (u.length > 3) viScope.detectedUrl = u;
            }
        }
    }

    Process {
        id: askProc
        stdout: SplitParser {
            onRead: (line) => {
                viScope.answerText += (viScope.answerText.length > 0 ? "\n" : "") + line;
            }
        }
        onExited: {
            viScope.loading = false;
        }
    }

    Process { id: copyAnsProc }

    IpcHandler {
        target: "visualintel"
        function open(): void { viScope.launch() }
        function toggle(): void { if (viScope.open) viScope.dismiss(); else viScope.launch() }
        function close(): void { viScope.dismiss() }
    }

    // ── Fullscreen Overlay Window ─────────────────────────────────
    PanelWindow {
        id: overlay
        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "macos:visualintel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: viScope.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        visible: viScope.open

        onVisibleChanged: {
            if (visible) keyCatcher.forceActiveFocus();
        }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: viScope.dismiss()
        }

        // ── Dimming Mask (4-rect cutout around selection) ──
        readonly property color dimCol: Qt.rgba(0, 0, 0, 0.36)

        Rectangle {
            anchors.fill: parent
            color: overlay.dimCol
            visible: viScope.selW < 4 || viScope.selH < 4
        }

        Item {
            anchors.fill: parent
            visible: viScope.selW >= 4 && viScope.selH >= 4
            Rectangle { x: 0; y: 0; width: parent.width; height: viScope.selY; color: overlay.dimCol }
            Rectangle { x: 0; y: viScope.selY + viScope.selH; width: parent.width; height: parent.height - (viScope.selY + viScope.selH); color: overlay.dimCol }
            Rectangle { x: 0; y: viScope.selY; width: viScope.selX; height: viScope.selH; color: overlay.dimCol }
            Rectangle { x: viScope.selX + viScope.selW; y: viScope.selY; width: parent.width - (viScope.selX + viScope.selW); height: viScope.selH; color: overlay.dimCol }
        }

        // ── Selection Drag Area ──
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: viScope.phase === "select" ? Qt.CrossCursor : Qt.ArrowCursor
            onPressed: (m) => {
                if (m.button === Qt.RightButton) { viScope.dismiss(); return; }
                if (viScope.phase === "menu") {
                    viScope.dismiss();
                    return;
                }
                viScope.dragging = true;
                viScope.startX = m.x; viScope.startY = m.y;
                viScope.endX = m.x; viScope.endY = m.y;
            }
            onPositionChanged: (m) => {
                if (!viScope.dragging) return;
                viScope.endX = Math.max(0, Math.min(overlay.width, m.x));
                viScope.endY = Math.max(0, Math.min(overlay.height, m.y));
            }
            onReleased: {
                if (!viScope.dragging) return;
                viScope.dragging = false;
                if (viScope.selW >= 16 && viScope.selH >= 16) {
                    viScope.runCapture(
                        viScope.selX / overlay.width,
                        viScope.selY / overlay.height,
                        viScope.selW / overlay.width,
                        viScope.selH / overlay.height
                    );
                } else {
                    viScope.dismiss();
                }
            }
        }

        // ── macOS White Rounded Selection Frame + Handles (like reference photo!) ──
        Rectangle {
            visible: viScope.selW >= 6 && viScope.selH >= 6
            x: viScope.selX - 2
            y: viScope.selY - 2
            width: viScope.selW + 4
            height: viScope.selH + 4
            radius: 10
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(1, 1, 1, 0.94)

            // 8 macOS-style white circular handles
            component Dot: Rectangle {
                width: 9; height: 9; radius: 4.5
                color: "#ffffff"
                border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.18)
            }
            Dot { x: -3; y: -3 }
            Dot { x: parent.width / 2 - 4.5; y: -3 }
            Dot { x: parent.width - 6; y: -3 }
            Dot { x: -3; y: parent.height - 6 }
            Dot { x: parent.width / 2 - 4.5; y: parent.height - 6 }
            Dot { x: parent.width - 6; y: parent.height - 6 }
        }

        // ── Hint pill while selecting ──
        Rectangle {
            visible: viScope.phase === "select" && !viScope.dragging
            anchors.top: parent.top
            anchors.topMargin: 52
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintLbl.implicitWidth + 32
            height: 34
            radius: 17
            color: Qt.rgba(0.10, 0.11, 0.14, 0.86)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)
            Text {
                id: hintLbl
                anchors.centerIn: parent
                text: "Arrastra para seleccionar una región  ·  Esc para cancelar"
                color: "#ffffff"
                font.family: "SF Pro Text"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        // ── Floating macOS Visual Intelligence Contextual Menu ──
        Column {
            id: menuCol
            visible: viScope.phase === "menu"
            z: 20
            spacing: 7
            width: viScope.questionText !== "" || viScope.loading ? 420 : 320

            // Smart positioning: right below the selection, clamped inside screen
            x: Math.max(16, Math.min(overlay.width - width - 16, viScope.selX))
            y: {
                const below = viScope.selY + viScope.selH + 14;
                const estH = (viScope.questionText !== "" || viScope.loading) ? 320 : 230;
                if (below + estH < overlay.height - 16) return below;
                return Math.max(16, viScope.selY - estH - 14);
            }

            onVisibleChanged: {
                if (visible) {
                    askInput.text = "";
                    Qt.callLater(() => askInput.forceActiveFocus());
                }
            }

            // ── 1. Top "Ask Antigravity" Pill (exact macOS frosted light pill!) ──
            Rectangle {
                id: askPill
                width: menuCol.width
                height: 44
                radius: 22
                color: Qt.rgba(0.93, 0.94, 0.96, 0.90)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.85)
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowOpacity: 0.28; shadowBlur: 0.65; shadowVerticalOffset: 5 }

                Text {
                    id: sparkIco
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✦"
                    font.pixelSize: 16
                    color: "#2c2c2e"
                }

                TextInput {
                    id: askInput
                    anchors.left: sparkIco.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: "SF Pro Text"
                    font.pixelSize: 15
                    color: "#1d1d1f"
                    selectionColor: "#0A84FF"
                    clip: true
                    Keys.onEscapePressed: viScope.dismiss()
                    onAccepted: {
                        const q = text.trim();
                        viScope.askAgy(q.length > 0 ? q : "Explica de forma clara y breve qué aparece en esta imagen.", q.length > 0 ? q : "Explicar selección");
                        text = "";
                    }
                    Text {
                        visible: !askInput.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Preguntar a Antigravity…"
                        color: Qt.rgba(0.12, 0.12, 0.14, 0.48)
                        font: askInput.font
                    }
                }
            }

            // Reusable macOS frosted action pill
            component ActionPill: Rectangle {
                id: ap
                property string iconText: ""
                property string labelText: ""
                signal triggered()
                height: 36
                width: pillRow.implicitWidth + 30
                radius: 18
                color: apMa.containsMouse ? Qt.rgba(0.98, 0.98, 1.0, 0.96) : Qt.rgba(0.91, 0.92, 0.95, 0.88)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.72)
                Behavior on color { ColorAnimation { duration: 120 } }
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowOpacity: 0.22; shadowBlur: 0.5; shadowVerticalOffset: 4 }

                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: ap.iconText
                        font.pixelSize: 14
                        color: "#1d1d1f"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: ap.labelText
                        font.family: "SF Pro Text"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#1d1d1f"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: apMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ap.triggered()
                }
            }

            // ── 2. Contextual Action Pills (Image Search, Explícame, Resume esto) ──
            Column {
                visible: !viScope.loading && viScope.answerText === "" && viScope.questionText === ""
                spacing: 7

                ActionPill {
                    iconText: "🔍"
                    labelText: "Image Search"
                    onTriggered: viScope.runGoogleLens()
                }
                ActionPill {
                    iconText: "✦"
                    labelText: "Explícame esto"
                    onTriggered: viScope.askAgy("Explícame de forma clara, directa y útil qué es o cómo funciona lo que aparece en esta imagen (código, repositorio, error o concepto).", "Explícame esto")
                }
                ActionPill {
                    iconText: "📝"
                    labelText: "Resume esto"
                    onTriggered: viScope.askAgy("Resume en puntos clave y de forma muy clara lo más importante que aparece en esta imagen.", "Resume esto")
                }
            }

            // ── 3. Inline Answer Card (appears right below the pill!) ──
            Rectangle {
                visible: viScope.loading || viScope.answerText !== "" || viScope.questionText !== ""
                width: menuCol.width
                height: Math.min(360, ansCol.implicitHeight + 36)
                radius: 20
                color: Qt.rgba(0.96, 0.97, 0.98, 0.95)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.88)
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowOpacity: 0.28; shadowBlur: 0.7; shadowVerticalOffset: 6 }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 16
                    contentHeight: ansCol.implicitHeight
                    clip: true

                    Column {
                        id: ansCol
                        width: parent.width
                        spacing: 10

                        // Header row: question + Copy button
                        Row {
                            width: parent.width
                            spacing: 8
                            Text {
                                width: parent.width - copyBtn.width - 8
                                text: viScope.questionText
                                wrapMode: Text.Wrap
                                font.family: "SF Pro Display"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: "#1d1d1f"
                            }
                            Rectangle {
                                id: copyBtn
                                visible: viScope.answerText !== ""
                                width: copyLbl.implicitWidth + 16
                                height: 24
                                radius: 12
                                color: copyMa.containsMouse ? "#0A84FF" : Qt.rgba(0, 0, 0, 0.08)
                                Text {
                                    id: copyLbl
                                    anchors.centerIn: parent
                                    text: viScope.statusToast !== "" ? viScope.statusToast : "Copiar"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: copyMa.containsMouse ? "#ffffff" : "#1d1d1f"
                                }
                                MouseArea {
                                    id: copyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: viScope.copyAnswer()
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.08) }

                        Text {
                            width: parent.width
                            text: viScope.answerText !== "" ? viScope.answerText : "Analizando imagen con Antigravity…"
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap
                            font.family: "SF Pro Text"
                            font.pixelSize: 14
                            lineHeight: 1.25
                            color: viScope.answerText !== "" ? "#2c2c2e" : "#6e6e73"
                        }
                    }
                }
            }
        }
    }
}
