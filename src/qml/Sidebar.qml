/*
   SPDX-License-Identifier: LGPL-3.0-or-later

   Spotify-style left sidebar for Spot-lisa.
   Top: navigation entries (Home, albums, artists, ...). Bottom: the "Your
   Library" panel holding the current play queue / playlist.
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.ki18n
import org.kde.kirigami as Kirigami
import org.kde.elisa

FocusScope {
    id: sidebar

    // The index of the view being displayed, not the one that is "highlighted"
    required property int displayedViewIndex

    property alias model: viewModeView.model
    property alias viewIndex: viewModeView.currentIndex

    // Whether the library (playlist) section is shown. On narrow screens the
    // playlist is available through the context drawer instead.
    property bool showLibrary: true

    readonly property int wideWidth: Kirigami.Units.gridUnit * 15
    // The sidebar always shows icon + label, so the "icons only" minimum is
    // just a reasonable floor for the SplitView to shrink to.
    readonly property real iconsOnlyMinWidth: Kirigami.Units.gridUnit * 12
    readonly property real iconsOnlyMaxWidth: wideWidth
    readonly property real navImplicitHeight: viewModeView.contentHeight + Kirigami.Units.largeSpacing * 2

    signal switchView(int viewIndex)

    Rectangle {
        anchors.fill: parent
        color: Theme.spotifyBlack
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ===== Navigation =====
        ScrollView {
            id: navScrollView

            Layout.fillWidth: true
            Layout.preferredHeight: sidebar.navImplicitHeight
            Layout.maximumHeight: sidebar.navImplicitHeight

            // HACK: workaround for https://bugreports.qt.io/browse/QTBUG-83890
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            contentItem: ListView {
                id: viewModeView

                readonly property int iconsOnlyWidth: Kirigami.Units.iconSizes.smallMedium + 2 * Kirigami.Units.largeSpacing

                reuseItems: true
                clip: true
                focus: true
                activeFocusOnTab: true
                keyNavigationEnabled: true
                interactive: false

                delegate: ItemDelegate {
                    id: delegate

                    required property int index
                    required property string title
                    required property url image

                    readonly property bool usingThemeIcon: delegate.image.toString().startsWith("image://icon/")

                    width: viewModeView.width
                    height: Kirigami.Units.gridUnit * 3

                    hoverEnabled: true

                    // recolor text/icon for the dark sidebar
                    Kirigami.Theme.inherit: false
                    Kirigami.Theme.colorSet: Kirigami.Theme.View
                    palette.text: delegate.highlighted ? Theme.spotifyAccent : Theme.spotifyTextPrimary
                    palette.highlightedText: delegate.highlighted ? Theme.spotifyAccent : Theme.spotifyTextPrimary

                    background: Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        height: Kirigami.Units.gridUnit * 2.4
                        radius: Theme.spotifyRadius
                        color: delegate.highlighted || delegate.hovered ? Theme.spotifyHighlightElevated : "transparent"
                    }

                    // We need to pass theme icons (i.e. not cover images) by icon.name so that
                    // Kirigami.Icon applies the correct color when the delegate is highlighted.
                    icon.name: usingThemeIcon ? delegate.image.toString().substring(13) : ""
                    icon.source: image
                    icon.color: delegate.highlighted ? Theme.spotifyAccent : Theme.spotifyTextPrimary
                    text: title
                    highlighted: index === sidebar.displayedViewIndex

                    // Prevent icon recoloring for styles that don't set `icon.color: "transparent"` by default
                    Binding {
                        when: !delegate.usingThemeIcon
                        delegate.icon.color: "transparent"
                    }

                    onClicked: {
                        sidebar.switchView(index)
                        forceActiveFocus()
                    }

                    Keys.onReturnPressed: {
                        sidebar.switchView(index)
                        forceActiveFocus()
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            color: Theme.spotifyDivider
        }

        // ===== Your Library (playlist) =====
        ColumnLayout {
            visible: sidebar.showLibrary
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    text: KI18n.i18nc("@title", "Your Library")
                    level: 4
                    font.bold: true
                    color: Theme.spotifyTextPrimary
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                FlatButtonWithToolTip {
                    text: KI18n.i18nc("@action:button Open music files or saved playlists", "Open…")
                    icon.name: 'document-open'
                    icon.color: Theme.spotifyTextSecondary
                    Kirigami.Theme.textColor: Theme.spotifyTextSecondary
                    onClicked: mainWindow.fileDialog.loadPlaylistOrMusicFile()
                }
            }

            MediaPlayListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                embeddedInSidebar: true
            }
        }
    }
}
