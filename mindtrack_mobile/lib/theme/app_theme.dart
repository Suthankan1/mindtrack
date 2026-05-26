import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dio_service.dart';

/// Cosmic Calm theme colors
class AppColors {
  static const Color backgroundColor = Color(0xFF0A0A14);
  static const Color surfaceColor = Color(0xFF12122A);
  static const Color primaryColor = Color(0xFF00D2C8);
  static const Color errorColor = Color(0xFFFF6B6B);

  static const Color navBarBackground = Color(0xFF1C1C3A);
  static const Color navBarUnselected = Color(0xFF6B6B9A);

  // Auxiliary styles for visual depth
  static const Color textMuted = Color(0xFF8B8BBA);
  static const Color borderOverlay = Color(0xFF23234A);
}

/// Cosmic Calm theme styling configuration
class AppTheme {
  static ThemeData get cosmicCalm {
    // Start with Google Fonts DM Sans for the base dark text theme
    final baseTextTheme = GoogleFonts.dmSansTextTheme(
      ThemeData.dark().textTheme,
    );

    // Customize the typography, overriding major display and headline sizes with Clash Display
    final customizedTextTheme = baseTextTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      ),
      displaySmall: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundColor,
      primaryColor: AppColors.primaryColor,
      cardColor: AppColors.surfaceColor,
      dividerColor: AppColors.borderOverlay,

      colorScheme: const ColorScheme.dark(
        surface: AppColors.surfaceColor,
        primary: AppColors.primaryColor,
        error: AppColors.errorColor,
        onSurface: Colors.white,
        onPrimary: AppColors.backgroundColor,
      ),

      textTheme: customizedTextTheme,

      // Premium card theme matching surfaceColor, modernized to CardThemeData
      cardTheme: const CardThemeData(
        color: AppColors.surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.borderOverlay, width: 1),
        ),
      ),

      // Bottom navigation theme settings (fallback)
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navBarBackground,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.navBarUnselected,
        elevation: 8,
      ),
    );
  }

  static ThemeData get cosmicCalmLight {
    final baseTextTheme = GoogleFonts.dmSansTextTheme(
      ThemeData.light().textTheme,
    );

    final customizedTextTheme = baseTextTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        color: Color(0xFF0A0A14),
      ),
      displayMedium: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        color: Color(0xFF0A0A14),
      ),
      displaySmall: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        color: Color(0xFF0A0A14),
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: Color(0xFF0A0A14),
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        color: Color(0xFF0A0A14),
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        color: Color(0xFF0A0A14),
      ),
      titleLarge: const TextStyle(
        fontFamily: 'ClashDisplay',
        fontWeight: FontWeight.w500,
        color: Color(0xFF0A0A14),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F6FC),
      primaryColor: const Color(0xFF009C94),
      cardColor: const Color(0xFFFFFFFF),
      dividerColor: const Color(0xFFE0E4F2),

      colorScheme: const ColorScheme.light(
        surface: Color(0xFFFFFFFF),
        primary: Color(0xFF009C94),
        error: Color(0xFFFF4D4D),
        onSurface: Color(0xFF0A0A14),
        onPrimary: Colors.white,
      ),

      textTheme: customizedTextTheme,

      cardTheme: const CardThemeData(
        color: Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE0E4F2), width: 1),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFE4E8F5),
        selectedItemColor: Color(0xFF009C94),
        unselectedItemColor: Color(0xFF8B8BBA),
        elevation: 8,
      ),
    );
  }
}

/// Modernized Riverpod 3.x Notifier to manage active theme state
class ThemeNotifier extends Notifier<ThemeData> {
  @override
  ThemeData build() {
    _loadTheme();
    // Return standard dark theme on synchronous build to avoid splash flicker
    return AppTheme.cosmicCalm;
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLight = prefs.getBool('theme_light_mode') ?? false;
      if (isLight) {
        state = AppTheme.cosmicCalmLight;
      } else {
        state = AppTheme.cosmicCalm;
      }
    } catch (e) {
      debugPrint('ThemeNotifier: Failed to load theme preference: $e');
    }
  }

  /// Explicitly set theme mode (light/dark) from synced data or local cache
  Future<void> setThemeMode(String themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (themeMode == 'light') {
        state = AppTheme.cosmicCalmLight;
        await prefs.setBool('theme_light_mode', true);
      } else {
        state = AppTheme.cosmicCalm;
        await prefs.setBool('theme_light_mode', false);
      }
    } catch (e) {
      debugPrint('ThemeNotifier: Failed to set theme mode: $e');
    }
  }

  /// Toggle between Dark and Light mode, persisting preference in SharedPreferences
  /// and syncing with Spring Boot if authenticated.
  Future<void> toggleTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLight = state.brightness == Brightness.light;
      final newTheme = isLight ? 'dark' : 'light';

      if (isLight) {
        state = AppTheme.cosmicCalm;
        await prefs.setBool('theme_light_mode', false);
      } else {
        state = AppTheme.cosmicCalmLight;
        await prefs.setBool('theme_light_mode', true);
      }

      // Check if user is authenticated and sync
      final token = prefs.getString('auth_jwt_token');
      if (token != null && token != 'fake_token') {
        final dio = ref.read(dioServiceProvider);
        final reminderEnabled = prefs.getBool('notifications_enabled') ?? true;
        final reminderTimeStr = prefs.getString('reminder_time') ?? '20:00';
        await dio.updateUserPreferences({
          'themeMode': newTheme,
          'reminderEnabled': reminderEnabled,
          'reminderTime': reminderTimeStr,
          'defaultCopingTechnique': 'Breathing',
          'privacyMode': 'standard',
        });
      }
    } catch (e) {
      debugPrint('ThemeNotifier: Failed to save theme preference: $e');
    }
  }

  void setCosmicCalm() {
    state = AppTheme.cosmicCalm;
  }
}

/// Modernized Riverpod 3.x NotifierProvider for active ThemeData
final themeProvider = NotifierProvider<ThemeNotifier, ThemeData>(
  ThemeNotifier.new,
);
