import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
}

/// Modernized Riverpod 3.x Notifier to manage active theme state
class ThemeNotifier extends Notifier<ThemeData> {
  @override
  ThemeData build() {
    // Return the initial state
    return AppTheme.cosmicCalm;
  }

  /// Toggle or apply a custom theme state (supports expansions later)
  void setCosmicCalm() {
    state = AppTheme.cosmicCalm;
  }
}

/// Modernized Riverpod 3.x NotifierProvider for active ThemeData
final themeProvider = NotifierProvider<ThemeNotifier, ThemeData>(ThemeNotifier.new);
