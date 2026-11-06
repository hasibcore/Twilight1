import 'package:flutter/material.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/player/full_player_screen.dart';
import '../screens/player/queue_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/auth/auth_screen.dart';

class AppRouter {
  AppRouter._();

  static const String main = '/';
  static const String search = '/search';
  static const String fullPlayer = '/player';
  static const String queue = '/queue';
  static const String settings = '/settings';
  static const String auth = '/auth';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case main:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case fullPlayer:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const FullPlayerScreen(),
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(anim),
              child: child,
            );
          },
        );
      case queue:
        return MaterialPageRoute(builder: (_) => const QueueScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case auth:
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      default:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
    }
  }
}
