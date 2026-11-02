/*
   SPDX-FileCopyrightText: 2016 (c) Matthieu Gallien <matthieu_gallien@yahoo.fr>

   SPDX-License-Identifier: LGPL-3.0-or-later

   Right-side "Now Playing" panel (Spotify's now-playing view). Shows the
   current track's cover art, title/artist/album, and a toggle between the
   track's credits (metadata) and its lyrics.
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.ki18n
import org.kde.kirigami as Kirigami
import org.kde.elisa

Rectangle {
    id: nowPlayingPanel

    // The header bar manager is created only after ElisaApplication.initialize()
    // runs (in the main window's Component.onCompleted), which happens *after*
    // this panel is instantiated. Reading its fields while it is null would
    // throw and permanently break the binding, so route everything through this
    // guarded reference and re-evaluate once it becomes available.
    readonly property var headerBar: ElisaApplication.manageHeaderBar
    readonly property bool headerReady: headerBar !== null && headerBar !== undefined

    property url image: headerReady ? headerBar.image : ""
    property string title: headerReady && headerBar.title !== undefined && headerBar.title !== null ? String(headerBar.title) : ""
    property string artist: headerReady && headerBar.artist !== undefined && headerBar.artist !== null ? String(headerBar.artist) : ""
    property string album: headerReady && headerBar.album !== undefined && headerBar.album !== null ? String(headerBar.album) : ""

    readonly property url fileUrl: headerReady ? headerBar.fileUrl : ""
    readonly property int trackType: headerReady ? headerBar.trackType : 0
    readonly property var databaseId: headerReady ? headerBar.databaseId : 0

    readonly property bool nothingPlaying: title.length === 0 && image.toString().length === 0

    signal openArtist()
    signal openAlbum()
    signal openNowPlaying()

    color: Theme.spotifySurface

    function initializeModel() {
        if (!headerReady || !ElisaApplication.musicManager || trackType === undefined) {
            return;
        }
        if (fileUrl.toString().length === 0) {
            return;
        }
        if (databaseId !== 0) {
            metaDataModel.initializeByIdAndUrl(trackType, databaseId, fileUrl);
        } else {
            metaDataModel.initializeByUrl(trackType, fileUrl);
        }
    }

    onFileUrlChanged: initializeModel()
    onTrackTypeChanged: initializeModel()

    // The header bar (and music manager) are created after this panel is
    // instantiated, so populate the model once they come online.
    onHeaderReadyChanged: {
        if (headerReady) {
            initializeModel();
        }
    }

    Connections {
        target: ElisaApplication
        function onMusicManagerChanged() {
            nowPlayingPanel.initializeModel();
        }
    }

    TrackContextMetaDataModel {
        id: metaDataModel
        manager: ElisaApplication.musicManager
        onLyricsChanged: lyricsView.model.setLyric(lyrics)
    }

    TrackMetadataProxyModel {
        id: metadataProxyModel
        sourceModel: metaDataModel
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // ===== header =====
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: KI18n.i18nc("@title:header of the now playing panel", "Now Playing")
                level: 4
                font.bold: true
                color: Theme.spotifyTextPrimary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            FlatButtonWithToolTip {
                text: KI18n.i18nc("@action:button", "Close")
                icon.name: "window-close"
                icon.color: Theme.spotifyTextSecondary
                Kirigami.Theme.textColor: Theme.spotifyTextSecondary
                onClicked: persistentSettings.showNowPlayingPanel = false
            }
        }

        // ===== cover art =====
        Rectangle {
            id: coverContainer
            Layout.fillWidth: true
            Layout.preferredHeight: contentLayout.width
            Layout.maximumHeight: Kirigami.Units.gridUnit * 18
            radius: Theme.spotifyRadius
            color: Theme.spotifySurfaceElevated
            clip: true

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.huge
                height: Kirigami.Units.iconSizes.huge
                source: Theme.defaultAlbumImage
                color: Theme.spotifyTextSecondary
                visible: cover.status !== Image.Ready
            }

            Image {
                id: cover
                anchors.fill: parent
                source: (nowPlayingPanel.image === "" || nowPlayingPanel.image === Qt.url("") || nowPlayingPanel.image === undefined || nowPlayingPanel.image === null) ? "" : nowPlayingPanel.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: width
                sourceSize.height: height
                visible: status === Image.Ready
            }
        }

        // ===== track info =====
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            visible: !nowPlayingPanel.nothingPlaying

            LabelWithToolTip {
                text: nowPlayingPanel.title
                level: 4
                font.bold: true
                color: Theme.spotifyTextPrimary
                Layout.fillWidth: true
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nowPlayingPanel.openNowPlaying()
                }
            }

            LabelWithToolTip {
                text: nowPlayingPanel.artist
                visible: text.length > 0
                level: 5
                font: Kirigami.Theme.smallFont
                color: Theme.spotifyTextSecondary
                Layout.fillWidth: true
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nowPlayingPanel.openArtist()
                }
            }

            LabelWithToolTip {
                text: nowPlayingPanel.album
                visible: text.length > 0
                level: 5
                font: Kirigami.Theme.smallFont
                color: Theme.spotifyTextSecondary
                Layout.fillWidth: true
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nowPlayingPanel.openAlbum()
                }
            }
        }

        // ===== toggle: credits / lyrics =====
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: !nowPlayingPanel.nothingPlaying

            ButtonGroup {
                id: viewButtons
                onCheckedButtonChanged: {
                    persistentSettings.nowPlayingPreferLyric = viewButtons.checkedButton === lyricButton
                }
            }

            FlatButtonWithToolTip {
                id: metadataButton
                ButtonGroup.group: viewButtons

                checkable: true
                checked: !persistentSettings.nowPlayingPreferLyric
                text: KI18n.i18nc("@option:radio One of the now playing panel views", "Credits")
                icon.name: "documentinfo"
                display: AbstractButton.TextBesideIcon
                icon.color: checked ? Theme.spotifyTextPrimary : Theme.spotifyTextSecondary
                Kirigami.Theme.textColor: checked ? Theme.spotifyTextPrimary : Theme.spotifyTextSecondary
                Layout.fillWidth: true
            }

            FlatButtonWithToolTip {
                id: lyricButton
                ButtonGroup.group: viewButtons

                checkable: true
                checked: persistentSettings.nowPlayingPreferLyric
                text: KI18n.i18nc("@option:radio One of the now playing panel views", "Lyrics")
                icon.name: "view-media-lyrics"
                display: AbstractButton.TextBesideIcon
                icon.color: checked ? Theme.spotifyTextPrimary : Theme.spotifyTextSecondary
                Kirigami.Theme.textColor: checked ? Theme.spotifyTextPrimary : Theme.spotifyTextSecondary
                Layout.fillWidth: true
            }
        }

        // ===== content: credits or lyrics =====
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !nowPlayingPanel.nothingPlaying
            currentIndex: persistentSettings.nowPlayingPreferLyric ? 1 : 0

            // credits (track metadata)
            ScrollView {
                id: allMetaDataScroll

                contentWidth: availableWidth
                contentHeight: allMetaDataLoader.height

                // HACK: workaround for https://bugreports.qt.io/browse/QTBUG-83890
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Loader {
                    id: allMetaDataLoader

                    width: allMetaDataScroll.availableWidth

                    sourceComponent: Kirigami.FormLayout {
                        width: allMetaDataScroll.availableWidth

                        Repeater {
                            model: metadataProxyModel

                            delegate: Item {
                                id: metadataDelegate

                                required property int index
                                required property var display
                                required property string name
                                required property int type
                                required property bool hasData

                                Kirigami.FormData.label: "<b>" + name + ":</b>"
                                implicitWidth: childrenRect.width
                                implicitHeight: childrenRect.height
                                visible: hasData

                                MediaTrackMetadataDelegate {
                                    maximumWidth: allMetaDataScroll.availableWidth - Kirigami.Units.largeSpacing * 2
                                    index: metadataDelegate.index
                                    name: metadataDelegate.name
                                    display: metadataDelegate.display
                                    type: metadataDelegate.type
                                    readOnly: true
                                    url: nowPlayingPanel.fileUrl
                                    hasData: metadataDelegate.hasData
                                }
                            }
                        }
                    }

                    // unload and recreate the FormLayout on model reset to avoid warnings
                    Timer {
                        id: resetTimer
                        interval: 0
                        onTriggered: allMetaDataLoader.active = true
                    }
                    Connections {
                        target: metaDataModel
                        function onModelAboutToBeReset() {
                            allMetaDataLoader.active = false
                        }
                        function onModelReset() {
                            resetTimer.restart()
                        }
                    }
                }
            }

            // lyrics
            LyricsView {
                id: lyricsView
                alignLeft: true
            }
        }

        // ===== nothing playing =====
        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: nowPlayingPanel.nothingPlaying
            text: KI18n.i18nc("@info:placeholder", "Nothing playing")
            icon.name: "view-media-track"
        }
    }
}
