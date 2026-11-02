/*
   SPDX-License-Identifier: LGPL-3.0-or-later

   Full-screen "Now Playing" overlay (Spotify's expanded player / Elisa's
   former party mode). Shows the cover, track metadata, and either the
   playlist or the lyrics over a blurred cover background.
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Effects as FX
import org.kde.ki18n
import org.kde.kirigami as Kirigami
import org.kde.elisa

FocusScope {
    id: nowPlaying

    property string title
    property string artist
    property string albumArtist
    property string album
    property string image
    property int trackRating
    property int albumID
    property bool ratingVisible

    property bool lyricsVisible: false

    signal closeRequested()
    signal openArtist()
    signal openAlbum()
    signal openNowPlaying()

    readonly property int trackType: ElisaApplication.manageHeaderBar.trackType
    readonly property int databaseId: ElisaApplication.manageHeaderBar.databaseId
    readonly property url fileUrl: ElisaApplication.manageHeaderBar.fileUrl

    Rectangle {
        anchors.fill: parent
        color: Theme.spotifyBase
    }

    TrackContextMetaDataModel {
        id: metaDataModel
        onLyricsChanged: lyricsView.model.setLyric(lyrics)
        manager: ElisaApplication.musicManager
    }

    onFileUrlChanged: {
        if (ElisaApplication.musicManager && trackType !== undefined && fileUrl !== undefined && fileUrl.toString().length !== 0) {
            if (databaseId !== 0) {
                metaDataModel.initializeByIdAndUrl(trackType, databaseId, fileUrl);
            } else {
                metaDataModel.initializeByUrl(trackType, fileUrl);
            }
        }
    }

    onTrackTypeChanged: {
        if (ElisaApplication.musicManager && trackType !== undefined && fileUrl !== undefined && fileUrl.toString().length !== 0) {
            if (databaseId !== 0) {
                metaDataModel.initializeByIdAndUrl(trackType, databaseId, fileUrl);
            } else {
                metaDataModel.initializeByUrl(trackType, fileUrl);
            }
        }
    }

    Connections {
        target: ElisaApplication

        function onMusicManagerChanged() {
            if (ElisaApplication.musicManager && nowPlaying.trackType !== undefined && nowPlaying.databaseId !== 0) {
                metaDataModel.initializeByIdAndUrl(nowPlaying.trackType, nowPlaying.databaseId, nowPlaying.fileUrl);
            }
        }
    }

    onImageChanged: loadImage();

    function loadImage() {
        if (background.pendingImageIncubator) {
            background.pendingImageIncubator.forceCompletion();
        }
        if (coverImage.pendingImageIncubator) {
            coverImage.pendingImageIncubator.forceCompletion();
        }

        background.doesSkipAnimation = background.currentItem == undefined;

        const fallbackBackground = Qt.resolvedUrl(Theme.defaultBackgroundImage);
        background.pendingImageIncubator = backgroundComponent.incubateObject(background, {
            "source": (image === "" || image === Qt.url("") || image === undefined || image === null) ? fallbackBackground : image,
            "opacity": 0,
        });
        coverImage.pendingImageIncubator = coverComponent.incubateObject(coverImage, {
            "source": (image === "" || image === Qt.url("") || image === undefined || image === null) ? Theme.defaultAlbumImage : image,
            "opacity": 0,
        });
    }

    function replaceWhenLoaded(item) {
        background.replace(item, {}, StackView.Transition);
        background.pendingImageIncubator = undefined;
    }

    function replaceCoverWhenLoaded(item) {
        coverImage.replace(item, {}, StackView.Transition);
        coverImage.pendingImageIncubator = undefined;
    }

    StackView {
        id: background

        anchors.fill: parent

        property var pendingImageIncubator
        property bool doesSkipAnimation: true

        replaceEnter: Transition {
            OpacityAnimator {
                id: bgReplaceEnter
                from: 0
                to: 1
                duration: background.doesSkipAnimation ? 1 : Kirigami.Units.longDuration
            }
        }
        replaceExit: Transition {
            PauseAnimation {
                duration: bgReplaceEnter.duration
            }
        }

        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: FX.MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 2
            brightness: -0.35
            saturation: -0.3
        }
    }

    Component {
        id: backgroundComponent

        Image {
            sourceSize.width: Screen.width
            fillMode: Image.PreserveAspectCrop

            Rectangle {
                anchors.fill: parent
                color: Theme.spotifyBase
                z: -1
            }

            Component.onCompleted: {
                if (status === Image.Loading) {
                    statusChanged.connect(() => { if (status === Image.Ready || status === Image.Error) { nowPlaying.replaceWhenLoaded(this) } });
                } else {
                    nowPlaying.replaceWhenLoaded(this);
                }
            }

            // darken so foreground text stays readable
            Rectangle {
                anchors.fill: parent
                color: Theme.spotifyBase
                opacity: 0.6
            }
        }
    }

    Component {
        id: coverComponent

        Image {
            fillMode: Image.PreserveAspectFit
            asynchronous: true

            Component.onCompleted: {
                if (status === Image.Loading) {
                    statusChanged.connect(() => { if (status === Image.Ready || status === Image.Error) { nowPlaying.replaceCoverWhenLoaded(this) } });
                } else {
                    nowPlaying.replaceCoverWhenLoaded(this);
                }
            }
        }
    }

    // ===== top bar =====
    RowLayout {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.largeSpacing

        z: 2

        FlatButtonWithToolTip {
            text: KI18n.i18nc("@action:button", "Close")
            icon.name: "window-close"
            icon.color: Theme.spotifyTextPrimary
            Kirigami.Theme.textColor: Theme.spotifyTextPrimary
            onClicked: nowPlaying.closeRequested()
        }

        Item { Layout.fillWidth: true }

        FlatButtonWithToolTip {
            id: playlistToggleButton
            autoExclusive: true
            text: KI18n.i18nc("@action:inmenu", "Playlist")
            icon.name: "view-media-playlist"
            display: AbstractButton.TextBesideIcon
            icon.color: Theme.spotifyTextPrimary
            Kirigami.Theme.textColor: Theme.spotifyTextPrimary
            checkable: true
            checked: !nowPlaying.lyricsVisible
            onCheckedChanged: if (checked) nowPlaying.lyricsVisible = false
        }

        FlatButtonWithToolTip {
            id: lyricsToggleButton
            autoExclusive: true
            text: KI18n.i18nc("@action:button", "Lyrics")
            icon.name: "view-media-lyrics"
            display: AbstractButton.TextBesideIcon
            icon.color: Theme.spotifyTextPrimary
            Kirigami.Theme.textColor: Theme.spotifyTextPrimary
            checkable: true
            checked: nowPlaying.lyricsVisible
            onCheckedChanged: if (checked) nowPlaying.lyricsVisible = true
        }

        FlatButtonWithToolTip {
            readonly property bool isFullScreen: mainWindow.visibility == Window.FullScreen
            text: isFullScreen
                ? KI18n.i18nc("@action:button", "Exit Full Screen")
                : KI18n.i18nc("@action:button", "Enter Full Screen")
            icon.name: "view-restore"
            display: AbstractButton.TextBesideIcon
            icon.color: Theme.spotifyTextPrimary
            Kirigami.Theme.textColor: Theme.spotifyTextPrimary
            onClicked: isFullScreen ? mainWindow.restorePreviousStateBeforeFullScreen() : mainWindow.goFullScreen()
        }
    }

    // ===== content =====
    GridLayout {
        id: contentZone

        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.largeSpacing * 2

        columns: portrait ? 1 : 2
        columnSpacing: Kirigami.Units.largeSpacing * 4
        rowSpacing: Kirigami.Units.largeSpacing

        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.fillHeight: true

        readonly property bool portrait: (height / width) > 0.9

        StackView {
            id: coverImage

            property var pendingImageIncubator

            readonly property double imageSize: Math.min(contentZone.height * (contentZone.portrait ? 0.5 : 0.8), contentZone.width / 2.5)

            Layout.alignment: Qt.AlignCenter
            Layout.preferredHeight: imageSize
            Layout.preferredWidth: imageSize

            replaceEnter: Transition {
                OpacityAnimator { from: 0; to: 1; duration: bgReplaceEnter.duration }
            }
            replaceExit: Transition {
                PauseAnimation { duration: bgReplaceEnter.duration }
            }
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                id: mainLabel
                text: nowPlaying.title
                level: 1
                font.bold: true
                color: Theme.spotifyTextPrimary
                horizontalAlignment: contentZone.portrait ? Text.AlignHCenter : Text.AlignLeft
                Layout.fillWidth: true
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        nowPlaying.openNowPlaying()
                        nowPlaying.closeRequested()
                    }
                }
            }

            Kirigami.Heading {
                id: authorLabel
                text: nowPlaying.artist
                visible: nowPlaying.artist.length > 0
                level: 3
                color: Theme.spotifyTextSecondary
                horizontalAlignment: contentZone.portrait ? Text.AlignHCenter : Text.AlignLeft
                Layout.fillWidth: true
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        nowPlaying.openArtist()
                        nowPlaying.closeRequested()
                    }
                }
            }

            Kirigami.Heading {
                id: albumLabel
                text: nowPlaying.album
                visible: nowPlaying.album.length > 0
                level: 3
                color: Theme.spotifyTextSecondary
                horizontalAlignment: contentZone.portrait ? Text.AlignHCenter : Text.AlignLeft
                Layout.fillWidth: true
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        nowPlaying.openAlbum()
                        nowPlaying.closeRequested()
                    }
                }
            }

            Loader {
                id: playLoader
                active: !nowPlaying.lyricsVisible
                visible: active

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                Layout.topMargin: Kirigami.Units.largeSpacing

                sourceComponent: SimplePlayListView {
                    model: ElisaApplication.mediaPlayListProxyModel
                }
            }

            LyricsView {
                id: lyricsView
                visible: nowPlaying.lyricsVisible

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                Layout.topMargin: Kirigami.Units.largeSpacing

                fadeInOut: true

                pointSize: {
                    if (lyricsView.width < 300 || lyricsView.height < 220) {
                        return Kirigami.Theme.defaultFont.pointSize;
                    } else {
                        return Kirigami.Theme.defaultFont.pointSize * 1.5;
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        loadImage();

        if (ElisaApplication.musicManager && trackType !== undefined) {
            if (ElisaApplication.manageHeaderBar.databaseId !== 0) {
                metaDataModel.initializeByIdAndUrl(trackType, databaseId, fileUrl);
            } else {
                metaDataModel.initializeByUrl(trackType, fileUrl);
            }
        }
    }
}
