<!--
SPDX-FileCopyrightText: 2017 Matthieu Gallien <matthieu_gallien@yahoo.fr>
SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>

SPDX-License-Identifier: LGPL-3.0-or-later
-->

# Spot-lisa

## Introduction

Spot-lisa is a friendly fork of [Elisa](https://apps.kde.org/elisa/) that reimagines the KDE music player with a Spotify-inspired look and feel: a persistent bottom player bar, a left sidebar that merges navigation with your library, and a forced dark theme.

Spot-lisa remains a simple local music player, and all credit for the original Elisa application belongs to its contributors.

## Installing

Spot-lisa is deliberately installable **next to Elisa**: nothing has to be uninstalled, and both players can even run at the same time. Every install-facing identity is its own — executable `spot-lisa`, desktop file and appstream ID `org.kde.spotlisa.desktop`, D-Bus service `org.kde.spotlisa`, MPRIS name `org.mpris.MediaPlayer2.spotlisa`, icons `spotlisa.*`, translation catalog `spotlisa.mo`, config file `~/.config/spotlisarc` and music database `~/.local/share/spotlisa/spotlisaDatabase.db`. Elisa's files are never touched.

### Flatpak

```sh
flatpak install --user flathub org.kde.Platform//6.11 org.kde.Sdk//6.11
flatpak run org.flatpak.Builder --force-clean --user --install build-flatpak .flatpak-manifest.json
flatpak run org.kde.spotlisa
```

The Flatpak is fully sandboxed, so it can coexist with a distribution-installed Elisa (or a Flathub Elisa) without any file ever overlapping.

### Native install

```sh
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build            # use -DCMAKE_INSTALL_PREFIX=~/.local (or /usr/local) to stay clear of the distribution's Elisa
```

Installing with the default `/usr` prefix is also conflict-free: no file path overlaps with the `elisa` distribution package (verified by staging an install and diffing it against the package's file list).

## Contributions

Contributions are very much welcome! The process of building Elisa from source using KDE's `kdesrc-build` tool is easy and recommended. See
https://community.kde.org/Get_Involved/development/Build_software_with_kdesrc-build
for information on how to set this up.

Please send code contributions by submitting a merge request at
https://invent.kde.org/multimedia/elisa/-/merge_requests. If you aren't familiar
with this process, you can learn how to do it [here](https://community.kde.org/Infrastructure/GitLab#Submitting_a_merge_request).
