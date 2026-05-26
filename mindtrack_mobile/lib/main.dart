// MindTrack Mobile — Flutter app for daily mood check-ins and breathing exercises. SDG 3 Good Health and Well-being.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

import 'services/notification_service.dart';

void main() async {
  // Ensure that Flutter widget bindings are initialized before starting any platform channels (like Shared Preferences or Local Notifications)
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  runApp(
    // ProviderScope stores the state of all Riverpod providers
    const ProviderScope(child: MindTrackApp()),
  );
}

class MindTrackApp extends ConsumerWidget {
  const MindTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamically watch the themeProvider state managed by Riverpod
    final activeTheme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'MindTrack Mobile',
      debugShowCheckedModeBanner: false,

      // Inject the Cosmic Calm theme
      theme: activeTheme,

      // Inject go_router configuration
      routerConfig: AppRouter.router,
    );
  }
}
