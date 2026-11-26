import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: root
    required property var ctrl

    readonly property color accent: ctrl.pomoMode === "focus" ? "#ff3b5c" : "#30d158"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 16

        // ── Left: Glowing Circular Progress Ring + Stopwatch ──────
        Item {
            Layout.preferredWidth: 74
            Layout.preferredHeight: 74
            Layout.alignment: Qt.AlignVCenter

            Canvas {
                id: ringCanvas
                anchors.fill: parent
                property real progress: ctrl.pomoProgress
                property color ringColor: root.accent
                onProgressChanged: requestPaint()
                onRingColorChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var cx = width / 2, cy = height / 2, r = 28;

                    // Soft dark ring track
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.strokeStyle = Qt.rgba(ringColor.r, ringColor.g, ringColor.b, 0.25);
                    ctx.lineWidth = 6;
                    ctx.stroke();

                    // Active progress arc (full glow ring when idle at 0 so it matches Nusa look)
                    var sweep = progress > 0.005 ? (Math.PI * 2 * (1 - progress)) : (Math.PI * 2);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + sweep);
                    ctx.strokeStyle = ringColor;
                    ctx.lineWidth = 6;
                    ctx.lineCap = "round";
                    ctx.stroke();

                    // Crisp white stopwatch icon inside
                    ctx.strokeStyle = "#ffffff";
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.arc(cx, cy + 2, 10, 0, Math.PI * 2);
                    ctx.stroke();

                    // Top crown button
                    ctx.beginPath();
                    ctx.moveTo(cx - 3.5, cy - 11.5);
                    ctx.lineTo(cx + 3.5, cy - 11.5);
                    ctx.moveTo(cx, cy - 11.5);
                    ctx.lineTo(cx, cy - 8);
                    ctx.stroke();

                    // Clock hand
                    ctx.beginPath();
                    ctx.moveTo(cx, cy + 2);
                    ctx.lineTo(cx + 3.5, cy - 2);
                    ctx.stroke();
                }
            }
        }

        // ── Right: Huge Countdown + Mode & Play Pills ─────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    text: ctrl.pomoText
                    font { family: Appearance.fontFamily; pixelSize: 28; weight: Font.Bold }
                    color: "#ffffff"
                }

                // Reset circle button
                Rectangle {
                    width: 22; height: 22; radius: 11
                    color: resetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)
                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        font { family: Appearance.fontFamily; pixelSize: 13; weight: Font.Bold }
                        color: Qt.rgba(1, 1, 1, 0.82)
                    }
                    MouseArea {
                        id: resetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.resetPomo()
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: ctrl.pomoMode === "focus" ? "Focus time" : "Short break"
                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Medium }
                color: Qt.rgba(1, 1, 1, 0.52)
            }

            // Control pills row: [Short Break]  [ ▶ / ⏸ ]  [Focus Time]
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 7

                Rectangle {
                    height: 24
                    width: sbTxt.implicitWidth + 18
                    radius: 12
                    color: ctrl.pomoMode === "break" ? Qt.rgba(0.19, 0.82, 0.35, 0.22) : (sbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: ctrl.pomoMode === "break" ? Qt.rgba(0.19, 0.82, 0.35, 0.55) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    Text {
                        id: sbTxt; anchors.centerIn: parent
                        text: "Short Break"
                        font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: sbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.setPomoMode("break")
                    }
                }

                // Primary coral play/pause pill
                Rectangle {
                    width: 52; height: 24; radius: 12
                    color: root.accent
                    scale: ppMa.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Canvas {
                        id: pomoPlayIcon
                        anchors.centerIn: parent; width: 12; height: 12
                        property bool run: ctrl.pomoRunning
                        onRunChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = "#ffffff";
                            if (run) {
                                ctx.fillRect(2, 1.5, 3, 9);
                                ctx.fillRect(7, 1.5, 3, 9);
                            } else {
                                ctx.beginPath();
                                ctx.moveTo(3, 1.5); ctx.lineTo(10.5, 6); ctx.lineTo(3, 10.5);
                                ctx.closePath(); ctx.fill();
                            }
                        }
                    }

                    MouseArea {
                        id: ppMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.togglePomo()
                    }
                }

                Rectangle {
                    height: 24
                    width: ftTxt.implicitWidth + 18
                    radius: 12
                    color: ctrl.pomoMode === "focus" ? Qt.rgba(1.0, 0.23, 0.36, 0.22) : (ftMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: ctrl.pomoMode === "focus" ? Qt.rgba(1.0, 0.23, 0.36, 0.55) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    Text {
                        id: ftTxt; anchors.centerIn: parent
                        text: "Focus Time"
                        font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: ftMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.setPomoMode("focus")
                    }
                }
            }
        }
    }
}
