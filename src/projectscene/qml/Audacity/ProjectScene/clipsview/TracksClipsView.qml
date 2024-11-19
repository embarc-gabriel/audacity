import QtQuick
import QtQuick.Controls

import Muse.Ui
import Muse.UiComponents

import Audacity.ProjectScene
import Audacity.Project

Rectangle {

    id: root

    property bool clipHovered: false
    property var hoveredClipKey: null
    color: ui.theme.backgroundPrimaryColor

    clip:true

    TracksListClipsModel {
        id: tracksModel

        onTotalTracksHeightChanged: {
            timeline.context.onResizeFrameContentHeight(tracksModel.totalTracksHeight)
        }
    }

    ProjectPropertiesModel {
        id: project

        onCaptureThumbnail: function captureThumbnail() {
            // hide playCursor for the time grabbing image
            playCursor.visible = false
            content.grabToImage(function(result) {
                playCursor.visible = true
                result.saveToFile(project.thumbnailUrl)
            })
        }
    }

    //! NOTE Sync with TracksPanel
    TracksViewStateModel {
        id: tracksViewState
        onTracksVericalYChanged: {
            tracksClipsView.contentY = tracksViewState.tracksVericalY
        }
    }

    PlayCursorController {
        id: playCursorController
        context: timeline.context
    }

    PlayPositionActionController {
        id: playPositionActionController
        context: timeline.context
    }

    SelectionViewController {
        id: selectionController
        context: timeline.context
    }

    Component.onCompleted: {
        //! NOTE Models depend on geometry, so let's create a page first and then initialize the models
        Qt.callLater(root.init)
    }

    function init() {
        timeline.init()
        playCursorController.init()
        playPositionActionController.init()
        tracksViewState.init()
        project.init()
        //! NOTE Loading tracks, or rather clips, is the most havy operation.
        // Let's make sure that everything is loaded and initialized before this,
        // to avoid double loading at the beginning, when some parameters are initialized.
        Qt.callLater(tracksModel.load)
    }

    Rectangle {
        id: timelineIndent
        anchors.top: parent.top
        anchors.left: parent.left
        height: timeline.height
        width: content.anchors.leftMargin
        color: timeline.color

        SeparatorLine {
            id: topBorder
            width: parent.width
            anchors.bottom: parent.bottom
            color: ui.theme.strokeColor
        }
    }

    Rectangle {
        id: canvasIndent
        anchors.top: timelineIndent.bottom
        anchors.bottom: parent.bottom
        height: timeline.height
        width: content.anchors.leftMargin
        color: ui.theme.backgroundTertiaryColor
    }

    Timeline {
        id: timeline

        anchors.top: parent.top
        anchors.left: timelineIndent.right
        anchors.right: parent.right

        clip: true

        height: 40

        function updateCursorPosition(x) {
            lineCursor.x = x
            timeline.context.updateMousePositionTime(x)
        }

        MouseArea {
            id: timelineMouseArea
            anchors.fill: parent
            hoverEnabled: true

            onPositionChanged: function(e) {
                timeline.updateCursorPosition(e.x)
            }

            onClicked: function (e) {
                if (!timeline.isMajorSection(e.y)) {
                    playCursorController.seekToX(e.x, true /* triggerPlay */)
                }
            }
        }

        Rectangle {
            id: lineCursor

            y: parent.top
            height: timeline.height
            width: 1

            color: ui.theme.fontPrimaryColor
        }

        Rectangle {
            id: timelineSelRect

            x: timeline.context.clipSelected ? timeline.context.selectedClipStartPosition : timeline.context.selectionStartPosition
            width: timeline.context.clipSelected ? timeline.context.selectedClipEndPosition - x : timeline.context.selectionEndPosition - x

            anchors.top: parent.top
            anchors.bottom: parent.bottom

            color: "#ABE7FF"
            opacity: 0.3
        }
    }

    Rectangle {
        id: content
        objectName: "clipsView"
        anchors.leftMargin: 12
        anchors.top: timeline.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // anchors.leftMargin: 130
        // anchors.rightMargin: 130

        GridLines {
            timelineRuler: timeline.ruler
            anchors.fill: parent
        }

        MouseArea {
            id: mainMouseArea
            anchors.fill: parent

            hoverEnabled: true

            onWheel: function(wheelEvent) {
                timeline.onWheel(wheelEvent.x, wheelEvent.pixelDelta, wheelEvent.angleDelta)
            }

            onPressed: function(e) {
                if (!(e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                    playCursorController.seekToX(e.x)
                }
                selectionController.onPressed(e.x, e.y)
                selectionController.resetSelectedClip()
                clipsSelection.visible = true
            }
            onPositionChanged: function(e) {
                selectionController.onPositionChanged(e.x, e.y)

                timeline.updateCursorPosition(e.x)

                if (root.clipHovered) {
                    root.clipHovered = false
                }
            }
            onReleased: e => {
                if (selectionController.isLeftSelection(e.x)) {
                    playCursorController.seekToX(e.x)
                }
                selectionController.onReleased(e.x, e.y)
                if (e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) {
                    playCursorController.seekToX(timeline.context.selectionStartPosition)
                }
                clipsSelection.visible = false
            }

            onClicked: e => {
                if (!root.clipHovered) {
                    selectionController.resetSelectedClip()
                }
            }

            onDoubleClicked: e => {
                if (root.clipHovered) {
                    selectionController.selectClipAudioData(root.hoveredClipKey)
                    playCursorController.seekToX(timeline.context.selectedClipStartPosition)
                } else {
                    selectionController.selectTrackAudioData(e.y)
                    playCursorController.seekToX(timeline.context.selectionStartPosition)
                }
                clipsSelection.visible = false
            }
        }

        StyledViewScrollAndZoomArea {
            id: tracksClipsViewArea

            anchors.fill: parent

            view: tracksClipsView

            horizontalScrollbarSize: timeline.context.horizontalScrollbarSize
            startHorizontalScrollPosition: timeline.context.startHorizontalScrollPosition

            verticalScrollbarSize: timeline.context.verticalScrollbarSize
            startVerticalScrollPosition: timeline.context.startVerticalScrollPosition

            StyledListView {
                id: tracksClipsView

                anchors.fill: parent
                clip: true

                property real visibleContentHeight: tracksModel.totalTracksHeight - tracksClipsView.contentY

                ScrollBar.horizontal: null
                ScrollBar.vertical: null

                onContentYChanged: {
                    tracksViewState.changeTracksVericalY(tracksClipsView.contentY)
                    timeline.context.startVerticalScrollPosition = tracksClipsView.contentY
                }

                onHeightChanged: {
                    timeline.context.onResizeFrameHeight(tracksClipsView.height)
                }

                Connections {
                    target: timeline.context

                    function onViewContentYChangeRequested(contentY) {
                        let canMove = tracksModel.totalTracksHeight > tracksClipsView.height
                        if (!canMove) {
                            return
                        }

                        if (tracksClipsView.contentY + contentY + tracksClipsView.height > tracksModel.totalTracksHeight) {
                            tracksClipsView.contentY += tracksModel.totalTracksHeight - (tracksClipsView.contentY + tracksClipsView.height)
                        } else if (tracksClipsView.contentY + contentY < 0) {
                            tracksClipsView.contentY = 0
                        } else {
                            tracksClipsView.contentY += contentY
                        }
                    }
                }

                interactive: false

                model: tracksModel

                delegate: TrackClipsItem {
                    width: tracksClipsView.width
                    context: timeline.context
                    canvas: content
                    trackId: model.trackId
                    isDataSelected: model.isDataSelected
                    isTrackSelected: model.isTrackSelected

                    onTrackItemMousePositionChanged: function(xWithinTrack, yWithinTrack, clipKey) {
                        timeline.updateCursorPosition(xWithinTrack)

                        if (!root.clipHovered) {
                            root.clipHovered = true
                        }
                        root.hoveredClipKey = clipKey
                    }

                    onClipSelectedRequested: {
                        selectionController.resetDataSelection()
                        clipsSelection.visible = false
                    }

                    onSelectionDraged: function(x1, x2, completed) {
                        selectionController.onSelectionDraged(x1, x2, completed)
                    }

                    onSeekToX: function(x) {
                        playCursorController.seekToX(x)
                    }
                }

                HoverHandler {
                    property bool isNeedSelectionCursor: !selectionController.selectionActive
                    cursorShape: isNeedSelectionCursor ? Qt.IBeamCursor : Qt.ArrowCursor
                }
            }

            onPinchToZoom: function(scale, pos) {
                timeline.context.pinchToZoom(scale, pos)
            }

            onScrollHorizontal: function(newPos) {
                timeline.context.scrollHorizontal(newPos)
            }

            onScrollVertical: function(newPos) {
                timeline.context.scrollVertical(newPos)
            }
        }

        Rectangle {
            id: clipsSelection

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "#ABE7FF"
            opacity: 0.05
            visible: false

            x: Math.max(timeline.context.selectionStartPosition, 0.0)
            width: timeline.context.selectionEndPosition - x
        }

        PlayCursor {
            id: playCursor
            anchors.top: tracksClipsViewArea.top
            anchors.bottom: parent.bottom
            x: playCursorController.positionX
            z: 2
            timelinePressed: timelineMouseArea.pressed

            onSetPlaybackPosition: function(ix) {
                playCursorController.seekToX(ix)
            }

            onPlayCursorMousePositionChanged: function(ix) {
                timeline.updateCursorPosition(ix)
            }
        }

        VerticalRulersPanel {
            id: verticalRulers

            height: parent.height - timeline.height
            anchors.right: tracksClipsViewArea.right
            anchors.bottom: tracksClipsViewArea.bottom

            visible: tracksModel.isVerticalRulersVisible
        }
    }
}