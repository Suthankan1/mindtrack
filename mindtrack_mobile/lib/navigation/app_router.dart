import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/breathe_screen.dart';
import '../screens/profile_screen.dart';
import 'bottom_nav_bar.dart';

// Navigator Keys for proper routing control
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'homeNav',
);
final GlobalKey<NavigatorState> _journalNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'journalNav');
final GlobalKey<NavigatorState> _breatheNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'breatheNav');
final GlobalKey<NavigatorState> _profileNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profileNav');

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: true,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            // Seamless integration of our animated sliding pill bottom bar
            bottomNavigationBar: CustomBottomNavBar(
              selectedIndex: navigationShell.currentIndex,
              onTap: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          );
        },
        branches: [
          // Branch 1: Home Screen
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),

          // Branch 2: Journal Entries with Charting
          StatefulShellBranch(
            navigatorKey: _journalNavigatorKey,
            routes: [
              GoRoute(
                path: '/journal',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: JournalScreen()),
              ),
            ],
          ),

          // Branch 3: Breathing animations guide
          StatefulShellBranch(
            navigatorKey: _breatheNavigatorKey,
            routes: [
              GoRoute(
                path: '/breathe',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: BreatheScreen()),
              ),
            ],
          ),

          // Branch 4: Profile and sanctuary settings
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
