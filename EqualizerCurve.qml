import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: equalizer

    readonly property var bandNames: ["Bass", "Mid", "Treble"]
    readonly property int minimum: -10
    readonly property int maximum: 10
    property var headsetValues: [0, 0, 0]
    property var values: headsetValues.slice()
    property int draggedBand: -1

    signal changeRequested(var bands)

    width: parent ? parent.width : 0
    topPadding: Theme.spacingS
    bottomPadding: Theme.spacingXS
    spacing: Theme.spacingS

    onHeadsetValuesChanged: {
        if (draggedBand < 0 && !sendDelay.running)
            values = headsetValues.slice();
    }
    onValuesChanged: curve.requestPaint()

    function setBand(band, value) {
        const clamped = Math.max(minimum, Math.min(maximum, Math.round(value)));
        if (values[band] === clamped)
            return;
        const updated = values.slice();
        updated[band] = clamped;
        values = updated;
        sendDelay.restart();
    }

    function bandX(band) {
        return curve.width * (band * 2 + 1) / 6;
    }

    function valueY(value) {
        const inset = handleRadius + 2;
        return inset + (maximum - value) / (maximum - minimum) * (curve.height - inset * 2);
    }

    function yValue(y) {
        const inset = handleRadius + 2;
        return maximum - (y - inset) / (curve.height - inset * 2) * (maximum - minimum);
    }

    readonly property real handleRadius: 9

    Timer {
        id: sendDelay

        interval: 300
        onTriggered: equalizer.changeRequested(equalizer.values.slice())
    }

    Item {
        width: parent.width
        height: resetLink.implicitHeight

        StyledText {
            anchors.left: parent.left
            text: "Equalizer"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
        }

        StyledText {
            id: resetLink

            anchors.right: parent.right
            text: "Reset"
            color: resetArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
            opacity: equalizer.values.every(value => value === 0) ? 0.4 : 1

            MouseArea {
                id: resetArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    equalizer.values = [0, 0, 0];
                    sendDelay.restart();
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 40

        Repeater {
            model: equalizer.bandNames

            Column {
                required property string modelData
                required property int index

                x: equalizer.bandX(index) - width / 2
                width: 64

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: parent.modelData
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }

                StyledText {
                    readonly property int value: equalizer.values[parent.index]

                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: value > 0 ? "+" + value : value
                    color: equalizer.draggedBand === parent.index ? Theme.primary : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                }
            }
        }
    }

    Canvas {
        id: curve

        width: parent.width
        height: 120

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            context.reset();

            const zeroY = Math.round(equalizer.valueY(0)) + 0.5;
            context.strokeStyle = Theme.outlineVariant;
            context.lineWidth = 1;
            context.beginPath();
            context.moveTo(0, zeroY);
            context.lineTo(width, zeroY);
            context.stroke();

            const points = [0, 1, 2].map(band => ({ x: equalizer.bandX(band), y: equalizer.valueY(equalizer.values[band]) }));
            context.strokeStyle = Theme.primary;
            context.lineWidth = 2.5;
            context.lineCap = "round";
            context.beginPath();
            context.moveTo(0, points[0].y);
            context.lineTo(points[0].x, points[0].y);
            for (let band = 1; band < points.length; band++) {
                const from = points[band - 1];
                const to = points[band];
                const middleX = (from.x + to.x) / 2;
                context.bezierCurveTo(middleX, from.y, middleX, to.y, to.x, to.y);
            }
            context.lineTo(width, points[2].y);
            context.stroke();
        }

        Repeater {
            model: 3

            Rectangle {
                required property int index
                readonly property bool active: equalizer.draggedBand === index

                x: equalizer.bandX(index) - width / 2
                y: equalizer.valueY(equalizer.values[index]) - height / 2
                width: (active ? equalizer.handleRadius + 2 : equalizer.handleRadius) * 2
                height: width
                radius: width / 2
                color: Theme.primary
                border.width: 3
                border.color: Theme.surfaceContainerHigh

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: equalizer.draggedBand >= 0 ? Qt.ClosedHandCursor : Qt.SizeVerCursor
            preventStealing: true

            function bandAt(x) {
                return Math.max(0, Math.min(2, Math.floor(x / (width / 3))));
            }

            onPressed: mouse => {
                equalizer.draggedBand = bandAt(mouse.x);
                equalizer.setBand(equalizer.draggedBand, equalizer.yValue(mouse.y));
            }
            onPositionChanged: mouse => {
                if (equalizer.draggedBand >= 0)
                    equalizer.setBand(equalizer.draggedBand, equalizer.yValue(mouse.y));
            }
            onReleased: equalizer.draggedBand = -1
            onCanceled: equalizer.draggedBand = -1
            onWheel: wheel => {
                const band = bandAt(wheel.x);
                equalizer.setBand(band, equalizer.values[band] + (wheel.angleDelta.y > 0 ? 1 : -1));
            }
        }
    }
}
