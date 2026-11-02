# SPDX-FileCopyrightText: 2017 (c) Aleix Pol <aleixpol@kde.org>
#
# SPDX-License-Identifier: LGPL-3.0-or-later

set(elisa_ICONS_PNG
    128-apps-spotlisa.png
    64-apps-spotlisa.png
    48-apps-spotlisa.png
    32-apps-spotlisa.png
    22-apps-spotlisa.png
    16-apps-spotlisa.png
)

ecm_install_icons(ICONS
    sc-apps-spotlisa.svg
    ${elisa_ICONS_PNG}
DESTINATION ${KDE_INSTALL_ICONDIR} THEME hicolor )

