import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/breathe_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../theme/app_theme.dart';
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
final GlobalKey<NavigatorState> _chatNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'chatNav');
final GlobalKey<NavigatorState> _profileNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profileNav');

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_jwt_token');
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/';
      if (token == null && !isAuthRoute) return '/login';
      return null;
    },
    routes: [
      // Entry point / splash route
      GoRoute(
        path: '/',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth & Onboarding routes
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),

      // App Shell Branch Navigation
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

          // Branch 4: MindChat conversational AI companion
          StatefulShellBranch(
            navigatorKey: _chatNavigatorKey,
            routes: [
              GoRoute(
                path: '/chat',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ChatScreen()),
              ),
            ],
          ),

          // Branch 5: Profile and sanctuary settings
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

/// A breathtaking entry loading splash screen that coordinates initial routing
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkRoutingGuard();
  }

  Future<void> _checkRoutingGuard() async {
    // Add a premium 1.2s delay to feel deliberate and present the brand
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    final token = prefs.getString('auth_jwt_token');

    if (!mounted) return;

    if (!onboardingCompleted) {
      context.go('/onboarding');
    } else if (token == null) {
      context.go('/login');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with premium Cyber-neon glow and typography
            Text(
              'mindtrack',
              style: theme.textTheme.displayMedium?.copyWith(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 42,
                letterSpacing: -0.8,
                shadows: [
                  Shadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Cosmic Emotional Pulse',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.0,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
