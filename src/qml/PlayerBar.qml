/*
   SPDX-License-Identifier: LGPL-3.0-or-later

   Spotify-style persistent bottom player bar for Spot-lisa.
   Left: cover + track/artist (clickable). Center: transport controls with a
   circular white play button and a progress slider. Right: volume + menu.
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.ki18n
import org.kde.kirigami as Kirigami
import org.kde.elisa

import "shared"

BasePlayerControl {
    id: playerBar

    property alias volume: volumeSlider.value
    property bool isMaximized
    property bool showNowPlayingPanel: false

    signal openArtist()
    signal openAlbum()
    signal openNowPlaying()
    signal toggleNowPlayingPanel()

    implicitHeight: toolBar.implicitHeight

    Rectangle {
        anchors.fill: parent
        color: Theme.spotifyBlack
    }

    ToolBar {
        id: toolBar
        anchors.fill: parent

        Kirigami.Theme.colorSet: Kirigami.Theme.Header
        Kirigami.Theme.inherit: false

        background: Rectangle {
            color: Theme.spotifyBlack
        }

        contentItem: Item {
            id: barContent

            // tallest of the three zones plus vertical padding
            implicitHeight: Math.max(nowPlayingZone.implicitHeight,
                                     controlZone.implicitHeight,
                                     rightZone.implicitHeight) + Kirigami.Units.largeSpacing * 2

            // media controls mirror IRL media playback devices,
            // which are not mirrored in countries that use RtL languages
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true

            // ===== Left zone: now playing =====
            // Anchored to the left edge; shrinks if the centered control
            // column needs the room, so the controls stay truly centered.
            RowLayout {
                id: nowPlayingZone

                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.verticalCenter: parent.verticalCenter

                spacing: Kirigami.Units.largeSpacing

                width: Math.min(implicitWidth,
                                Math.max(0, (parent.width - controlZone.width) / 2 - Kirigami.Units.largeSpacing * 2))

                Kirigami.Icon {
                    id: coverIcon

                    readonly property url image: ElisaApplication.manageHeaderBar.image

                    source: (image === "" || image === Qt.url("") || image === undefined || image === null) ? Theme.defaultAlbumImage : image
                    fallback: Theme.defaultAlbumImage
                    roundToIconSize: false
                    smooth: true

                    Layout.preferredWidth: Theme.coverArtSize
                    Layout.preferredHeight: Theme.coverArtSize
                    Layout.minimumWidth: Theme.coverArtSize
                    Layout.minimumHeight: Theme.coverArtSize
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    LabelWithToolTip {
                        id: titleLabel

                        text: ElisaApplication.manageHeaderBar.title
                        level: 4
                        font.bold: true
                        color: Theme.spotifyTextPrimary

                        Layout.fillWidth: true
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerBar.openNowPlaying()
                        }
                    }

                    LabelWithToolTip {
                        id: artistLabel

                        text: ElisaApplication.manageHeaderBar.artist !== undefined ? ElisaApplication.manageHeaderBar.artist : ''
                        visible: text.length > 0
                        level: 5
                        font: Kirigami.Theme.smallFont
                        color: Theme.spotifyTextSecondary

                        Layout.fillWidth: true
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerBar.openArtist()
                        }
                    }
                }
            }

            // ===== Center zone: transport controls =====
            // Anchored to the bar's horizontal center so it is always
            // perfectly centered, independent of the side zones' widths.
            ColumnLayout {
                id: controlZone

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                // Give the seek bar plenty of width (up to 600px) while
                // leaving room for the side zones; never narrower than the
                // transport buttons themselves.
                width: Math.min(Math.max(transportRow.implicitWidth, 600),
                                parent.width * 0.45)

                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    id: transportRow

                    spacing: Kirigami.Units.largeSpacing
                    Layout.alignment: Qt.AlignHCenter

                    FlatButtonWithToolTip {
                        id: shuffleButton

                        text: {
                            const map = {
                                [MediaPlayListProxyModel.NoShuffle]: KI18n.i18nc("@info:tooltip", "Current: No shuffle"),
                                [MediaPlayListProxyModel.Track]: KI18n.i18nc("@info:tooltip", "Current: Shuffle tracks"),
                                [MediaPlayListProxyModel.Album]: KI18n.i18nc("@info:tooltip", "Current: Shuffle albums"),
                            }
                            return map[ElisaApplication.mediaPlayListProxyModel.shuffleMode]
                        }
                        icon.name: {
                            const map = {
                                [MediaPlayListProxyModel.NoShuffle]: "media-playlist-no-shuffle-symbolic",
                                [MediaPlayListProxyModel.Track]: "media-playlist-shuffle",
                                [MediaPlayListProxyModel.Album]: "media-random-albums-amarok",
                            }
                            return map[ElisaApplication.mediaPlayListProxyModel.shuffleMode]
                        }
                        icon.color: checked ? Theme.spotifyAccent : Theme.spotifyTextSecondary
                        Kirigami.Theme.textColor: Theme.spotifyTextSecondary

                        checkable: true
                        checked: ElisaApplication.mediaPlayListProxyModel.shuffleMode !== 0
                        onClicked: ElisaApplication.mediaPlayListProxyModel.shuffleMode = (ElisaApplication.mediaPlayListProxyModel.shuffleMode + 1) % 3
                    }

                    FlatButtonWithToolTip {
                        id: skipBackwardButton

                        enabled: playerBar.skipBackwardEnabled
                        text: KI18n.i18nc("@action:button displayed as @info:tooltip", "Skip backward")
                        icon.name: "media-skip-backward"
                        icon.color: Theme.spotifyTextPrimary
                        Kirigami.Theme.textColor: Theme.spotifyTextPrimary
                        onClicked: playerBar.playPrevious()
                    }

                    // circular white play/pause button
                    Rectangle {
                        id: playPauseButton

                        readonly property bool hovered: playPauseMouse.containsMouse

                        implicitWidth: 32
                        implicitHeight: 32
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        radius: width / 2
                        color: !playerBar.playEnabled
                            ? Theme.spotifySurfaceElevated
                            : (playPauseMouse.pressed ? '#c8c8c8' : (hovered ? '#e6e6e6' : Theme.spotifyTextPrimary))
                        opacity: playerBar.playEnabled ? 1 : 0.6

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: playerBar.isPlaying ? "media-playback-pause" : "media-playback-start"
                            color: playerBar.playEnabled ? "#000000" : Theme.spotifyTextSecondary
                        }

                        Accessible.name: playerBar.isPlaying
                            ? KI18n.i18nc("@action:button", "Pause")
                            : KI18n.i18nc("@action:button", "Play")
                        Accessible.role: Accessible.Button

                        MouseArea {
                            id: playPauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: playerBar.playEnabled
                            onClicked: playerBar.isPlaying ? playerBar.pause() : playerBar.play()
                        }
                    }

                    FlatButtonWithToolTip {
                        id: skipForwardButton

                        enabled: playerBar.skipForwardEnabled
                        text: KI18n.i18nc("@action:button displayed as @info:tooltip skip forward in playlists", "Skip forward")
                        icon.name: "media-skip-forward"
                        icon.color: Theme.spotifyTextPrimary
                        Kirigami.Theme.textColor: Theme.spotifyTextPrimary
                        onClicked: playerBar.playNext()
                    }

                    FlatButtonWithToolTip {
                        id: repeatButton

                        text: {
                            const map = {
                                [MediaPlayListProxyModel.None]: KI18n.i18nc("@info:tooltip", "Current: Don't repeat tracks"),
                                [MediaPlayListProxyModel.One]: KI18n.i18nc("@info:tooltip", "Current: Repeat current track"),
                                [MediaPlayListProxyModel.Playlist]: KI18n.i18nc("@info:tooltip", "Current: Repeat all tracks in playlist"),
                            }
                            return map[ElisaApplication.mediaPlayListProxyModel.repeatMode]
                        }
                        icon.name: {
                            const map = {
                                [MediaPlayListProxyModel.None]: "media-repeat-none",
                                [MediaPlayListProxyModel.One]: "media-repeat-single",
                                [MediaPlayListProxyModel.Playlist]: "media-repeat-all",
                            }
                            return map[ElisaApplication.mediaPlayListProxyModel.repeatMode]
                        }
                        icon.color: checked ? Theme.spotifyAccent : Theme.spotifyTextSecondary
                        Kirigami.Theme.textColor: Theme.spotifyTextSecondary

                        checkable: true
                        checked: ElisaApplication.mediaPlayListProxyModel.repeatMode !== 0
                        onClicked: ElisaApplication.mediaPlayListProxyModel.repeatMode = (ElisaApplication.mediaPlayListProxyModel.repeatMode + 1) % 3
                    }
                }

                RowLayout {
                    id: progressRow

                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter

                    // TODO: Make duration values locale-aware
                    DurationSlider {
                        id: durationSlider

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        position: playerBar.position
                        duration: playerBar.duration
                        seekable: playerBar.seekable
                        playEnabled: playerBar.playEnabled
                        onSeek: position => playerBar.seek(position)

                        labelColor: Theme.spotifyTextSecondary
                    }
                }
            }

            // ===== Right zone: volume + menu =====
            // Anchored to the right edge; shrinks if the centered control
            // column needs the room, so the controls stay truly centered.
            RowLayout {
                id: rightZone

                // NB: LayoutMirroring.enabled flips anchors (right would become
                // left), so position with an explicit x instead — mirroring
                // never touches the x coordinate.
                x: parent.width - width - Kirigami.Units.largeSpacing
                anchors.verticalCenter: parent.verticalCenter

                spacing: Kirigami.Units.smallSpacing
                LayoutMirroring.enabled: true
                LayoutMirroring.childrenInherit: true

                width: Math.min(implicitWidth,
                                Math.max(0, (parent.width - controlZone.width) / 2 - Kirigami.Units.largeSpacing * 2))

                FlatButtonWithToolTip {
                    id: muteButton

                    text: playerBar.muted
                        ? KI18n.i18nc("@action:button displayed as @info:tooltip", "Unmute")
                        : KI18n.i18nc("@action:button displayed as @info:tooltip", "Mute")
                    icon.name: playerBar.muted ? "audio-volume-muted" : "audio-volume-high"
                    icon.color: Theme.spotifyTextSecondary
                    Kirigami.Theme.textColor: Theme.spotifyTextSecondary
                    onClicked: playerBar.muted = !playerBar.muted
                }

                VolumeSlider {
                    id: volumeSlider

                    Layout.preferredWidth: Theme.volumeSliderWidth
                    Layout.maximumWidth: Theme.volumeSliderWidth
                    Layout.minimumWidth: Theme.volumeSliderWidth
                    Layout.alignment: Qt.AlignVCenter

                    interactionHeight: barContent.height

                    muted: playerBar.muted
                }

                // toggle the right-side "Now Playing" panel
                FlatButtonWithToolTip {
                    id: nowPlayingPanelButton

                    visible: mainWindow.isWideScreen
                    text: KI18n.i18nc("@action:button displayed as @info:tooltip", "Toggle Now Playing panel")
                    icon.name: "media-album-cover"
                    icon.color: checked ? Theme.spotifyAccent : Theme.spotifyTextSecondary
                    Kirigami.Theme.textColor: checked ? Theme.spotifyAccent : Theme.spotifyTextSecondary

                    checkable: true
                    checked: playerBar.showNowPlayingPanel
                    onClicked: playerBar.toggleNowPlayingPanel()
                }

                FlatButtonWithToolTip {
                    id: menuButton

                    function openMenu() {
                        if (!menu.visible) {
                            menu.open()
                        } else {
                            (menu as ApplicationMenu).dismiss()
                        }
                    }

                    text: KI18n.i18nc("@action:button displayed as @info:tooltip", "Application menu")
                    icon.name: "open-menu-symbolic"
                    icon.color: Theme.spotifyTextSecondary
                    Kirigami.Theme.textColor: Theme.spotifyTextSecondary

                    down: pressed || menu.visible
                    Accessible.role: Accessible.ButtonMenu

                    onPressed: openMenu()
                    Keys.onReturnPressed: openMenu()
                    Keys.onEnterPressed: openMenu()

                    menu: ApplicationMenu {
                        y: menuButton.height
                        modal: true
                        dim: false
                    }
                }
            }
        }
    }
}
