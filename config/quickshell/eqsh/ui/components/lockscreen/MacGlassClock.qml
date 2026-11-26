import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs

// Exact MacSDDM Liquid Glass Clock (MorphText + glasstext.frag.qsb + Open Runde)
Item {
    id: root

    // Required: the live background Item to refract through the glass digits
    property Item backdropItem: null
    // Reference root item for coordinate mapping (defaults to parent)
    property Item coordRoot: parent
    property real scaleFactor: 1.0
    property real clockPx: 148 * scaleFactor
    property bool showDate: true
    property real glassIntensity: 0.34
    property real glassRefraction: 13
    property color glassTint: "#C8D4E3"

    readonly property string timeStr: Time.getTime("h:mm ap").replace(/\s*(am|pm|a\.?\s*m\.?|p\.?\s*m\.?)$/i, "").trim()
    readonly property string dateStr: Time.getTime("dddd, MMMM d")

    width: Math.max(showDate ? dateTxt.implicitWidth : 0, timeItem.width)
    height: (showDate ? (dateTxt.implicitHeight - 14 * scaleFactor) : 0) + timeItem.height

    FontLoader {
        id: openRundeSemi
        source: "file://" + Quickshell.env("HOME") + "/MacSDDM/assets/fonts/OpenRunde-Semibold.otf"
    }

    readonly property string clockFamily: {
        if (Qt.fontFamilies().indexOf("Nunito") >= 0) return "Nunito";
        if (openRundeSemi.status === FontLoader.Ready) return openRundeSemi.name;
        return "Open Runde";
    }

    // Shared backdrop texture for glass refraction
    ShaderEffectSource {
        id: glassTexture
        sourceItem: root.backdropItem
        live: root.visible && !!root.backdropItem
        mipmap: true
        visible: false
    }

    // DATE (optional, shown on standard lock screen)
    MorphText {
        id: dateTxt
        visible: root.showDate
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
        text: root.dateStr
        color: "#E8EEF6"
        font.family: openRundeSemi.status === FontLoader.Ready ? openRundeSemi.name : root.clockFamily
        font.pixelSize: 23 * root.scaleFactor
        font.weight: 600
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#99000000"
            shadowBlur: 0.55
            shadowOpacity: 0.30
            shadowVerticalOffset: 1.5
        }
    }

    // LIQUID GLASS CLOCK
    Item {
        id: timeItem
        anchors.top: root.showDate ? dateTxt.bottom : parent.top
        anchors.topMargin: root.showDate ? (-14 * root.scaleFactor) : 0
        anchors.horizontalCenter: parent.horizontalCenter

        readonly property real mp: Math.max(40 * root.scaleFactor, root.clockPx * 0.48)

        width: timeTxt.implicitWidth + 40
        height: timeTxt.implicitHeight

        // Hidden MorphText glyph mask
        MorphText {
            id: timeTxt
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            duration: 560
            useBlur: false
            animateWidth: false
            stretch: false
            scaleIn: 1.03
            scaleOut: 0.97
            text: root.timeStr
            color: "white"
            font.family: root.clockFamily
            font.pixelSize: root.clockPx
            font.weight: 680
            font.letterSpacing: -1.5 * root.scaleFactor
            renderType: Text.QtRendering
            visible: false
        }

        ShaderEffectSource {
            id: timeMaskRaw
            sourceItem: timeTxt
            hideSource: true
            visible: false
            smooth: true
            sourceRect: Qt.rect(
                -timeItem.mp,
                -timeItem.mp,
                timeTxt.width + 2 * timeItem.mp,
                timeTxt.height + 2 * timeItem.mp
            )
        }

        MultiEffect {
            id: timeMaskFx
            width: timeMaskRaw.sourceRect.width
            height: timeMaskRaw.sourceRect.height
            source: timeMaskRaw
            blurEnabled: true
            blurMax: 48
            blur: timeTxt.morphBlur
            autoPaddingEnabled: false
            visible: false
        }

        ShaderEffectSource {
            id: timeMask
            sourceItem: timeMaskFx
            visible: false
            smooth: true
        }

        MultiEffect {
            id: timeHeightFx
            width: timeMaskFx.width
            height: timeMaskFx.height
            source: timeMask
            blurEnabled: true
            blurMax: 16
            blur: Math.max(0.12, Math.min(0.6, root.clockPx * 0.04 / 16))
            autoPaddingEnabled: false
            visible: false
        }

        ShaderEffectSource {
            id: timeHeight
            sourceItem: timeHeightFx
            visible: false
            smooth: true
        }

        // Soft shadow below digits
        MultiEffect {
            x: timeTxt.x - timeItem.mp
            y: timeTxt.y - timeItem.mp + 7 * root.scaleFactor
            width: timeMaskFx.width
            height: timeMaskFx.height
            source: timeMask
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            colorization: 1.0
            colorizationColor: "black"
            brightness: -1.0
            opacity: 0.24
        }

        // Real Liquid Glass Refraction (MacSDDM glasstext.frag.qsb)
        ShaderEffect {
            id: timeGlass
            visible: !!root.backdropItem
            x: timeTxt.x - timeItem.mp
            y: timeTxt.y - timeItem.mp
            width: timeMaskFx.width
            height: timeMaskFx.height

            fragmentShader: Qt.resolvedUrl("glasstext.frag.qsb")

            readonly property point fp: {
                if (root.coordRoot) {
                    root.coordRoot.height;
                    root.x; root.y;
                    timeItem.x; timeTxt.x; timeTxt.width;
                    return timeGlass.mapToItem(root.coordRoot, 0, 0);
                }
                return Qt.point(0, 0);
            }

            property variant src: glassTexture
            property variant mask: timeMask
            property variant hmap: timeHeight
            property vector2d itemSize: Qt.vector2d(width, height)
            property vector2d srcSize: root.coordRoot ? Qt.vector2d(root.coordRoot.width, root.coordRoot.height) : Qt.vector2d(1920, 1080)
            property vector2d srcOffset: Qt.vector2d(fp.x, fp.y)
            property real mode: 1.0
            property real intensity: root.glassIntensity
            property real refract: root.glassRefraction * root.scaleFactor
            property real bevel: 4.5
            property color tint: root.glassTint
            property vector2d lightDir: Qt.vector2d(-0.6, -0.8)
        }

        // Fallback crisp text if no backdrop item is bound
        Text {
            visible: !root.backdropItem
            anchors.fill: timeTxt
            text: timeTxt.text
            font: timeTxt.font
            color: "#ffffff"
        }
    }
}
