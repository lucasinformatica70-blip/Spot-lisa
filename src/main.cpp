/*
   SPDX-FileCopyrightText: 2015 (c) Matthieu Gallien <matthieu_gallien@yahoo.fr>

   SPDX-License-Identifier: LGPL-3.0-or-later
 */

#include "config-upnp-qt.h"
#include "elisa-version.h"

#include "colorschemepreviewimageprovider.h"
#include "elisaapplication.h"
#include "elisa_settings.h"

#include "localFileConfiguration/elisaconfigurationdialog.h"

#if KFDBusAddons_FOUND
#include <KDBusService>
#endif

#if KFFileMetaData_FOUND
#include "embeddedcoverageimageprovider.h"
#endif

//#define QT_QML_DEBUG

#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include <KAboutData>
#include <KColorSchemeManager>
#include <KIconTheme>
#include <KirigamiAddons/App/KirigamiAppDefaults>

#if KFCrash_FOUND
#include <KCrash>
#endif

#include <KQuickIconProvider>
#include <QIcon>

#include <QApplication>
#include <QColor>
#include <QCommandLineParser>
#include <QDir>
#include <QModelIndex>
#include <QPalette>
#include <QQmlContext>
#include <QStandardPaths>
#include <QSurfaceFormat>

#include <QQmlApplicationEngine>
#include <QQmlFileSelector>
#include <QQuickStyle>

#include <memory>

#ifdef Q_OS_ANDROID
#include "android/androidcoverimageprovider.h"
#include "android/androidplayerjni.h"

#include <QCoreApplication>
#include <QJniObject>
#include <QtCore/private/qandroidextras_p.h>
#endif

#ifdef Q_OS_WIN
#include <Windows.h>
#endif

#ifdef Q_OS_ANDROID
int __attribute__((visibility("default"))) main(int argc, char *argv[])
#else
int main(int argc, char *argv[])
#endif
{
#ifdef Q_OS_ANDROID
    if(argc > 1 && strcmp(argv[1], "-service") == 0){
        QAndroidService app(argc, argv);
        qInfo() << "Service starting...";

        // My service stuff

        return app.exec();
    }

    qInfo() << "Application starting...";

    qputenv("QT_LOGGING_RULES", "org.kde.elisa*=true");

    AndroidPlayerJni::registerNativeMethods();
#endif

    qputenv("QT_GSTREAMER_USE_PLAYBIN_VOLUME", "true");

    QApplication app(argc, argv);

    // Spot-lisa always presents Spotify's dark look, regardless of the
    // system color scheme. Install a Spotify-tinted dark palette so that
    // both Qt Quick Controls and Kirigami (which derives its semantic
    // colors from the application palette) render the dark theme.
    {
        const QColor base{QStringLiteral("#121212")};
        const QColor surface{QStringLiteral("#181818")};
        const QColor elevated{QStringLiteral("#242424")};
        const QColor textPrimary{QStringLiteral("#FFFFFF")};
        const QColor textSecondary{QStringLiteral("#B3B3B3")};
        const QColor accent{QStringLiteral("#1DB954")};

        QPalette palette;
        palette.setColor(QPalette::Window, base);
        palette.setColor(QPalette::WindowText, textPrimary);
        palette.setColor(QPalette::Base, base);
        palette.setColor(QPalette::AlternateBase, surface);
        palette.setColor(QPalette::ToolTipBase, elevated);
        palette.setColor(QPalette::ToolTipText, textPrimary);
        palette.setColor(QPalette::PlaceholderText, textSecondary);
        palette.setColor(QPalette::Text, textPrimary);
        palette.setColor(QPalette::Button, surface);
        palette.setColor(QPalette::ButtonText, textPrimary);
        palette.setColor(QPalette::BrightText, accent);
        palette.setColor(QPalette::Link, accent);
        palette.setColor(QPalette::LinkVisited, accent);
        palette.setColor(QPalette::Highlight, accent);
        palette.setColor(QPalette::HighlightedText, QStringLiteral("#000000"));
        palette.setColor(QPalette::Light, elevated);
        palette.setColor(QPalette::Midlight, surface);
        palette.setColor(QPalette::Mid, elevated);
        palette.setColor(QPalette::Dark, base);
        palette.setColor(QPalette::Shadow, QStringLiteral("#000000"));
        for (const auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
            palette.setColor(group, QPalette::Window, base);
            palette.setColor(group, QPalette::WindowText, group == QPalette::Disabled ? textSecondary : textPrimary);
            palette.setColor(group, QPalette::Base, base);
            palette.setColor(group, QPalette::AlternateBase, surface);
            palette.setColor(group, QPalette::Text, group == QPalette::Disabled ? textSecondary : textPrimary);
            palette.setColor(group, QPalette::Button, surface);
            palette.setColor(group, QPalette::ButtonText, group == QPalette::Disabled ? textSecondary : textPrimary);
            palette.setColor(group, QPalette::Highlight, accent);
            palette.setColor(group, QPalette::HighlightedText, QStringLiteral("#000000"));
        }
        app.setPalette(palette);

        // Force a dark base scheme so Kirigami's semantic colors (menus,
        // dialogs, tooltips) are guaranteed dark. The Spotify-tinted
        // palette installed above provides the accent/text tint on top.
        // If the scheme isn't available, activateScheme is a no-op and the
        // palette above still applies.
        const QModelIndex darkIndex = KColorSchemeManager::instance()->indexForScheme(QStringLiteral("Breeze Dark"));
        if (darkIndex.isValid()) {
            KColorSchemeManager::instance()->activateScheme(darkIndex);
            app.setPalette(palette);
        }
    }

    // Translation catalog: the po/ files are installed as spotlisa.mo, a
    // domain distinct from Elisa's so both packages can be installed at once.
    KLocalizedString::setApplicationDomain(QByteArrayLiteral("spotlisa"));

    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("spotlisa")));

    // KAboutData's component name drives QCoreApplication::applicationName,
    // the organization domain (kde.org), the desktop file name
    // (org.kde.spotlisa) and the D-Bus service name used for single-instance
    // activation (org.kde.spotlisa). All of them must stay distinct from
    // Elisa's so both applications can be installed side by side.
    KAboutData aboutData(QStringLiteral("spotlisa"),
                         i18nc("@title", "Spot-lisa"),
                         QStringLiteral(ELISA_VERSION_STRING),
                         i18nc("@info", "A Spotify-style music player, a friendly fork of Elisa by the KDE community"),
                         KAboutLicense::LGPL_V3,
                         i18nc("@info", "© 2015–2026, Elisa contributors"));

    aboutData.addAuthor(QStringLiteral("Matthieu Gallien"),i18nc("@label", "Creator"), QStringLiteral("mgallien@mgallien.fr"));
    aboutData.addAuthor(QStringLiteral("Nate Graham"), i18nc("@label", "Author"), QStringLiteral("nate@kde.org"));

    aboutData.addCredit(QStringLiteral("Andrew Lake"), i18nc("@label", "Concept and design work"), QStringLiteral("jamboarder@gmail.com"));
    aboutData.addCredit(QStringLiteral("Luigi Toscano"), i18nc("@label", "Localization support"), QStringLiteral("luigi.toscano@tiscali.it"));
    aboutData.addCredit(QStringLiteral("Safa Alfulaij"), i18nc("@label", "Right to left support in interface"), QStringLiteral("safa1996alfulaij@gmail.com"));
    aboutData.addCredit(QStringLiteral("Diego Gangl"), i18nc("@label", "Various improvements to the interface"), QStringLiteral("diego@sinestesia.co"));
    aboutData.addCredit(QStringLiteral("Jérôme Guidon"), i18nc("@label", "Support for online radios"), QStringLiteral("guidon@live.fr"));

    KAboutData::setApplicationData(aboutData);

    KirigamiAppDefaults::apply(&app);

    QCommandLineParser parser;
    aboutData.setupCommandLine(&parser);
    parser.process(app);
    aboutData.processCommandLine(&parser);

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/imports"));
    QQmlFileSelector selector(&engine);
    constexpr auto qmlUri = "org.kde.elisa";

#if KFDBusAddons_FOUND
    const auto *elisaApplication = engine.singletonInstance<ElisaApplication *>(qmlUri, "ElisaApplication");

    KDBusService service(KDBusService::Unique);
    service.connect(&service, &KDBusService::activateActionRequested, elisaApplication, &ElisaApplication::activateActionRequested);
    service.connect(&service, &KDBusService::activateRequested, elisaApplication, &ElisaApplication::activateRequested);
    service.connect(&service, &KDBusService::openRequested, elisaApplication, &ElisaApplication::openRequested);
#endif

    // Allow image:// icon URLs to be loaded as images im QML
    engine.addImageProvider(QStringLiteral("icon"), new KQuickIconProvider);

#if KFFileMetaData_FOUND
    engine.addImageProvider(QStringLiteral("cover"), new EmbeddedCoverageImageProvider);
#endif

#ifdef Q_OS_ANDROID
    engine.addImageProvider(QStringLiteral("android"), new AndroidCoverImageProvider);
#endif

    engine.addImageProvider(QStringLiteral("colorScheme"), new ColorSchemePreviewImageProvider);

    KLocalization::setupLocalizedContext(&engine);

    QList<QUrl> urls;
    const auto positionalArguments = parser.positionalArguments();
    for (const auto &oneArgument : positionalArguments) {
        urls.push_back(QUrl::fromUserInput(oneArgument, QDir::currentPath()));
    }

    engine.rootContext()->setContextProperty(QStringLiteral("elisaStartupArguments"), QVariant::fromValue(urls));

    engine.loadFromModule(qmlUri, "ElisaMainWindow");

    return app.exec();
}
