

import 'dart:async';

import 'package:dew/firebase_options.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dew/screens/now_playing_page.dart';
import 'package:dew/screens/playlist_page.dart';
import 'package:dew/screens/search_page.dart';
import 'package:dew/screens/settings_page.dart';
import 'package:dew/services/trending_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dew/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dew/services/audio_service.dart';
import 'package:dew/services/data_manager.dart';
import 'package:dew/services/logger_service.dart';
import 'package:dew/services/router_service.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/services/update_manager.dart';
import 'package:dew/style/app_themes.dart';
import 'package:dew/screens/home_page.dart';
import 'package:go_router/go_router.dart';
import 'package:dew/screens/bottom_navigation_page.dart';
import 'package:dew/screens/splash_screen.dart'; // DewMountainSplash, no video

late MusifyAudioHandler audioHandler;

final logger = Logger();

bool isFdroidBuild = false;
bool isUpdateChecked = false;

final appLanguages = <String, String>{'English': 'en'};

final appSupportedLocales = appLanguages.values
    .map((languageCode) => Locale.fromSubtags(languageCode: languageCode))
    .toList();

class Musify extends StatefulWidget {
  const Musify({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    final state = context.findAncestorStateOfType<_MusifyState>()!;
    state.changeSettings(
      newThemeMode: newThemeMode,
      newLocale: newLocale,
      newAccentColor: newAccentColor,
      systemColorStatus: useSystemColor,
    );
  }

  @override
  _MusifyState createState() => _MusifyState();
}

class _MusifyState extends State<Musify> {
  void changeSettings({
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? systemColorStatus,
  }) {
    setState(() {
      if (newThemeMode != null) {
        themeMode = newThemeMode;
        brightness = getBrightnessFromThemeMode(newThemeMode);
      }
      if (newLocale != null) {
        languageSetting = newLocale;
      }
      if (newAccentColor != null) {
        if (systemColorStatus != null &&
            useSystemColor.value != systemColorStatus) {
          useSystemColor.value = systemColorStatus;
          addOrUpdateData(
            'settings',
            'useSystemColor',
            systemColorStatus,
          );
        }
        primaryColorSetting = newAccentColor;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // Some people said that Colors.transparent causes some issues, so better to use it this way
    final trickyFixForTransparency = Colors.black.withOpacity(0.002);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: trickyFixForTransparency,
        systemNavigationBarColor: trickyFixForTransparency,
      ),
    );

    try {
      LicenseRegistry.addLicense(() async* {
        final license =
            await rootBundle.loadString('assets/licenses/paytone.txt');
        yield LicenseEntryWithLineBreaks(['paytoneOne'], license);
      });
    } catch (e, stackTrace) {
      logger.log('License Registration Error', e, stackTrace);
    }

    if (!isFdroidBuild &&
        !isUpdateChecked &&
        !offlineMode.value &&
        kReleaseMode) {
      Future.delayed(Duration.zero, () {
        checkAppUpdates();
        isUpdateChecked = true;
      });
    }
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      key: const ValueKey('main_app'), // Add stable key
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: appSupportedLocales,
      locale: languageSetting,
      theme: AppThemes.lightTheme(primaryColorSetting),
      darkTheme: AppThemes.darkTheme(primaryColorSetting),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: NavigationManager.instance.router,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initialisation();

  // Start the periodic timer.
  Timer.periodic(const Duration(hours: 12), (_) {
    TrendingService.updateTrendingVideos().catchError((e, s) {
      logger.log('Periodic Trending Update Error', e, s);
    });
  });

  try {
    await TrendingService.updateTrendingVideos();
  } catch (e, s) {
    logger.log('Initial Trending Update Error', e, s);
  }

  runApp(const AppEntry());
}

/// Entry widget that shows a (video) splash screen then launches the main app.
class AppEntry extends StatefulWidget {
  const AppEntry({Key? key}) : super(key: key);

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _splashDone = false;

  void _onSplashFinished() {
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DewMountainSplash(onFinish: _onSplashFinished),
      );
    }
    return const Musify();
  }
}

Future<void> initialisation() async {
  try {
    await Hive.initFlutter();

    final boxNames = ['settings', 'user', 'userNoBackup', 'cache'];

    for (final boxName in boxNames) {
      await Hive.openBox(boxName);
    }

    audioHandler = await AudioService.init(
      builder: MusifyAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sidh.dew',
        androidNotificationChannelName: 'Dew Music',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'drawable/ic_notification',
        androidShowNotificationBadge: true,
      ),
    );

    // Init router
    NavigationManager.instance;
  } catch (e, stackTrace) {
    logger.log('Initialization Error', e, stackTrace);
  }
}

class NavigationManager {
  static final NavigationManager _instance = NavigationManager._internal();

  factory NavigationManager() {
    return _instance;
  }

  NavigationManager._internal();

  static NavigationManager get instance => _instance;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavigationPage(child: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) =>
                    const SearchPage(), // Create this page
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'library',
                builder: (context, state) =>
                    const PlaylistPage(), // Create this page
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) =>
                    const SettingsPage(), // Create this page
              ),
            ],
          ),
        ],
      ),
      // Add standalone routes (not part of bottom nav)
      GoRoute(
        path: '/now-playing',
        name: 'now-playing',
        builder: (context, state) => const NowPlayingPage(),
      ),
    ],
  );
}
