import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: root
    required property var ctrl

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ── Left: Drag & Drop File Shelf ──────────────────────────
        Rectangle {
            id: shelfDropBox
            Layout.fillWidth: true
            Layout.preferredWidth: 230
            Layout.fillHeight: true
            radius: 12
            color: dropArea.containsDrag ? Qt.rgba(0.18, 0.52, 1.0, 0.20) : Qt.rgba(1, 1, 1, 0.04)
            border.color: dropArea.containsDrag ? "#3b9eff" : Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
            clip: true

            DropArea {
                id: dropArea
                anchors.fill: parent
                enabled: !ctrl.draggingShelfOut
                onDropped: (drop) => {
                    if (drop.hasUrls && drop.urls.length > 0) {
                        ctrl.addShelfPaths(drop.urls);
                        drop.acceptProposedAction();
                    } else if (drop.hasText && drop.text.trim().length > 0) {
                        ctrl.copyText(drop.text.trim());
                        drop.acceptProposedAction();
                    }
                }
            }

            // Empty drop prompt
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                visible: ctrl.shelfItems.length === 0

                Canvas {
                    Layout.alignment: Qt.AlignHCenter
                    width: 24; height: 20
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#3b9eff";
                        ctx.beginPath();
                        ctx.roundedRect(2, 4, 20, 14, 3, 3);
                        ctx.fill();
                        ctx.fillStyle = "#7cc7ff";
                        ctx.beginPath();
                        ctx.roundedRect(2, 2, 9, 5, 2, 2);
                        ctx.fill();
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: dropArea.containsDrag ? "Suelta para guardar" : "Arrastra archivos aquí"
                    font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                    color: dropArea.containsDrag ? "#5ec2ff" : Qt.rgba(1, 1, 1, 0.65)
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Arrastra fuera a cualquier app · Clic abre"
                    font { family: Appearance.fontFamily; pixelSize: 9 }
                    color: Qt.rgba(1, 1, 1, 0.36)
                }
            }

            // Dropped file tiles (horizontal scroll; drag any tile out to Nautilus, browser, ChatGPT, etc.)
            Flickable {
                id: shelfFlick
                anchors.fill: parent
                anchors.margins: 6
                visible: ctrl.shelfItems.length > 0
                contentWidth: shelfRow.width
                contentHeight: height
                clip: true
                interactive: !ctrl.draggingShelfOut
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: shelfRow
                    height: parent.height
                    spacing: 8

                    Repeater {
                        model: ctrl.shelfItems
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            readonly property string fileUri: ctrl.filePathToUri(modelData.path)
                            property bool isDraggingThis: false

                            width: 72
                            height: shelfRow.height
                            radius: 10
                            color: isDraggingThis
                                ? Qt.rgba(0.23, 0.62, 1.0, 0.24)
                                : (tileHover.hovered ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.05))
                            border.color: isDraggingThis ? "#3b9eff" : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            opacity: isDraggingThis ? 0.72 : 1.0
                            scale: isDraggingThis ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                            HoverHandler { id: tileHover }

                            // Native Wayland/Qt external drag source (works in Nautilus, Firefox, ChatGPT, Telegram, etc.)
                            Item {
                                id: dragProxy
                                anchors.fill: parent
                                Drag.dragType: Drag.Automatic
                                Drag.supportedActions: Qt.CopyAction
                                Drag.proposedAction: Qt.CopyAction
                                Drag.imageSource: modelData.isImage
                                    ? tile.fileUri
                                    : Qt.resolvedUrl("../../assets/icons/file_drag.svg")
                                Drag.imageSourceSize: Qt.size(56, 56)
                                Drag.hotSpot: Qt.point(28, 28)
                                Drag.mimeData: ({
                                    "text/uri-list": tile.fileUri + "\r\n",
                                    "x-special/gnome-copied-files": "copy\n" + tile.fileUri,
                                    "text/plain": tile.fileUri
                                })
                                Drag.onDragStarted: {
                                    tile.isDraggingThis = true;
                                    ctrl.draggingShelfOut = true;
                                }
                                Drag.onDragFinished: (dropAction) => {
                                    dragProxy.Drag.active = false;
                                    tile.isDraggingThis = false;
                                    ctrl.draggingShelfOut = false;
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 3

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 9
                                    color: "#1a2638"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.isImage ? tile.fileUri : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: modelData.isImage && status === Image.Ready
                                    }

                                    Canvas {
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        visible: !modelData.isImage
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            ctx.fillStyle = "#5ec2ff";
                                            ctx.beginPath();
                                            ctx.roundedRect(4, 2, 16, 20, 3, 3);
                                            ctx.fill();
                                            ctx.fillStyle = "#0f2238";
                                            ctx.fillRect(7, 8, 10, 2);
                                            ctx.fillRect(7, 12, 8, 2);
                                            ctx.fillRect(7, 16, 6, 2);
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font { family: Appearance.fontFamily; pixelSize: 9; weight: Font.DemiBold }
                                    color: "#ffffff"
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 1
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.sizeText
                                    font { family: Appearance.fontFamily; pixelSize: 8 }
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                id: tileDragMa
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                preventStealing: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                property real pressX: 0
                                property real pressY: 0
                                property bool didDrag: false

                                onPressed: (m) => {
                                    pressX = m.x;
                                    pressY = m.y;
                                    didDrag = false;
                                }
                                onPositionChanged: (m) => {
                                    if (didDrag || !(m.buttons & Qt.LeftButton)) return;
                                    const dx = m.x - pressX;
                                    const dy = m.y - pressY;
                                    if (dx * dx + dy * dy >= 36) {
                                        didDrag = true;
                                        tile.isDraggingThis = true;
                                        ctrl.draggingShelfOut = true;
                                        dragProxy.Drag.active = true;
                                        if (!dragProxy.Drag.active) {
                                            tile.isDraggingThis = false;
                                            ctrl.draggingShelfOut = false;
                                        }
                                    }
                                }
                                onReleased: (m) => {
                                    if (didDrag) {
                                        didDrag = false;
                                        return;
                                    }
                                    if (m.button === Qt.RightButton) ctrl.copyShelfFile(modelData.path);
                                    else if (m.button === Qt.LeftButton) ctrl.openShelfItem(modelData.path);
                                }
                                onCanceled: {
                                    didDrag = false;
                                    tile.isDraggingThis = false;
                                    ctrl.draggingShelfOut = false;
                                }
                            }

                            // Top-left copy-file button (pastes real file with Ctrl+V anywhere)
                            Rectangle {
                                visible: tileHover.hovered && !tile.isDraggingThis
                                anchors.top: parent.top; anchors.left: parent.left
                                anchors.margins: 3
                                width: 15; height: 15; radius: 7.5
                                color: copyTileMa.containsMouse ? "#3b9eff" : Qt.rgba(0, 0, 0, 0.72)
                                Text { anchors.centerIn: parent; text: "⧉"; font.pixelSize: 8; color: "#ffffff" }
                                MouseArea {
                                    id: copyTileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ctrl.copyShelfFile(modelData.path)
                                }
                            }

                            // Top-right remove button
                            Rectangle {
                                visible: tileHover.hovered && !tile.isDraggingThis
                                anchors.top: parent.top; anchors.right: parent.right
                                anchors.margins: 3
                                width: 15; height: 15; radius: 7.5
                                color: delTileMa.containsMouse ? "#ff453a" : Qt.rgba(0, 0, 0, 0.72)
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 8; color: "#ffffff" }
                                MouseArea {
                                    id: delTileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ctrl.removeShelfItem(modelData.path)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Right: Clipboard History (cliphist) ───────────────────
        Rectangle {
            Layout.preferredWidth: 168
            Layout.fillHeight: true
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Clipboard"
                        font { family: Appearance.fontFamily; pixelSize: 9; weight: Font.Bold }
                        color: Qt.rgba(1, 1, 1, 0.54)
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "↻"
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.48)
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: ctrl.refreshClipboard()
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: clipCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: clipCol
                        width: parent.width
                        spacing: 3

                        Repeater {
                            model: ctrl.clipItems
                            delegate: Rectangle {
                                required property var modelData
                                width: clipCol.width
                                height: 22
                                radius: 6
                                color: clipMa.containsMouse ? Qt.rgba(0.37, 0.61, 1.0, 0.24) : Qt.rgba(1, 1, 1, 0.05)

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.preview
                                    font { family: Appearance.fontFamily; pixelSize: 9 }
                                    color: Qt.rgba(1, 1, 1, 0.86)
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: clipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ctrl.copyClipId(modelData.id, modelData.preview)
                                }
                            }
                        }

                        Text {
                            visible: ctrl.clipItems.length === 0
                            width: clipCol.width
                            height: 44
                            text: "No clipboard history"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font { family: Appearance.fontFamily; pixelSize: 9 }
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }
                    }
                }
            }
        }
    }
}
