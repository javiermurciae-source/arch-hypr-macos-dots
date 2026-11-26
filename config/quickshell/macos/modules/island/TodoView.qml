import QtQuick
import QtQuick.Layouts
import "../common"

Item {
    id: root
    required property var ctrl

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 4
        spacing: 14

        // ── Left: Big 4/5 counter + Add Task pill ─────────────────
        ColumnLayout {
            Layout.preferredWidth: 112
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                text: ctrl.todosDoneCount + "/" + ctrl.todos.length
                font { family: Appearance.fontFamily; pixelSize: 30; weight: Font.Bold }
                color: "#ffffff"
            }

            Text {
                text: "Task Done Today"
                font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Medium }
                color: Qt.rgba(1, 1, 1, 0.48)
            }

            Rectangle {
                Layout.topMargin: 6
                height: 22
                width: 78
                radius: 11
                color: addBtnMa.containsMouse ? Qt.rgba(0.19, 0.82, 0.35, 0.32) : Qt.rgba(1, 1, 1, 0.10)
                border.color: ctrl.addingTodo ? "#30d158" : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: ctrl.addingTodo ? "Cancel" : "+ New task"
                    font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.DemiBold }
                    color: "#ffffff"
                }

                MouseArea {
                    id: addBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ctrl.addingTodo = !ctrl.addingTodo;
                        if (ctrl.addingTodo) todoInput.forceActiveFocus();
                    }
                }
            }
        }

        // ── Right: Inline input (optional) + Task cards ───────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            // Inline add input
            Rectangle {
                visible: ctrl.addingTodo
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.10)
                border.color: "#30d158"
                border.width: 1

                TextInput {
                    id: todoInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 28
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#ffffff"
                    selectionColor: "#30d158"
                    font { family: Appearance.fontFamily; pixelSize: 11 }
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type a task and press Enter…"
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font: todoInput.font
                        visible: todoInput.text.length === 0
                    }

                    Keys.onReturnPressed: {
                        ctrl.addTodo(todoInput.text);
                        todoInput.text = "";
                        ctrl.addingTodo = false;
                    }
                    Keys.onEscapePressed: {
                        todoInput.text = "";
                        ctrl.addingTodo = false;
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; radius: 6
                    color: "#30d158"
                    Text {
                        anchors.centerIn: parent; text: "↵"
                        font { family: Appearance.fontFamily; pixelSize: 11; weight: Font.Bold }
                        color: "#04140a"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ctrl.addTodo(todoInput.text);
                            todoInput.text = "";
                            ctrl.addingTodo = false;
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: todoCol.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: todoCol
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: ctrl.todos
                        delegate: Rectangle {
                            id: taskRow
                            required property var modelData
                            width: todoCol.width
                            height: 29
                            radius: 9
                            color: modelData.done
                                ? Qt.rgba(0.11, 0.42, 0.22, 0.34)
                                : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.06))
                            border.color: modelData.done
                                ? Qt.rgba(0.19, 0.82, 0.35, 0.34)
                                : Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1

                            HoverHandler { id: rowHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 8
                                spacing: 8

                                // Check circle
                                Rectangle {
                                    width: 15; height: 15; radius: 7.5
                                    color: modelData.done ? "#30d158" : "transparent"
                                    border.color: modelData.done ? "#30d158" : Qt.rgba(1, 1, 1, 0.36)
                                    border.width: 1.5
                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.done
                                        text: "✓"
                                        font { family: Appearance.fontFamily; pixelSize: 10; weight: Font.Bold }
                                        color: "#051a0c"
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    font {
                                        family: Appearance.fontFamily
                                        pixelSize: 11
                                        weight: modelData.done ? Font.Normal : Font.Medium
                                        strikeout: modelData.done
                                    }
                                    color: modelData.done ? Qt.rgba(1, 1, 1, 0.50) : "#ffffff"
                                    elide: Text.ElideRight
                                }

                                // Delete button on hover
                                Rectangle {
                                    visible: rowHover.hovered
                                    width: 16; height: 16; radius: 8
                                    color: delMa.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.35) : "transparent"
                                    Text {
                                        anchors.centerIn: parent; text: "✕"
                                        font.pixelSize: 8; color: Qt.rgba(1, 1, 1, 0.65)
                                    }
                                    MouseArea {
                                        id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: ctrl.removeTodo(modelData.id)
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: rowHover.hovered ? 24 : 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctrl.toggleTodo(modelData.id)
                            }
                        }
                    }

                    Text {
                        visible: ctrl.todos.length === 0
                        width: todoCol.width
                        height: 60
                        text: "All clear! Click + New task."
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font { family: Appearance.fontFamily; pixelSize: 11 }
                        color: Qt.rgba(1, 1, 1, 0.42)
                    }
                }
            }
        }
    }
}
