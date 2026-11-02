import QtMultimedia
import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets

DFloatingWindow {
    id: root

    required property var daemon
    property string defaultName: ""
    readonly property string fileName: nameInput.text
    readonly property var quality: daemon.qualities[daemon.qualityIndex]
    readonly property real labelWidth: 150

    title: "Screen recording"
    minimumSize: Qt.size(720, dialog.implicitHeight)
    maximumSize: Qt.size(720, dialog.implicitHeight)
    visible: false

    onClosed: daemon.finish()
    onVisibleChanged: {
        if (!visible) {
            encodeDelay.stop();
            player.stop();
        }
    }

    function seconds(ms) {
        return (ms / 1000).toFixed(1) + " s";
    }

    function open() {
        defaultName = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        nameInput.text = defaultName;
        qualitySlider.value = daemon.qualityIndex;
        frameRateSlider.value = daemon.frameRateIndex;
        visible = true;
        Qt.callLater(() => {
            nameInput.forceActiveFocus();
            nameInput.selectAll();
        });
    }

    function save() {
        encodeDelay.stop();
        daemon.save(nameInput.text);
    }

    Timer {
        id: encodeDelay

        interval: 300
        onTriggered: {
            if (root.visible)
                root.daemon.encode();
        }
    }

    DDialog {
        id: dialog

        anchors.fill: parent
        enabled: !root.daemon.saving
        windowControls: windowControls
        title: root.title
        acceptEnabled: root.daemon.previewFile !== "" || root.daemon.encoding
        onAccepted: root.save()
        onRejected: root.daemon.finish()

        Rectangle {
            width: parent.width
            height: width * 9 / 16
            radius: Theme.cornerRadius
            color: "black"
            clip: true

            Video {
                id: player

                anchors.fill: parent
                source: root.daemon.previewFile ? "file://" + root.daemon.previewFile : ""
                fillMode: VideoOutput.PreserveAspectFit
                loops: MediaPlayer.Infinite
                muted: true
                onSourceChanged: {
                    if (source.toString())
                        play();
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.daemon.encoding && !root.daemon.previewFile
                text: "Encoding..."
                color: "white"
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Theme.spacingS
                visible: root.daemon.previewFile !== "" && player.playbackState !== MediaPlayer.PlayingState
                text: "Paused - click to play"
                color: "white"
            }
        }

        TrimTimeline {
            width: parent.width
            durationMs: root.daemon.sourceMs
            startMs: root.daemon.trimStartMs
            endMs: root.daemon.trimEndMs
            playheadMs: root.daemon.previewFile ? root.daemon.previewStartMs + player.position : -1
            onTrimMoved: (startMs, endMs) => root.daemon.setTrim(startMs, endMs)
            onTrimFinished: {
                encodeDelay.stop();
                root.daemon.encode();
            }
            onSeekRequested: ms => {
                player.pause();
                player.seek(ms - root.daemon.previewStartMs);
            }
        }

        Row {
            width: parent.width

            StyledText {
                width: root.labelWidth
                anchors.verticalCenter: parent.verticalCenter
                text: root.quality.label + (root.quality.height > 0 ? " (" + root.quality.height + "p)" : "")
                color: Theme.surfaceText
            }

            DSlider {
                id: qualitySlider

                width: parent.width - root.labelWidth
                minimum: 0
                maximum: root.daemon.qualities.length - 1
                step: 1
                showValue: false
                showStops: true
                startIcon: "compress"
                endIcon: "high_quality"
                onSliderValueChanged: newValue => {
                    if (!root.visible || root.daemon.qualityIndex === newValue)
                        return;
                    root.daemon.qualityIndex = newValue;
                    encodeDelay.restart();
                }
            }
        }

        Row {
            width: parent.width

            StyledText {
                width: root.labelWidth
                anchors.verticalCenter: parent.verticalCenter
                text: root.daemon.frameRates[root.daemon.frameRateIndex] + " fps"
                color: Theme.surfaceText
            }

            DSlider {
                id: frameRateSlider

                width: parent.width - root.labelWidth
                minimum: 0
                maximum: Math.max(1, root.daemon.frameRates.length - 1)
                enabled: root.daemon.frameRates.length > 1
                step: 1
                showValue: false
                showStops: true
                startIcon: "slow_motion_video"
                endIcon: "speed"
                onSliderValueChanged: newValue => {
                    if (!root.visible || root.daemon.frameRateIndex === newValue)
                        return;
                    root.daemon.frameRateIndex = newValue;
                    encodeDelay.restart();
                }
            }
        }

        StyledText {
            width: parent.width
            text: "Clip " + root.seconds(root.daemon.trimStartMs) + " -> " + root.seconds(root.daemon.trimEndMs) + " (" + root.seconds(root.daemon.trimEndMs - root.daemon.trimStartMs) + ") - " + (root.daemon.encoding ? "encoding..." : root.daemon.formatBytes(root.daemon.previewBytes))
            color: Theme.surfaceVariantText
        }

        DTextField {
            id: nameInput

            width: parent.width
            outlined: true
            controlHeight: Theme.fieldHeightLarge
            labelText: "File name"
            leftIconName: "edit"
            isError: root.daemon.saveError !== ""
            supportingText: root.daemon.saveError || ("Saved to " + root.daemon.videosDir)
            onAccepted: root.save()
        }

        actions: [
            DButton {
                maximumWidth: dialog.actionWidth
                text: "Discard"
                backgroundColor: "transparent"
                textColor: Theme.primary
                onClicked: root.daemon.finish()
            },
            DButton {
                maximumWidth: dialog.actionWidth
                text: "Save"
                busy: root.daemon.saveRequested || root.daemon.saving
                onClicked: root.save()
            }
        ]
    }

    FloatingWindowControls {
        id: windowControls

        targetWindow: root
    }
}
