import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/config/firebase_config.dart';
import 'core/constants/app_strings.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/artwork_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';

import 'data/datasources/local_storage_datasource.dart';
import 'data/datasources/youtube_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/music_repository_impl.dart';
import 'data/repositories/youtube_repository_impl.dart';

import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/music_repository.dart';
import 'domain/repositories/youtube_repository.dart';

import 'presentation/navigation/app_router.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/download_provider.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/providers/playlist_provider.dart';
import 'presentation/providers/search_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run independent initialization tasks concurrently to minimize cold-start latency
  String apiKey = '';
  await Future.wait([
    LocalStorageService.init(),
    () async {
      try {
        final configString = await rootBundle.loadString('assets/config/app_config.json');
        final Map<String, dynamic> configJson = jsonDecode(configString);
        apiKey = configJson['youtubeApiKey'] as String? ?? '';
        final fbApiKey = configJson['firebaseApiKey'] as String?;
        final fbProjectId = configJson['firebaseProjectId'] as String?;
        FirebaseConfig.init(customApiKey: fbApiKey, customProjectId: fbProjectId);
      } catch (e) {
        AppLogger.error('Could not load assets/config/app_config.json, falling back to defaults', e);
      }
    }(),
    () async {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await JustAudioBackground.init(
            androidNotificationChannelId: 'com.twilight.music.audio',
            androidNotificationChannelName: 'Twilight Music',
            androidNotificationChannelDescription: 'Twilight Music playback controls',
            // Keep foreground service notification active to prevent Android OS background termination
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: false,
            androidShowNotificationBadge: true,
            // Strictly monochrome white-on-transparent vector status bar icon
            androidNotificationIcon: 'drawable/ic_stat_music',
            notificationColor: const Color(0xFF6C63FF),
            preloadArtwork: true,
          );
          AppLogger.info('JustAudioBackground initialized successfully');
        } catch (e) {
          AppLogger.info('JustAudioBackground init skipped or failed: $e');
        }
      }
    }(),
  ]);

  // Defer non-critical notification fallback logo extraction until after first frame paints
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ArtworkService.getAppLogoFilePath();
    });
  }

  // Setup Dependency Injection Layer
  final httpClient = http.Client();
  final ytRemoteDatasource = YouTubeRemoteDatasource(client: httpClient, apiKey: apiKey);
  final localDatasource = LocalStorageDatasource();

  final YouTubeRepository youtubeRepository = YouTubeRepositoryImpl(remoteDatasource: ytRemoteDatasource);
  final MusicRepository musicRepository = MusicRepositoryImpl(localDatasource: localDatasource);
  final AuthRepository authRepository = AuthRepositoryImpl();

  runApp(
    MultiProvider(
      providers: [
        // Repository Providers
        Provider<YouTubeRepository>.value(value: youtubeRepository),
        Provider<MusicRepository>.value(value: musicRepository),
        Provider<AuthRepository>.value(value: authRepository),

        // Presentation State Providers
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (_) => DownloadProvider(),
        ),
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => PlayerProvider(musicRepository: musicRepository),
        ),
        ChangeNotifierProvider<PlaylistProvider>(
          create: (_) => PlaylistProvider(musicRepository: musicRepository),
        ),
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider(
            youtubeRepository: youtubeRepository,
            musicRepository: musicRepository,
          ),
        ),
      ],
      child: const TwilightApp(),
    ),
  );
}

class TwilightApp extends StatelessWidget {
  const TwilightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const MainNavigationScreen(),
    );
  }
}
