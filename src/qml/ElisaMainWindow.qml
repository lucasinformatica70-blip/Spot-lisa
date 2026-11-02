/*
   SPDX-FileCopyrightText: 2016 (c) Matthieu Gallien <matthieu_gallien@yahoo.fr>

   SPDX-License-Identifier: LGPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQml
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs as Dialogs
import org.kde.config as KConfig
import org.kde.ki18n
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.elisa
import Qt.labs.platform

import "mobile"

Kirigami.ApplicationWindow {
    id: mainWindow

    visible: true

    Connections {
        target: ElisaApplication.mediaPlayListProxyModel
        function onPlayListLoadFailed() {
            mainWindow.showPassiveNotification(KI18n.i18nc("@label", "Loading failed"), 7000, KI18n.i18nc("@action:button", "Retry"), () => loadPlaylistButton.clicked())
        }

        function onDisplayUndoNotification() {
            mainWindow.showPassiveNotification(KI18n.i18nc("@label", "Playlist cleared"), 7000, KI18n.i18nc("@action:button", "Undo"), () => ElisaApplication.mediaPlayListProxyModel.undoClearPlayList())
        }
    }

    Connections {
        target: ElisaApplication

        function onOpenAboutKDEPage() {
            const openDialogWindow = mainWindow.pageStack.pushDialogLayer(aboutKDEPage, {
                width: ElisaApplication.width
            }, {
                width: Kirigami.Units.gridUnit * 30,
                height: Kirigami.Units.gridUnit * 30,
                modality: Qt.NonModal
            });
        }

        function onOpenAboutAppPage() {
            const openDialogWindow = mainWindow.pageStack.pushDialogLayer(aboutAppPage, {
                width: ElisaApplication.width
            }, {
                width: Kirigami.Units.gridUnit * 30,
                height: Kirigami.Units.gridUnit * 30,
                modality: Qt.NonModal
            });
        }

        function onConfigureElisa() {
            if (Kirigami.Settings.isMobile) {
                mainWindow.pageStack.layers.push("MobileSettingsPage.qml");
            } else {
                const component = Qt.createComponent(Qt.resolvedUrl("./ConfigurationDialog.qml"));
                if (component.status === Component.Error) {
                    console.error(component.errorString());
                    return;
                }
                const window = component.createObject(mainWindow);
            }
        }

        function onGoBack() {
            contentView.goBack();
        }

        function onTogglePlaylist() {
            if (mainWindow.isWideScreen) {
                contentView.showPlaylist = !contentView.showPlaylist;
            } else {
                mainWindow.contextDrawer.open();
            }
        }

        function onClearPlaylist() {
            ElisaApplication.mediaPlayListProxyModel.clearPlayList();
        }

        function onSeek() {
            ElisaApplication.audioControl.seek(mainWindow.playerControlItem.position + 10000);
        }

        function onScrub() {
            ElisaApplication.audioControl.seek(mainWindow.playerControlItem.position - 10000);
        }

        function onNextTrack() {
            ElisaApplication.mediaPlayListProxyModel.skipNextTrack(ElisaUtils.Manual);
        }

        function onPreviousTrack() {
            ElisaApplication.mediaPlayListProxyModel.skipPreviousTrack(ElisaApplication.audioPlayer.position);
        }

        function onPlayPause() {
            ElisaApplication.audioControl.playPause();
        }

        function onFind() {
            persistentSettings.expandedFilterView = !persistentSettings.expandedFilterView;
        }

        function onTogglePartyMode() {
            mainWindow.toggleNowPlaying();
        }
    }

    Loader {
        id: mobileSidebar
        active: Kirigami.Settings.isMobile

        function updateSidebarIndex() {
            if (status === Loader.Ready) {
                item.viewIndex = (item as MobileSidebar).model.mapRowFromSource(contentView.viewManager.viewIndex)
            }
        }

        sourceComponent: MobileSidebar {
            model: contentView.pageProxyModel
            viewIndex: model.mapRowFromSource(contentView.viewManager.viewIndex)
            onSwitchView: viewIndex => contentView.viewManager.openView(model.mapRowToSource(viewIndex))
        }
    }

    globalDrawer: mobileSidebar.active ? mobileSidebar.item as MobileSidebar : null

    contextDrawer: Kirigami.ContextDrawer {
        id: playlistDrawer
        handleClosedIcon.name: "view-media-playlist"
        handleClosedIcon.color: Theme.spotifyTextPrimary
        handleOpenIcon.name: "view-right-close"
        handleClosedToolTip: KI18n.i18nc("@action:button", "Show playlist drawer")
        handleOpenToolTip: KI18n.i18nc("@action:button", "Hide playlist drawer")

        // only used on narrow screens where the sidebar hides its library
        handleVisible: !Kirigami.Settings.isMobile && !mainWindow.isWideScreen && (drawerOpen || mainWindow.tracksInPlaylist)

        interactive: Kirigami.Settings.isMobile

        // without this drawer button is never shown
        enabled: true
        MediaPlayListView {
            anchors.fill: parent
        }
    }

    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            if (drop.hasUrls) {
                if (!ElisaApplication.openFiles(drop.urls)) {
                    mainWindow.showPassiveNotification(KI18n.i18nc("@info:status", "Could not load some files. Spot-lisa can only open audio and playlist files."), 7000, "", function() {})
                }
            }
        }
    }

    // HACK: since elisa's main view hasn't been ported to a page, but page layers are used for mobile settings
    // lower the main view and mobile footer's z to be behind the layer when there are layers added (normally it is in front)
    property bool layerOnTop: pageStack.layers.depth > 1

    // disable certain transitions at startup
    property bool transitionsEnabled: false
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: { mainWindow.transitionsEnabled = true }
    }

    minimumWidth: Kirigami.Units.gridUnit * (Kirigami.Settings.isMobile ? 17 : 34)
    property int minHeight: Kirigami.Units.gridUnit * 17

    property string previousStateBeforeFullScreen: "windowed"
    function restorePreviousStateBeforeFullScreen() {
        if (previousStateBeforeFullScreen === "windowed") {
            showNormal()
        } else if (previousStateBeforeFullScreen === "maximized") {
            // Need to make it windowed before showMaximized will work, apparently
            showNormal()
            showMaximized()
        } else if (previousStateBeforeFullScreen === "minimized") {
            showMinimized()
        } else if (previousStateBeforeFullScreen === "hidden") {
            show()
        } else if (previousStateBeforeFullScreen === "automatic") {
            show()
        }
    }
    function goFullScreen() {
        if (visibility === Window.Windowed) {
            previousStateBeforeFullScreen = "windowed"
        } else if (visibility === Window.Maximized) {
            previousStateBeforeFullScreen = "maximized"
        } else if (visibility === Window.Minimized) {
            previousStateBeforeFullScreen = "minimized"
        } else if (visibility === Window.Hidden) {
            previousStateBeforeFullScreen = "hidden"
        } else if (visibility === Window.AutomaticVisibility){
            previousStateBeforeFullScreen = "automatic"
        }
        showFullScreen()
    }

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    width: Kirigami.Units.gridUnit * 50
    height: Kirigami.Units.gridUnit * 36

    title: ElisaApplication.manageHeaderBar.title ? KI18n.i18nc("@title:window", "%1 — Spot-lisa", ElisaApplication.manageHeaderBar.title) : KI18n.i18nc("@title:window", "Spot-lisa")

    readonly property int initialViewIndex: 3

    // The active player control: mobile footer bar, or the desktop bottom player bar
    readonly property var mediaPlayerControl: Kirigami.Settings.isMobile ? mobileFooterBarLoader.item : playerBarLoader.item
    // The inner transport control exposing volume/muted/position
    readonly property var playerControlItem: Kirigami.Settings.isMobile ? mobileFooterBarLoader.item.playerControl : playerBarLoader.item
    readonly property alias fileDialog: fileDialog

    readonly property bool inPartyMode: nowPlayingLoader.active
    readonly property bool isWideScreen: mainWindow.width >= Theme.viewSelectorSmallSizeThreshold
    readonly property int tracksInPlaylist: ElisaApplication.mediaPlayListProxyModel ? ElisaApplication.mediaPlayListProxyModel.tracksCount : 0

    // Now Playing (party mode) overlay
    readonly property alias nowPlayingVisible: nowPlayingLoader.active

    function toggleNowPlaying() {
        if (nowPlayingLoader.active) {
            nowPlayingLoader.active = false;
        } else {
            nowPlayingLoader.active = true;
        }
    }

    function openNowPlaying() {
        nowPlayingLoader.active = true;
    }

    // Avoid Ambiguity with Plasma Global Quit-Shortcut
    quitAction.enabled: false

    // Setup keyboard shortcuts for actions that aren't used in the GUI
    Kirigami.Action {
        fromQAction: ElisaActions.goBackQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.clearPlaylistQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.seekQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.scrubQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.nextTrackQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.previousTrackQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.playPauseQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.editFindQAction
    }

    Kirigami.Action {
        fromQAction: ElisaActions.togglePartyModeQAction
    }

    Dialogs.FileDialog {
        id: fileDialog

        // Keep these in sync with MIME types listed in org.kde.spotlisa.desktop.cmake
        readonly property string playlistFormats: "*.m3u* *.pls"
        readonly property string musicFormats: "*.aac *.m4a *.ra *.rax *.oga *.ogg *.opus *.spx *.flac *.mp3 *.wma *.mpc *.mpp *.mp+ *.wav *.ogm"

        function savePlaylist() {
            nameFilters = [ KI18n.i18nc("@option file type (mime type) for m3u, m3u8 playlist file formats; do not translate *.m3u*", "m3u8, m3u Playlist File (*.m3u*)"), KI18n.i18nc("@option file type (mime type) for pls playlist file formats; do not translate *.pls", "pls Playlist File (*.pls)")]
            defaultSuffix = 'm3u8'
            fileMode = FileDialog.SaveFile
            open()
        }
        function loadPlaylistOrMusicFile() {
            nameFilters = [
                KI18n.i18nc("@option Allow opening music and playlist files. %1 and %2 are lists of untranslated file extensions", "Playlist files and music files (%1 %2) (%1 %2)", playlistFormats, musicFormats),
                KI18n.i18nc("@option Allow opening playlist files. %1 is an untranslated list of file extensions", "Playlist files (%1) (%1)", playlistFormats),
                KI18n.i18nc("@option Allow opening music files. %1 is an untranslated list of file extensions", "Music files (%1) (%1)", musicFormats)
            ]
            fileMode = FileDialog.OpenFile
            open()
        }

        currentFolder: StandardPaths.writableLocation(StandardPaths.MusicLocation)

        onAccepted: {
            if (fileMode === FileDialog.SaveFile) {
                if (!ElisaApplication.mediaPlayListProxyModel.savePlayList(selectedFile)) {
                    mainWindow.showPassiveNotification(KI18n.i18nc("@label", "Saving failed"), 7000, KI18n.i18nc("@action:button", "Retry"), () => savePlaylistButton.clicked())
                }
            } else {
                let selectedFileExtension = selectedFile.toString().split('.').pop()
                if (playlistFormats.includes(selectedFileExtension)) {
                    ElisaApplication.mediaPlayListProxyModel.loadPlayList(selectedFile)
                } else {
                    ElisaApplication.openFiles(selectedFiles)
                }
            }
        }
    }

    KConfig.WindowStateSaver {
        configGroupName: "MainWindow"
    }

    Settings {
        id: persistentSettings

        property var playListState

        property var audioPlayerState

        property var contentViewState

        property double playControlItemVolume : 100.0
        property bool playControlItemMuted : false

        property bool expandedFilterView: false

        property bool showPlaylist: true

        property bool nowPlayingPreferLyric: false

        property bool showNowPlayingPanel: true
    }

    Connections {
        target: Application
        function onAboutToQuit() {
            persistentSettings.playListState = ElisaApplication.mediaPlayListProxyModel.persistentState;
            persistentSettings.audioPlayerState = ElisaApplication.audioControl.persistentState
            persistentSettings.contentViewState = contentView.saveState();

            persistentSettings.playControlItemVolume = playerControlItem.volume
            persistentSettings.playControlItemMuted = playerControlItem.muted

            persistentSettings.showPlaylist = contentView.showPlaylist
        }
    }

    Loader {
        id: mprisloader
        active: false

        sourceComponent:  PlatformIntegration {
            id: platformInterface

            playListModel: ElisaApplication.mediaPlayListProxyModel
            audioPlayerManager: ElisaApplication.audioControl
            player: ElisaApplication.audioPlayer
            headerBarManager: ElisaApplication.manageHeaderBar
            manageMediaPlayerControl: ElisaApplication.playerControl
            showProgressOnTaskBar: ElisaApplication.showProgressOnTaskBar
            showSystemTrayIcon: ElisaApplication.showSystemTrayIcon
            elisaMainWindow: mainWindow

            onRaisePlayer: function() {
                mainWindow.visible = true
                mainWindow.raise()
                mainWindow.requestActivate()
            }
        }
    }

    Connections {
        target: ElisaApplication.audioPlayer
        function onVolumeChanged() {
            if (mainWindow.playerControlItem !== null) {
                mainWindow.playerControlItem.volume = ElisaApplication.audioPlayer.volume
            }
        }
        function onMutedChanged() {
            if (mainWindow.playerControlItem !== null) {
                mainWindow.playerControlItem.muted = ElisaApplication.audioPlayer.muted
            }
        }
    }

    // mobile footer bar
    Loader {
        id: mobileFooterBarLoader
        anchors.fill: parent

        active: Kirigami.Settings.isMobile
        visible: active

        // footer bar fills the whole page, so only be in front of the main view when it is opened
        // otherwise, it captures all mouse/touch events on the main view
        z: (!item || (item as MobileFooterBar).contentY === 0) ? (mainWindow.layerOnTop ? -1 : 0) : 999

        readonly property real toolBarHeight: active ? (item as MobileFooterBar).trackControl.height : 0

        sourceComponent: MobileFooterBar {
            id: mobileFooterBar
            contentHeight: mainWindow.height * 2

            focus: true

            album: (ElisaApplication.manageHeaderBar.album !== undefined ? ElisaApplication.manageHeaderBar.album : '')
            title: ElisaApplication.manageHeaderBar.title
            artist: (ElisaApplication.manageHeaderBar.artist !== undefined ? ElisaApplication.manageHeaderBar.artist : '')
            albumArtist: (ElisaApplication.manageHeaderBar.albumArtist !== undefined ? ElisaApplication.manageHeaderBar.albumArtist : '')
            image: ElisaApplication.manageHeaderBar.image
            albumID: ElisaApplication.manageHeaderBar.albumId

            ratingVisible: false

            // since we have multiple volume bars, and only one is linked directly to audio, sync the other one (trackControl)
            Binding on playerControl.volume {
                when: mobileFooterBar.trackControl.volumeSlider.moved
                value: mobileFooterBar.trackControl.volume
            }
            Component.onCompleted: {
                trackControl.volume = Qt.binding(() => mobileFooterBar.playerControl.volume);
            }

            onOpenArtist: { contentView.openArtist(artist) }
            onOpenNowPlaying: { contentView.openNowPlaying() }
            onOpenAlbum: { contentView.openAlbum(album, albumArtist, image, albumID) }
        }
    }

    Rectangle {
        id: mainContent

        visible: !mainWindow.layerOnTop

        color: Theme.spotifyBase
        anchors.fill: parent
        anchors.bottomMargin: Kirigami.Settings.isMobile ? mobileFooterBarLoader.toolBarHeight : 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ===== main area (sidebar + content) with Spotify rounded surfaces =====
            Rectangle {
                id: contentArea

                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Theme.spotifyBlack

                // inset + rounded corners for the Spotify "card" look
                readonly property int insetMargin: Kirigami.Units.smallSpacing

                Rectangle {
                    id: contentClip
                    anchors.fill: parent
                    anchors.margins: contentArea.insetMargin
                    radius: Theme.spotifyRadius
                    color: Theme.spotifyBase
                    clip: true

                    ContentView {
                        id: contentView
                        anchors.fill: parent
                        showPlaylist: persistentSettings.showPlaylist
                        showNowPlayingPanel: persistentSettings.showNowPlayingPanel
                        showExpandedFilterView: persistentSettings.expandedFilterView
                        playlistDrawer: mainWindow.contextDrawer
                        initialIndex: ElisaApplication.initialViewIndex
                        enabled: !mainWindow.inPartyMode

                        onViewIndexChanged: mobileSidebar.updateSidebarIndex()
                    }
                }
            }

            FooterBar {
                Layout.fillWidth: true
            }

            // ===== desktop bottom player bar =====
            Loader {
                id: playerBarLoader
                active: !Kirigami.Settings.isMobile
                visible: active

                Layout.fillWidth: true
                Layout.preferredHeight: status === Loader.Ready ? item.implicitHeight : Kirigami.Units.gridUnit * 5

                sourceComponent: PlayerBar {
                    id: playerBar

                    focus: true
                    showNowPlayingPanel: persistentSettings.showNowPlayingPanel

                    onOpenArtist: contentView.openArtist(ElisaApplication.manageHeaderBar.artist)
                    onOpenAlbum: contentView.openAlbum(ElisaApplication.manageHeaderBar.album, ElisaApplication.manageHeaderBar.albumArtist, ElisaApplication.manageHeaderBar.image, ElisaApplication.manageHeaderBar.albumId)
                    onOpenNowPlaying: mainWindow.openNowPlaying()
                    onToggleNowPlayingPanel: persistentSettings.showNowPlayingPanel = !persistentSettings.showNowPlayingPanel
                }
            }
        }
    }

    // Now Playing / party mode overlay
    Loader {
        id: nowPlayingLoader
        anchors.fill: parent
        z: 1000
        active: false

        sourceComponent: NowPlayingView {
            anchors.fill: parent

            title: ElisaApplication.manageHeaderBar.title
            artist: (ElisaApplication.manageHeaderBar.artist !== undefined ? ElisaApplication.manageHeaderBar.artist : '')
            albumArtist: (ElisaApplication.manageHeaderBar.albumArtist !== undefined ? ElisaApplication.manageHeaderBar.albumArtist : '')
            album: (ElisaApplication.manageHeaderBar.album !== undefined ? ElisaApplication.manageHeaderBar.album : '')
            image: ElisaApplication.manageHeaderBar.image
            albumID: ElisaApplication.manageHeaderBar.albumId

            onCloseRequested: nowPlayingLoader.active = false
            onOpenArtist: contentView.openArtist(ElisaApplication.manageHeaderBar.artist)
            onOpenAlbum: contentView.openAlbum(ElisaApplication.manageHeaderBar.album, ElisaApplication.manageHeaderBar.albumArtist, ElisaApplication.manageHeaderBar.image, ElisaApplication.manageHeaderBar.albumId)
            onOpenNowPlaying: contentView.openNowPlaying()
        }
    }

    // capture mouse events behind flickable when it is open
    MouseArea {
        visible: Kirigami.Settings.isMobile && mobileFooterBarLoader.item.contentY !== 0 // only capture when the mobile footer panel is open
        anchors.fill: mobileFooterBarLoader
        preventStealing: true
        onClicked: mouse => mouse.accepted = true
    }

    Component.onCompleted:
    {
        ElisaApplication.initialize()

        if (persistentSettings.maximized) {
            showMaximized();
        }

        if (persistentSettings.playListState) {
            ElisaApplication.mediaPlayListProxyModel.persistentState = persistentSettings.playListState
        }

        if (persistentSettings.audioPlayerState) {
            ElisaApplication.audioControl.persistentState = persistentSettings.audioPlayerState
        }

        if (persistentSettings.contentViewState) {
            contentView.restoreState(persistentSettings.contentViewState);
        }

        // it seems the header/footer bars load before settings are loaded, so we need to set their settings here
        playerControlItem.volume = persistentSettings.playControlItemVolume;
        playerControlItem.muted = persistentSettings.playControlItemMuted;

        ElisaApplication.audioPlayer.muted = Qt.binding(() => playerControlItem.muted);
        ElisaApplication.audioPlayer.volume = Qt.binding(() => playerControlItem.volume);
        mprisloader.active = true

        if (!ElisaApplication.openFiles(elisaStartupArguments)) {
            showPassiveNotification(KI18n.i18nc("@info:status", "Could not load some files. Spot-lisa can only open audio and playlist files."), 7000, "", function() {})
        }
    }

    Component {
        id: aboutKDEPage
        FormCard.AboutKDEPage {}
    }

    Component {
        id: aboutAppPage
        FormCard.AboutPage {}
    }
}
