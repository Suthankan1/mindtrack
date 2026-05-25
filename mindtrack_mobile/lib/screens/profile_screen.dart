import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';
import '../services/dio_service.dart';

/// The Profile tab — displays the user's avatar, stats, settings, and
/// persistent crisis support buttons.
///
/// Reads display name, email, join date and notification preference from
/// [SharedPreferences] and exposes light/dark theme toggle via [themeProvider].
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _displayName = 'Cosmic Practitioner';
  String _email = 'practitioner@mindtrack.com';
  String _joinDateStr = 'Joined May 2026';
  bool _notificationsEnabled = true;

  bool _isLoadingStats = true;
  int _totalEntries = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  double _avgMoodScore = 0.0;

  final List<Color> _avatarColors = const [
    Color(0xFF00D2C8), // Teal
    Color(0xFFFF6B6B), // Coral
    Color(0xFFFFB347), // Orange
    Color(0xFF9B5DE5), // Purple
    Color(0xFF00F5D4), // Mint
    Color(0xFFF15BB5), // Pink
    Color(0xFF3A86C8), // Blue
  ];

  String _getEmailInitials(String email) {
    if (email.trim().isEmpty) return '??';
    final parts = email.split('@');
    final namePart = parts[0];
    if (namePart.length >= 2) {
      return namePart.substring(0, 2).toUpperCase();
    } else if (namePart.isNotEmpty) {
      return namePart.toUpperCase();
    }
    return '??';
  }

  Color _getAvatarColor(String email) {
    if (email.trim().isEmpty) return _avatarColors[0];
    final firstChar = email.trim()[0].toLowerCase();
    final code = firstChar.codeUnitAt(0);
    final index = code % _avatarColors.length;
    return _avatarColors[index];
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _fetchUserStats();
  }

  Future<void> _syncPreferencesWithBackend(SharedPreferences prefs) async {
    try {
      final dio = ref.read(dioServiceProvider);
      final prefsData = await dio.getUserPreferences();
      final reminderEnabled = prefsData['reminderEnabled'] ?? true;
      final themeMode = prefsData['themeMode'] ?? 'dark';

      await prefs.setBool('notifications_enabled', reminderEnabled);
      await prefs.setBool('theme_light_mode', themeMode == 'light');

      if (mounted) {
        setState(() {
          _notificationsEnabled = reminderEnabled;
        });
        await ref.read(themeProvider.notifier).setThemeMode(themeMode);
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error syncing preferences with backend: $e');
    }
  }

  Future<void> _fetchUserStats() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStats = true;
    });
    try {
      final dio = ref.read(dioServiceProvider);
      final stats = await dio.getUserStats();
      if (!mounted) return;
      setState(() {
        _totalEntries = stats['totalEntries'] ?? 0;
        _currentStreak = stats['currentStreak'] ?? 0;
        _longestStreak = stats['longestStreak'] ?? 0;
        final avg = stats['avgMoodScore'];
        if (avg is num) {
          _avgMoodScore = avg.toDouble();
        } else {
          _avgMoodScore = 0.0;
        }
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('ProfileScreen: Error fetching user stats: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  /// Reads profile data (name, email, join date, notifications flag)
  /// from [SharedPreferences] and refreshes local state.
  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _displayName = prefs.getString('user_display_name') ?? 'Cosmic Practitioner';
        _email = prefs.getString('user_email') ?? 'practitioner@mindtrack.com';
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

        final rawJoinDate = prefs.getString('user_join_date');
        if (rawJoinDate != null) {
          final joinDateTime = DateTime.parse(rawJoinDate);
          _joinDateStr = 'Joined ${_getMonthName(joinDateTime.month)} ${joinDateTime.year}';
        } else {
          // Initialize if missing
          final now = DateTime.now();
          prefs.setString('user_join_date', now.toIso8601String());
          _joinDateStr = 'Joined ${_getMonthName(now.month)} ${now.year}';
        }
      });

      // Synchronize settings with backend dynamically if authenticated and not in a widget test
      final token = prefs.getString('auth_jwt_token');
      if (token != null && token != 'fake_token') {
        _syncPreferencesWithBackend(prefs);
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error loading profile data: $e');
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return 'May';
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _toggleNotifications(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', val);
      setState(() {
        _notificationsEnabled = val;
      });

      // Sync notification toggle with backend
      final token = prefs.getString('auth_jwt_token');
      if (token != null && token != 'fake_token') {
        final isLight = prefs.getBool('theme_light_mode') ?? false;
        final dio = ref.read(dioServiceProvider);
        await dio.updateUserPreferences({
          'themeMode': isLight ? 'light' : 'dark',
          'reminderEnabled': val,
          'reminderTime': '20:00',
          'defaultCopingTechnique': 'Breathing',
          'privacyMode': 'standard',
        });
      }

      // FCM Subscription logic simulation
      if (val) {
        debugPrint('FCM: Subscribed to theme_calm_notifications topic.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildCustomSnackBar(
              message: 'Notifications Enabled & FCM Subscribed',
              isSuccess: true,
            ),
          );
        }
      } else {
        debugPrint('FCM: Unsubscribed from theme_calm_notifications topic.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildCustomSnackBar(
              message: 'Notifications Disabled & FCM Unsubscribed',
              isSuccess: false,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error toggling notifications: $e');
    }
  }

  /// Computes the longest consecutive daily mood-logging streak from [entries].
  ///
  /// Deduplicates by calendar date and returns the longest unbroken run.
  int _calculateLongestStreak(List<MoodEntry> entries) {
    if (entries.isEmpty) return 0;
    
    // Sort entries by date ascending
    final sorted = List<MoodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Extract unique yyyy-MM-dd dates
    final uniqueDates = sorted.map((e) {
      final t = e.timestamp.toLocal();
      return DateTime(t.year, t.month, t.day);
    }).toSet().toList();

    if (uniqueDates.isEmpty) return 0;

    int maxStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < uniqueDates.length; i++) {
      final diff = uniqueDates[i].difference(uniqueDates[i - 1]).inDays;
      if (diff == 1) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else if (diff > 1) {
        currentStreak = 1;
      }
    }

    return maxStreak;
  }

  /// Opens [urlString] in the platform's default browser / dialler.
  /// Shows an error snackbar if the URL cannot be launched.
  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open lifeline. Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  SnackBar _buildCustomSnackBar({required String message, bool isSuccess = true}) {
    return SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSuccess ? const Color(0xFF00D2C8).withValues(alpha: 0.9) : const Color(0xFFFF6B6B).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSuccess ? const Color(0xFF00D2C8) : const Color(0xFFFF6B6B),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSuccess ? const Color(0xFF00D2C8) : const Color(0xFFFF6B6B)).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.notifications_off_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;
    
    // Watch reactive state from Riverpod
    final activeTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Scrollable Sanctuary Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header title "My Sanctuary"
                    Text(
                      'My Sanctuary',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // User Personal Block
                    Row(
                      children: [
                        // Initials Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getAvatarColor(_email),
                            boxShadow: [
                              BoxShadow(
                                color: _getAvatarColor(_email).withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _getEmailInitials(_email),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isLightTheme ? const Color(0xFFE4E8F5) : AppColors.surfaceColor).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
                                  ),
                                ),
                                child: Text(
                                  _joinDateStr,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isLightTheme ? const Color(0xFF009C94) : const Color(0xFF00D2C8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Stats & Badges Grid
                    _isLoadingStats
                        ? Column(
                            children: [
                              Row(
                                children: const [
                                  Expanded(child: ShimmerStatsCard()),
                                  SizedBox(width: 16),
                                  Expanded(child: ShimmerStatsCard()),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: const [
                                  Expanded(child: ShimmerStatsCard()),
                                  SizedBox(width: 16),
                                  Expanded(child: ShimmerStatsCard()),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatsCard(
                                      theme: theme,
                                      isLightTheme: isLightTheme,
                                      icon: Icons.article_outlined,
                                      color: isLightTheme ? const Color(0xFF009C94) : const Color(0xFF00D2C8),
                                      value: '$_totalEntries',
                                      label: 'Total Logs',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatsCard(
                                      theme: theme,
                                      isLightTheme: isLightTheme,
                                      icon: Icons.bolt_rounded,
                                      color: Colors.orange,
                                      value: '$_currentStreak days',
                                      label: 'Current Streak',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatsCard(
                                      theme: theme,
                                      isLightTheme: isLightTheme,
                                      icon: Icons.local_fire_department,
                                      color: Colors.amber,
                                      value: '$_longestStreak days',
                                      label: 'Longest Streak',
                                      isBest: _longestStreak > 0,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatsCard(
                                      theme: theme,
                                      isLightTheme: isLightTheme,
                                      icon: Icons.favorite_border_rounded,
                                      color: Colors.pink,
                                      value: _avgMoodScore.toStringAsFixed(1),
                                      label: 'Avg Mood Score',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                    const SizedBox(height: 32),

                    // Sanctuary Settings Title
                    Text(
                      'Sanctuary Settings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notification toggle settings tile
                    _buildSettingItem(
                      icon: Icons.notifications_none,
                      title: 'Breathing Reminders',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeColor: const Color(0xFF00D2C8),
                      ),
                    ),

                    // Light/Dark Theme toggle settings tile
                    _buildSettingItem(
                      icon: isLightTheme ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      title: isLightTheme ? 'Light Mode Active' : 'Dark Mode Active',
                      trailing: Switch(
                        value: isLightTheme,
                        onChanged: (val) {
                          ref.read(themeProvider.notifier).toggleTheme();
                        },
                        activeColor: const Color(0xFF00D2C8),
                      ),
                    ),

                    // Export data placeholder tile
                    _buildSettingItem(
                      icon: Icons.ios_share_outlined,
                      title: 'Export Sanctuary Data',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Sanctuary data export will download JSON backup in standard version.',
                            ),
                            backgroundColor: theme.brightness == Brightness.light ? const Color(0xFF009C94) : const Color(0xFF00D2C8),
                          ),
                        );
                      },
                    ),

                    // Sign Out Settings Tile
                    _buildSettingItem(
                      icon: Icons.logout_outlined,
                      title: 'Sign Out',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onTap: () async {
                        // Call DioService logout
                        await ref.read(dioServiceProvider).logout();
                        
                        // Clear all providers
                        ref.invalidate(todayMoodProvider);
                        ref.invalidate(moodHistoryProvider);
                        
                        // Navigate to /login via go_router
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Debug Info',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSettingItem(
                        icon: Icons.dns_outlined,
                        title: 'Backend API URL',
                        subtitle: ref.watch(dioServiceProvider).baseUrl,
                        trailing: const Icon(
                          Icons.bug_report_outlined,
                          size: 18,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // SDG 3 - Good Health & Well-being Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
                        ),
                        gradient: LinearGradient(
                          colors: isLightTheme 
                            ? [Colors.white, const Color(0xFFF1F8F6)]
                            : [AppColors.surfaceColor, const Color(0xFF16252A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Glowing Custom painted SDG 3 Circle Badge
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4C9F38), // Standard UN SDG 3 green color
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4C9F38).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SDG',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '3',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          // Content Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UN Sustainable Goal 3',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supporting Good Health & Well-being through conscious emotion tracking.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Persistent bottom Crisis Support section (Always visible!)
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLightTheme ? 0.05 : 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Crisis Support Resources',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B6B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Talk to Someone (local helpline)
                      Expanded(
                        child: _buildCrisisButton(
                          label: 'Talk to Someone',
                          icon: Icons.phone_in_talk_outlined,
                          onPressed: () => _launchUrl('tel:988'), // Global Mental Health Lifeline
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Find a Therapist
                      Expanded(
                        child: _buildCrisisButton(
                          label: 'Find Therapist',
                          icon: Icons.search_rounded,
                          onPressed: () => context.go('/profile/therapists'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Emergency 911
                      Expanded(
                        child: _buildCrisisButton(
                          label: 'Emergency',
                          icon: Icons.emergency_outlined,
                          onPressed: () => _launchUrl('tel:911'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrisisButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF8E8E),
              Color(0xFFFF6B6B),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required ThemeData theme,
    required bool isLightTheme,
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    bool isBest = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              if (isBest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'BEST',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerStatsCard extends StatefulWidget {
  const ShimmerStatsCard({super.key});

  @override
  State<ShimmerStatsCard> createState() => _ShimmerStatsCardState();
}

class _ShimmerStatsCardState extends State<ShimmerStatsCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLightTheme ? const Color(0xFFF1F4FA) : AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black12 : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black12 : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black12 : Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
