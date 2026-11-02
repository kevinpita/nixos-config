import QtQuick
import qs.Common

// Full clip track: the kept range between the two handles is colored, the cut parts are gray.
Item {
    id: root

    property int durationMs: 1
    property int startMs: 0
    property int endMs: 0
    property int playheadMs: -1
    readonly property real handleWidth: 14
    readonly property real trackWidth: width - handleWidth * 2

    signal trimMoved(int startMs, int endMs)
    signal trimFinished
    signal seekRequested(int ms)

    implicitHeight: 44

    function xFor(ms) {
        return handleWidth + trackWidth * ms / Math.max(1, durationMs);
    }

    function msAt(item, x) {
        const local = item.mapToItem(root, x, 0).x;
        return Math.round(Math.max(0, Math.min(1, (local - handleWidth) / trackWidth)) * durationMs);
    }

    function seekTo(item, x) {
        seekRequested(Math.max(startMs, Math.min(endMs, msAt(item, x))));
    }

    Rectangle {
        x: root.handleWidth
        width: root.trackWidth
        height: 28
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.cornerRadius
        color: Theme.surfaceVariant
    }

    Rectangle {
        x: root.xFor(root.startMs)
        width: root.xFor(root.endMs) - x
        height: 28
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.primary
        opacity: 0.55
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.seekTo(this, mouse.x)
        onPositionChanged: mouse => root.seekTo(this, mouse.x)
    }

    Rectangle {
        x: root.xFor(root.playheadMs) - width / 2
        width: 2
        height: parent.height
        visible: root.playheadMs >= 0
        color: Theme.surfaceText
    }

    Rectangle {
        x: root.xFor(root.startMs) - width
        width: root.handleWidth
        height: parent.height
        radius: 4
        color: Theme.primary

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.SizeHorCursor
            property real grabOffset: 0
            onPressed: mouse => grabOffset = mapToItem(root, mouse.x, 0).x - root.xFor(root.startMs)
            onPositionChanged: mouse => {
                if (pressed)
                    root.trimMoved(root.msAt(this, mouse.x - grabOffset), root.endMs);
            }
            onReleased: root.trimFinished()
            onCanceled: root.trimFinished()
        }
    }

    Rectangle {
        x: root.xFor(root.endMs)
        width: root.handleWidth
        height: parent.height
        radius: 4
        color: Theme.primary

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.SizeHorCursor
            property real grabOffset: 0
            onPressed: mouse => grabOffset = mapToItem(root, mouse.x, 0).x - root.xFor(root.endMs)
            onPositionChanged: mouse => {
                if (pressed)
                    root.trimMoved(root.startMs, root.msAt(this, mouse.x - grabOffset));
            }
            onReleased: root.trimFinished()
            onCanceled: root.trimFinished()
        }
    }
}
