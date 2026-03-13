import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/core/theme/aura_theme.dart';
import 'package:dew/features/home/presentation/home_page.dart';
import 'package:dew/features/home/presentation/main_shell.dart';
import 'package:dew/features/library/presentation/library_page.dart';
import 'package:dew/features/player/presentation/player_page.dart';
import 'package:dew/features/search/presentation/search_page.dart';
import 'package:dew/features/settings/presentation/settings_page.dart';
// import 'package:dew/firebase_options.dart';
import 'package:dew/generated/app_localizations.dart';
import 'package:dew/screens/chatroom_page.dart';
import 'package:dew/screens/chatroom_pre.dart';
import 'package:dew/screens/desktop/qr_login_screen.dart';
import 'package:dew/screens/device_management_screen.dart';
import 'package:dew/screens/friend_request.dart';
import 'package:dew/screens/login_page.dart';
import 'package:dew/screens/profile_page.dart';
import 'package:dew/screens/qr_scanner_screen.dart';
import 'package:dew/screens/register_page.dart';
import 'package:dew/services/audio_service.dart';
// import 'package:dew/services/cloud_sync_service.dart';
import 'package:dew/services/data_manager.dart';
// import 'package:dew/services/device_manager_service.dart';
import 'package:dew/services/logger_service.dart';
import 'package:dew/services/trending_service.dart';
import 'package:dew/services/update_manager.dart';
import 'package:dew/services/appwrite_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Global keys
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Global Audio Handler (Legacy Support)
late MusifyAudioHandler audioHandler;
bool audioHandlerInitialized = false;
final logger = Logger();

// Legacy Compatibility
bool isFdroidBuild = false;
final appLanguages = <String, String>{'English': 'en'};

class Musify {
  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    // No-op for now in Aura
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive system UI
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Appwrite Initialization
  AppwriteService().init();

  await initialisation();

  runZonedGuarded(() {
    runApp(const ProviderScope(child: AuraApp()));
  }, (error, stack) {
    logger.log('Unhandled error in runZonedGuarded', error, stack);
  });
}

Future<void> initialisation() async {
  try {
    await Hive.initFlutter();

    // Open necessary boxes
    await Hive.openBox('settings');
    await Hive.openBox('user');
    await Hive.openBox('userNoBackup');
    await Hive.openBox('cache');

    audioHandler = await AudioService.init(
      builder: MusifyAudioHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.sidh.dew',
        androidNotificationChannelName: 'Dew',
        androidNotificationOngoing: false,
        androidNotificationIcon: 'drawable/ic_notification',
        androidShowNotificationBadge: true,
        // Enhanced settings for smoother background playback
        androidStopForegroundOnPause: false,
        fastForwardInterval: Duration(seconds: 15),
        rewindInterval: Duration(seconds: 15),
        preloadArtwork: true,
      ),
    );
    audioHandlerInitialized = true;

    // Initial data fetch
    unawaited(TrendingService.updateTrendingVideos().catchError((e, s) {
      logger.log('Trending Update Error', e, s);
    }));

    // Restore last playback session
    await _restoreLastPlaybackSession();

    // Initialize cloud sync and device registration for logged-in users
    // await _initializeCloudServices();

    // Check for app updates (non-blocking)
    Future.delayed(const Duration(seconds: 2), checkAppUpdates);
  } catch (e, stackTrace) {
    logger.log('Initialization Error', e, stackTrace);
    rethrow;
  }
}

Future<void> _initializeCloudServices() async {
  try {
    /*
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) {
      // Initialize cloud sync
      await CloudSyncService().initialize();
      // Register device
      await DeviceManagerService().registerDevice();

      // Update device last active periodically
      Timer.periodic(const Duration(minutes: 5), (_) {
        DeviceManagerService().updateLastActive();
      });
    }

    // Listen for auth changes
    auth.authStateChanges().listen((user) async {
      if (user != null) {
        await CloudSyncService().initialize();
        await DeviceManagerService().registerDevice();
      }
    });
    */
    final user = await AppwriteService().account.get();
    if (user != null) {
      print('Appwrite User Logged in: ${user.$id}');
      // TODO: Re-enable these services after migration
      // await CloudSyncService().initialize();
      // await DeviceManagerService().registerDevice();
    }
  } catch (e) {
    logger.log('Cloud services init error', e, null);
  }
}

Future<void> _restoreLastPlaybackSession() async {
  try {
    final lastState = await getData('user', 'lastPlaybackState');
    if (lastState != null && lastState is Map) {
      final state = Map<String, dynamic>.from(lastState);

      final songDetails = {
        'ytid': state['songId'],
        'title': state['title'],
        'artist': state['artist'],
        'image': state['artUri'],
        'duration': state['duration'] ?? 0,
        'isOffline': state['isOffline'] ?? false,
      };

      if (state['extras'] != null) {
        if (state['extras'] is Map) {
          songDetails.addAll(Map<String, dynamic>.from(state['extras']));
        }
      }

      // Restore without auto-playing

      // 1. Instant UI Restore: Manually update mediaItem so MiniPlayer shows up immediately
      final restoredMediaItem = MediaItem(
        id: songDetails['ytid'].toString(),
        title: songDetails['title']?.toString() ?? 'Unknown Title',
        artist: songDetails['artist']?.toString() ?? 'Unknown Artist',
        artUri: songDetails['image'] != null
            ? Uri.tryParse(songDetails['image'].toString())
            : null,
        duration: Duration(milliseconds: state['duration'] as int? ?? 0),
        extras: Map<String, dynamic>.from(songDetails),
      );
      audioHandler.mediaItem.add(restoredMediaItem);

      // 2. Background Load: Fetch fresh URL and prepare player
      unawaited(audioHandler.playSong(songDetails, play: false).then((_) async {
        // Restore position after source is loaded
        final position = state['position'] as int? ?? 0;
        if (position > 0) {
          await audioHandler.seek(Duration(milliseconds: position));
        }
      }).catchError((e) {
        logger.log('Error preparing restored song', e, null);
      }));

      // 3. Preload Video URL: Start fetching now so it's ready when player opens
      final ytid = songDetails['ytid']?.toString();
      if (ytid != null && ytid.isNotEmpty) {
        unawaited(
            getVideoStreamUrl(ytid, targetQuality: 1080).then((streamInfo) {
          if (streamInfo != null) {
            final videoUrl = streamInfo['url'] as String?;
            if (videoUrl != null) {
              logger.log('Video URL prefetched for: $ytid', null, null);
            }
          }
        }).catchError((e) {
          // Non-critical, just log
          logger.log('Video prefetch failed:', e, null);
        }));
      }

      logger.log('Session restored: ${state['title']}', null, null);
    }
  } catch (e, stackTrace) {
    logger.log('Error restoring playback session', e, stackTrace);
  }
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aura Music',
      debugShowCheckedModeBanner: false,

      // Theme Configuration
      theme: AuraTheme.darkTheme,
      darkTheme: AuraTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],

      // Routing
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        // Home Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        // Search Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchPage(),
            ),
          ],
        ),
        // Library Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryPage(),
            ),
          ],
        ),
        // Profile Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    // Full screen routes
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/player',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const PlayerPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    ),
    // Social Routes (outside shell)
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/chatrooms',
      builder: (context, state) => const ChatroomPrePage(),
    ),
    GoRoute(
      path: '/chatroom/:id',
      builder: (context, state) {
        final roomId = state.pathParameters['id'] ?? '';
        return ChatroomPage(sessionId: roomId);
      },
    ),
    GoRoute(
      path: '/friend-requests',
      builder: (context, state) => const FriendListPage(),
    ),
    // PC App Routes
    GoRoute(
      path: '/scan-qr',
      builder: (context, state) => const QrScannerScreen(),
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const DeviceManagementScreen(),
    ),
    GoRoute(
      path: '/qr-login',
      builder: (context, state) => const QrLoginScreen(),
    ),
  ],
);
