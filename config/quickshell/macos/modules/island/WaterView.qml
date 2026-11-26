import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: root
    required property var ctrl

    // ── Normal Water Reminder view ────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 14
        visible: !ctrl.waterSettingsOpen

        // Left: Liters count + bell toggle + progress + Drink/Settings buttons
        ColumnLayout {
            Layout.preferredWidth: 186
            Layout.fillHeight: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: ctrl.waterLitersText
                    font { family: Appearance.fontFamily; pixelSize: 25; weight: Font.Bold }
                    color: "#ffffff"
                }
                Text {
                    text: "/ " + ctrl.waterGoalLitersText + " L"
                    font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Medium }
                    color: Qt.rgba(1, 1, 1, 0.54)
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 4
                }

                Item { Layout.fillWidth: true }

                // Blue bell toggle switch
                Rectangle {
                    width: 34; height: 19; radius: 9.5
                    color: ctrl.waterReminderOn ? "#2584ff" : Qt.rgba(1, 1, 1, 0.18)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 15; height: 15; radius: 7.5
                        y: 2
                        x: ctrl.waterReminderOn ? parent.width - 17 : 2
                        color: "#ffffff"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ctrl.waterReminderOn = !ctrl.waterReminderOn;
                            ctrl.saveState();
                        }
                    }
                }
            }

            // Today · 71% · Next 14:22
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    text: "Today"
                    font { family: Appearance.fontFamily; pixelSize: 10 }
                    color: Qt.rgba(1, 1, 1, 0.52)
                }
                Text {
                    text: Math.round(ctrl.waterProgress * 100) + "%"
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                    color: "#3b9eff"
                }
                Text {
                    text: "· Next " + ctrl.waterNextTime
                    font { family: Appearance.fontFamily; pixelSize: 10 }
                    color: Qt.rgba(1, 1, 1, 0.52)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Blue progress bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.14)

                Rectangle {
                    width: Math.max(height, parent.width * ctrl.waterProgress)
                    height: parent.height
                    radius: 2.5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#2ea0ff" }
                        GradientStop { position: 1.0; color: "#5ec2ff" }
                    }
                    Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                }
            }

            Item { Layout.fillHeight: true }

            // [Drink]  [Settings]
            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 74
                    radius: 12
                    color: drinkMa.containsMouse ? "#1f6ce0" : "#15499c"
                    border.color: "#3b9eff"
                    border.width: 1
                    scale: drinkMa.pressed ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Canvas {
                            width: 10; height: 12
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.fillStyle = "#7cc7ff";
                                ctx.beginPath();
                                ctx.moveTo(5, 1);
                                ctx.quadraticCurveTo(9, 6, 9, 8.2);
                                ctx.arc(5, 8.2, 4, 0, Math.PI);
                                ctx.quadraticCurveTo(1, 6, 5, 1);
                                ctx.fill();
                            }
                        }
                        Text {
                            text: "Drink"
                            font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: drinkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.addWater(ctrl.waterCupMl)
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.fillWidth: true
                    radius: 12
                    color: setMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Settings"
                        font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                        color: Qt.rgba(1, 1, 1, 0.88)
                    }

                    MouseArea {
                        id: setMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.waterSettingsOpen = true
                    }
                }
            }
        }

        // Right: Hourly bar chart (matches Nusa screenshot!)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property var hours: [9, 11, 13, 15, 17, 19, 21]

            Canvas {
                id: chartCanvas
                anchors.fill: parent
                property var hourlyData: ctrl.waterHourly
                property int totalMl: ctrl.waterMl
                onHourlyDataChanged: requestPaint()
                onTotalMlChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var padL = 6, padR = 32, padT = 10, padB = 18;
                    var cw = Math.max(10, width - padL - padR);
                    var ch = Math.max(10, height - padT - padB);

                    // Grid lines + Y-axis labels (400, 200, 0 ml)
                    var yTicks = [
                        { v: 1.0, lbl: "400" },
                        { v: 0.5, lbl: "200" },
                        { v: 0.0, lbl: "0 ml" }
                    ];
                    ctx.font = "9px 'SF Pro Display', sans-serif";
                    for (var i = 0; i < yTicks.length; i++) {
                        var yy = padT + (1 - yTicks[i].v) * ch;
                        ctx.strokeStyle = "rgba(255,255,255,0.08)";
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(padL, yy);
                        ctx.lineTo(padL + cw, yy);
                        ctx.stroke();

                        ctx.fillStyle = "rgba(255,255,255,0.45)";
                        ctx.fillText(yTicks[i].lbl, padL + cw + 5, yy + 3);
                    }

                    // Aggregate buckets around 08..22 (8 bars)
                    var buckets = [8, 10, 12, 14, 16, 18, 20, 22];
                    var slotW = cw / buckets.length;
                    var barW = Math.min(12, Math.max(6, slotW - 5));

                    for (var b = 0; b < buckets.length; b++) {
                        var h0 = buckets[b];
                        var ml = (hourlyData[String(h0)] || 0) + (hourlyData[String(h0 + 1)] || 0);
                        var bx = padL + b * slotW + (slotW - barW) / 2;

                        // Dim background bar slot
                        ctx.fillStyle = "rgba(255,255,255,0.04)";
                        ctx.beginPath();
                        ctx.roundedRect(bx, padT, barW, ch, barW / 2, barW / 2);
                        ctx.fill();

                        // Active blue capsule bar
                        if (ml > 0) {
                            var frac = Math.min(1.0, ml / 400.0);
                            var bh = Math.max(barW, frac * ch);
                            var by = padT + ch - bh;
                            var grad = ctx.createLinearGradient(0, by, 0, padT + ch);
                            grad.addColorStop(0.0, "#5ec2ff");
                            grad.addColorStop(1.0, "#1976ff");
                            ctx.fillStyle = grad;
                            ctx.beginPath();
                            ctx.roundedRect(bx, by, barW, bh, barW / 2, barW / 2);
                            ctx.fill();
                        }

                        // X labels (09, 12, 15, 18, 21 style)
                        if (b === 0 || b === 2 || b === 4 || b === 6) {
                            ctx.fillStyle = "rgba(255,255,255,0.45)";
                            ctx.fillText(("0" + h0).slice(-2), bx - 1, height - 3);
                        }
                    }
                }
            }
        }
    }

    // ── Inline Quick Settings Panel ───────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8
        visible: ctrl.waterSettingsOpen

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Daily Goal"
                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                color: Qt.rgba(1, 1, 1, 0.72)
                Layout.preferredWidth: 74
            }
            Repeater {
                model: [1500, 2000, 2500, 3000]
                delegate: Rectangle {
                    required property int modelData
                    Layout.preferredHeight: 22
                    Layout.fillWidth: true
                    radius: 11
                    color: ctrl.waterGoalMl === modelData ? "#2584ff" : Qt.rgba(1, 1, 1, 0.09)
                    Text {
                        anchors.centerIn: parent
                        text: (modelData / 1000).toFixed(1) + " L"
                        font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                        color: "#ffffff"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { ctrl.waterGoalMl = modelData; ctrl.saveState(); }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Reminder"
                font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                color: Qt.rgba(1, 1, 1, 0.72)
                Layout.preferredWidth: 74
            }
            Repeater {
                model: [30, 45, 60, 90]
                delegate: Rectangle {
                    required property int modelData
                    Layout.preferredHeight: 22
                    Layout.fillWidth: true
                    radius: 11
                    color: ctrl.waterIntervalMin === modelData ? "#2584ff" : Qt.rgba(1, 1, 1, 0.09)
                    Text {
                        anchors.centerIn: parent
                        text: modelData + "m"
                        font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                        color: "#ffffff"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ctrl.waterIntervalMin = modelData;
                            ctrl.updateNextWaterTime();
                            ctrl.saveState();
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Rectangle {
                height: 24; width: 92; radius: 12
                color: Qt.rgba(1.0, 0.27, 0.23, 0.22)
                border.color: Qt.rgba(1.0, 0.27, 0.23, 0.5)
                border.width: 1
                Text {
                    anchors.centerIn: parent; text: "Reset Today"
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                    color: "#ff6961"
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.resetWaterToday()
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                height: 24; width: 64; radius: 12
                color: Qt.rgba(1, 1, 1, 0.16)
                Text {
                    anchors.centerIn: parent; text: "Done"
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                    color: "#ffffff"
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: ctrl.waterSettingsOpen = false
                }
            }
        }
    }
}
