/*
   SPDX-FileCopyrightText: 2016 (c) Matthieu Gallien <matthieu_gallien@yahoo.fr>
   SPDX-FileCopyrightText: 2021 (c) Devin Lin <espidev@gmail.com>

   SPDX-License-Identifier: LGPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import org.kde.ki18n
import org.kde.kirigami as Kirigami
import org.kde.elisa

AccessibleSlider {
    id: volumeSlider

    property bool muted

    // The player bar's right zone enables layout mirroring for RTL button
    // ordering, but a slider must stay left-to-right: a mirrored control
    // reports visualPosition as 1.0 - position, which renders the fill and
    // handle inverted (100% volume would look empty and drag backwards).
    LayoutMirroring.enabled: false

    // Use its own visible height by default
    interactionHeight: height

    from: 0
    to: 100

    keyStepSize: 1
    wheelStepSize: 5

    enabled: !muted

    Accessible.name: KI18n.i18nc("@label", "Volume")

    onPressedChanged: {
        tooltip.delay = pressed ? 0 : Kirigami.Units.toolTipDelay
    }

    MouseArea {
        id: sliderMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }

    ToolTip {
        id: tooltip
        x: volumeSlider.visualPosition * volumeSlider.width - width / 2
        visible: volumeSlider.pressed || sliderMouseArea.containsMouse
        // delay is actually handled in volumeSlider.onPressedChanged, because property bindings aren't immediate
        delay: volumeSlider.pressed ? 0 : Kirigami.Units.toolTipDelay
        closePolicy: Popup.NoAutoClose
        timeout: -1
        text: KI18n.i18nc("Volume as a percentage", "%1%", Math.round(volumeSlider.value))
    }

    // Spotify-style groove: thin dark track that turns white on the filled part
    background: Rectangle {
        x: volumeSlider.leftPadding
        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
        width: volumeSlider.availableWidth
        height: volumeSlider.pressed || sliderMouseArea.containsMouse ? 6 : 4
        radius: height / 2
        color: Theme.spotifySurfaceElevated
        Behavior on height { NumberAnimation { duration: 100 } }

        Rectangle {
            width: volumeSlider.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.spotifyTextPrimary
        }
    }

    // Spotify-style handle: white circle, shown on hover/drag
    handle: Rectangle {
        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
        width: volumeSlider.pressed || sliderMouseArea.containsMouse ? 14 : 0
        height: width
        radius: width / 2
        color: Theme.spotifyTextPrimary
        Behavior on width { NumberAnimation { duration: 100 } }
    }
}
