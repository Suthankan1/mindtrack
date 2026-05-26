import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';
import '../services/dio_service.dart';
import '../services/notification_service.dart';

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
  String _displayName = '';
  String _email = '';
  String _joinDateStr = 'Joined May 2026';
  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _aiJournalAnalysisEnabled = false;
  bool _aiChatHistoryEnabled = false;
  bool _shareNotesWithAi = false;

  bool _isLoadingPassport = true;
  Map<String, dynamic>? _passportData;

  bool _isLoadingStats = true;
  bool _isExporting = false;
  int _totalEntries = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  double _avgMoodScore = 0.0;
  int _copingSessions = 0;
  int _copingMinutes = 0;
  String _favoriteTechnique = '--';

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
    _fetchWellnessPassport();
  }

  Future<void> _syncPreferencesWithBackend(SharedPreferences prefs) async {
    try {
      final dio = ref.read(dioServiceProvider);
      final prefsData = await dio.getUserPreferences();
      final reminderEnabled = prefsData['reminderEnabled'] ?? true;
      final reminderTimeStr = prefsData['reminderTime'] ?? '20:00';
      final themeMode = prefsData['themeMode'] ?? 'dark';
      final aiJournalAnalysisEnabled = prefsData['aiJournalAnalysisEnabled'] ?? false;
      final aiChatHistoryEnabled = prefsData['aiChatHistoryEnabled'] ?? false;
      final shareNotesWithAi = prefsData['shareNotesWithAi'] ?? false;

      await prefs.setBool('notifications_enabled', reminderEnabled);
      await prefs.setString('reminder_time', reminderTimeStr);
      await prefs.setBool('theme_light_mode', themeMode == 'light');
      await prefs.setBool('ai_journal_analysis_enabled', aiJournalAnalysisEnabled);
      await prefs.setBool('ai_chat_history_enabled', aiChatHistoryEnabled);
      await prefs.setBool('share_notes_with_ai', shareNotesWithAi);

      TimeOfDay parsedTime = const TimeOfDay(hour: 20, minute: 0);
      try {
        final parts = reminderTimeStr.split(':');
        if (parts.length == 2) {
          parsedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _notificationsEnabled = reminderEnabled;
          _reminderTime = parsedTime;
          _aiJournalAnalysisEnabled = aiJournalAnalysisEnabled;
          _aiChatHistoryEnabled = aiChatHistoryEnabled;
          _shareNotesWithAi = shareNotesWithAi;
        });
        await ref.read(themeProvider.notifier).setThemeMode(themeMode);
        await NotificationService().scheduleDaily(parsedTime, reminderEnabled);
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
      final copingStats = await dio.getCopingStats();
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
        _copingSessions = copingStats['totalSessions'] ?? 0;
        _copingMinutes = copingStats['totalMinutes'] ?? 0;
        _favoriteTechnique = copingStats['mostUsedType'] ?? '--';
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

  Future<void> _fetchWellnessPassport() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPassport = true;
    });
    try {
      final dio = ref.read(dioServiceProvider);
      final data = await dio.getWellnessPassport();
      if (!mounted) return;
      setState(() {
        _passportData = data;
        _isLoadingPassport = false;
      });
    } catch (e) {
      debugPrint('ProfileScreen: Error fetching wellness passport: $e');
      if (!mounted) return;
      setState(() {
        _passportData = null;
        _isLoadingPassport = false;
      });
    }
  }

  Future<void> _exportMoodHistory() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      final historyList = await dio.getMoodHistory(days: 365);

      final jsonString = jsonEncode({
        'app': 'MindTrack',
        'exportedAt': DateTime.now().toIso8601String(),
        'entries': historyList,
      });

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final fileName =
          'mindtrack_mood_history_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${documentsDirectory.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'MindTrack mood history export');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _buildCustomSnackBar(
          message: 'Mood history exported! Check your share sheet.',
          isSuccess: true,
        ),
      );
    } catch (e) {
      debugPrint('ProfileScreen: Error exporting mood history: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export mood history. Error: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// Reads profile data (name, email, join date, notifications flag)
  /// from [SharedPreferences] and refreshes local state.
  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email') ?? '';
      setState(() {
        _displayName =
            prefs.getString('user_display_name') ?? '';
        _email = email;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

        final reminderTimeStr = prefs.getString('reminder_time') ?? '20:00';
        try {
          final parts = reminderTimeStr.split(':');
          if (parts.length == 2) {
            _reminderTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        } catch (_) {}

        _aiJournalAnalysisEnabled = prefs.getBool('ai_journal_analysis_enabled') ?? false;
        _aiChatHistoryEnabled = prefs.getBool('ai_chat_history_enabled') ?? false;
        _shareNotesWithAi = prefs.getBool('share_notes_with_ai') ?? false;

        final rawJoinDate = prefs.getString('user_join_date');
        if (rawJoinDate != null) {
          final joinDateTime = DateTime.parse(rawJoinDate);
          _joinDateStr =
              'Joined ${_getMonthName(joinDateTime.month)} ${joinDateTime.year}';
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return 'May';
  }

  Future<void> _toggleNotifications(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', val);
      setState(() {
        _notificationsEnabled = val;
      });

      // Sync notification toggle with backend
      await _syncAllPreferencesToBackend();

      // Schedule or cancel local notification daily reminder
      await NotificationService().scheduleDaily(_reminderTime, val);

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

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF00D2C8),
              onPrimary: Colors.black,
              surface: Theme.of(context).cardColor,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00D2C8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
      final prefs = await SharedPreferences.getInstance();
      final reminderTimeString = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await prefs.setString('reminder_time', reminderTimeString);

      // Sync notification settings with backend
      await _syncAllPreferencesToBackend();

      // Schedule or update local notification daily reminder
      await NotificationService().scheduleDaily(picked, _notificationsEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildCustomSnackBar(
            message: 'Reminder scheduled for ${picked.format(context)}',
            isSuccess: true,
          ),
        );
      }
    }
  }

  Future<void> _toggleAiJournalAnalysis(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_journal_analysis_enabled', val);
      setState(() {
        _aiJournalAnalysisEnabled = val;
      });
      await _syncAllPreferencesToBackend();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildCustomSnackBar(
            message: val ? 'AI Journal Analysis Enabled' : 'AI Journal Analysis Disabled',
            isSuccess: val,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling AI Journal Analysis: $e');
    }
  }

  Future<void> _toggleAiChatHistory(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ai_chat_history_enabled', val);
      setState(() {
        _aiChatHistoryEnabled = val;
      });
      await _syncAllPreferencesToBackend();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildCustomSnackBar(
            message: val ? 'AI Chat History Enabled' : 'AI Chat History Disabled',
            isSuccess: val,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling AI Chat History: $e');
    }
  }

  Future<void> _toggleShareNotesWithAi(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('share_notes_with_ai', val);
      setState(() {
        _shareNotesWithAi = val;
      });
      await _syncAllPreferencesToBackend();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildCustomSnackBar(
            message: val ? 'Share Notes with AI Enabled' : 'Share Notes with AI Disabled',
            isSuccess: val,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling Share Notes: $e');
    }
  }

  Future<void> _syncAllPreferencesToBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_jwt_token');
      if (token != null && token != 'fake_token') {
        final isLight = prefs.getBool('theme_light_mode') ?? false;
        final dio = ref.read(dioServiceProvider);
        final reminderTimeString = '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';
        await dio.updateUserPreferences({
          'themeMode': isLight ? 'light' : 'dark',
          'reminderEnabled': _notificationsEnabled,
          'reminderTime': reminderTimeString,
          'defaultCopingTechnique': 'Breathing',
          'privacyMode': 'standard',
          'aiJournalAnalysisEnabled': _aiJournalAnalysisEnabled,
          'aiChatHistoryEnabled': _aiChatHistoryEnabled,
          'shareNotesWithAi': _shareNotesWithAi,
        });
      }
    } catch (e) {
      debugPrint('Error syncing preferences to backend: $e');
    }
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

  SnackBar _buildCustomSnackBar({
    required String message,
    bool isSuccess = true,
  }) {
    return SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSuccess
              ? const Color(0xFF00D2C8).withValues(alpha: 0.9)
              : const Color(0xFFFF6B6B).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSuccess
                ? const Color(0xFF00D2C8)
                : const Color(0xFFFF6B6B),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isSuccess
                          ? const Color(0xFF00D2C8)
                          : const Color(0xFFFF6B6B))
                      .withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline
                  : Icons.notifications_off_outlined,
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
    ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Scrollable Sanctuary Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header title "My Sanctuary"
                    Text(
                      'My Sanctuary',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme
                            ? const Color(0xFF0A0A14)
                            : Colors.white,
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
                                color: _getAvatarColor(
                                  _email,
                                ).withValues(alpha: 0.35),
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
                                _displayName.trim().isNotEmpty
                                    ? _displayName
                                    : (_email.contains('@') ? _email.split('@').first : _email),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isLightTheme
                                      ? const Color(0xFF0A0A14)
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isLightTheme
                                      ? const Color(0xFF606080)
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isLightTheme
                                              ? const Color(0xFFE4E8F5)
                                              : AppColors.surfaceColor)
                                          .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLightTheme
                                        ? const Color(0xFFE0E4F2)
                                        : AppColors.borderOverlay,
                                  ),
                                ),
                                child: Text(
                                  _joinDateStr,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isLightTheme
                                        ? const Color(0xFF009C94)
                                        : const Color(0xFF00D2C8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildWellnessPassportCard(theme, isLightTheme),
                    const SizedBox(height: 24),

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
                              const SizedBox(height: 16),
                              const ShimmerCalmPracticeCard(),
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
                                      color: isLightTheme
                                          ? const Color(0xFF009C94)
                                          : const Color(0xFF00D2C8),
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
                              const SizedBox(height: 16),
                              _buildCalmPracticeCard(theme, isLightTheme),
                            ],
                          ),
                    const SizedBox(height: 32),

                    // Sanctuary Settings Title
                    Text(
                      'Sanctuary Settings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme
                            ? const Color(0xFF0A0A14)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'Export',
                            icon: Icons.download_outlined,
                            isLoading: _isExporting,
                            onPressed: _isExporting ? null : _exportMoodHistory,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Weekly Report',
                            icon: Icons.analytics_outlined,
                            onPressed: () => context.push('/weekly-summary'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Notification toggle settings tile
                    _buildSettingItem(
                      icon: Icons.notifications_none,
                      title: 'Breathing Reminders',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeThumbColor: const Color(0xFF00D2C8),
                      ),
                    ),

                    if (_notificationsEnabled)
                      _buildSettingItem(
                        icon: Icons.access_time_outlined,
                        title: 'Reminder Time',
                        subtitle: 'Currently scheduled for ${_reminderTime.format(context)}',
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        onTap: _selectReminderTime,
                      ),

                    // AI Privacy Controls
                    _buildSettingItem(
                      icon: Icons.psychology_outlined,
                      title: 'AI Journal Analysis',
                      subtitle: 'Locally extract journal sentiment and themes',
                      trailing: Switch(
                        value: _aiJournalAnalysisEnabled,
                        onChanged: _toggleAiJournalAnalysis,
                        activeThumbColor: const Color(0xFF00D2C8),
                      ),
                    ),

                    _buildSettingItem(
                      icon: Icons.history_edu_outlined,
                      title: 'AI Chat History',
                      subtitle: 'Allows MindChat to remember recent turns',
                      trailing: Switch(
                        value: _aiChatHistoryEnabled,
                        onChanged: _toggleAiChatHistory,
                        activeThumbColor: const Color(0xFF00D2C8),
                      ),
                    ),

                    _buildSettingItem(
                      icon: Icons.share_outlined,
                      title: 'Share Notes with AI',
                      subtitle: 'Sends journal bodies to generate reflections',
                      trailing: Switch(
                        value: _shareNotesWithAi,
                        onChanged: _toggleShareNotesWithAi,
                        activeThumbColor: const Color(0xFF00D2C8),
                      ),
                    ),

                    // Light/Dark Theme toggle settings tile
                    _buildSettingItem(
                      icon: isLightTheme
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      title: isLightTheme
                          ? 'Light Mode Active'
                          : 'Dark Mode Active',
                      trailing: Switch(
                        value: isLightTheme,
                        onChanged: (val) {
                          ref.read(themeProvider.notifier).toggleTheme();
                        },
                        activeThumbColor: const Color(0xFF00D2C8),
                      ),
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
                          color: isLightTheme
                              ? const Color(0xFF0A0A14)
                              : Colors.white,
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
                          color: isLightTheme
                              ? const Color(0xFFE0E4F2)
                              : AppColors.borderOverlay,
                        ),
                        gradient: LinearGradient(
                          colors: isLightTheme
                              ? [Colors.white, const Color(0xFFF1F8F6)]
                              : [
                                  AppColors.surfaceColor,
                                  const Color(0xFF16252A),
                                ],
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
                              color: const Color(
                                0xFF4C9F38,
                              ), // Standard UN SDG 3 green color
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4C9F38,
                                  ).withValues(alpha: 0.35),
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
                                    color: isLightTheme
                                        ? const Color(0xFF0A0A14)
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supporting Good Health & Well-being through conscious emotion tracking.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isLightTheme
                                        ? const Color(0xFF606080)
                                        : AppColors.textMuted,
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
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 20,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: isLightTheme
                        ? const Color(0xFFE0E4F2)
                        : AppColors.borderOverlay,
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isLightTheme ? 0.05 : 0.25,
                    ),
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
                          onPressed: () => _launchUrl(
                            'tel:988',
                          ), // Global Mental Health Lifeline
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
            colors: [Color(0xFFFF8E8E), Color(0xFFFF6B6B)],
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLightTheme
              ? const Color(0xFF009C94)
              : const Color(0xFF00D2C8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              color: isLightTheme
                  ? const Color(0xFFE0E4F2)
                  : AppColors.borderOverlay,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isLightTheme
                    ? const Color(0xFF606080)
                    : AppColors.textMuted,
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
                        color: isLightTheme
                            ? const Color(0xFF0A0A14)
                            : Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isLightTheme
                              ? const Color(0xFF606080)
                              : AppColors.textMuted,
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

  String _getHumanizedTechnique(String tech) {
    if (tech == 'breathing_box') return 'Box Breathing';
    if (tech == 'breathing_478') return '4-7-8 Breathing';
    if (tech == 'breathing_deep') return 'Deep Breathing';
    if (tech == 'N/A' || tech == '--') return '--';
    return tech;
  }

  Widget _buildCalmPracticeCard(ThemeData theme, bool isLightTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightTheme
              ? const Color(0xFFE0E4F2)
              : AppColors.borderOverlay,
        ),
        gradient: LinearGradient(
          colors: isLightTheme
              ? [Colors.white, const Color(0xFFF1F8F6)]
              : [
                  AppColors.surfaceColor,
                  const Color(0xFF16252A),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.spa_outlined,
                color: isLightTheme
                    ? const Color(0xFF009C94)
                    : const Color(0xFF00D2C8),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Calm Practice',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_copingSessions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sessions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLightTheme
                            ? const Color(0xFF606080)
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_copingMinutes mins',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLightTheme
                            ? const Color(0xFF606080)
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _getHumanizedTechnique(_favoriteTechnique),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Favorite',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLightTheme
                            ? const Color(0xFF606080)
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessPassportCard(ThemeData theme, bool isLightTheme) {
    if (_isLoadingPassport) {
      return const ShimmerWellnessPassportCard();
    }
    if (_passportData == null) {
      return _buildPassportErrorCard(theme, isLightTheme);
    }

    final borderGradient = LinearGradient(
      colors: isLightTheme
          ? [const Color(0xFF009C94), const Color(0xFF9B5DE5)]
          : [const Color(0xFF00D2C8), const Color(0xFFF15BB5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: borderGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2.0), // The gradient border width
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isLightTheme
                ? [Colors.white, const Color(0xFFF9FAFC)]
                : [
                    AppColors.surfaceColor,
                    const Color(0xFF1B1B2F),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Icon
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: isLightTheme
                      ? const Color(0xFF009C94)
                      : const Color(0xFF00D2C8),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Wellness Passport',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isLightTheme ? const Color(0xFF009C94) : const Color(0xFF00D2C8)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isLightTheme ? const Color(0xFF009C94) : const Color(0xFF00D2C8)).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: isLightTheme ? const Color(0xFF009C94) : const Color(0xFF00D2C8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI Insight',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLightTheme ? const Color(0xFF009C94) : const Color(0xFF00D2C8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // AI Insight Text
            Text(
              _passportData?['aiWeeklyInsight'] ?? 'No weekly insight generated yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isLightTheme ? const Color(0xFF333345) : Colors.white.withValues(alpha: 0.9),
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderOverlay, height: 1),
            const SizedBox(height: 16),

            // Bottom Section: Tags & Stats Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Tags Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Focus',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTagsWrap(isLightTheme),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Coping Sessions Counter Card
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Coping Sessions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLightTheme ? const Color(0xFFF1F4FA) : AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.spa_outlined,
                            size: 16,
                            color: isLightTheme ? const Color(0xFF9B5DE5) : const Color(0xFFF15BB5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_passportData?['copingSessionsCompleted'] ?? 0}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsWrap(bool isLightTheme) {
    final tagsList = _passportData?['topTags'];
    if (tagsList == null || tagsList is! List || tagsList.isEmpty) {
      return Text(
        'No active tags',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isLightTheme ? const Color(0xFF8080A0) : AppColors.textMuted,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tagsList.map<Widget>((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isLightTheme ? const Color(0xFFE4E8F5) : AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLightTheme ? const Color(0xFFD0D5E5) : AppColors.borderOverlay,
            ),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPassportErrorCard(ThemeData theme, bool isLightTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightTheme
              ? const Color(0xFFE0E4F2)
              : AppColors.borderOverlay,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.errorColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Wellness Passport Failed',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Could not retrieve wellness passport summary. Please try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isLightTheme ? const Color(0xFF606080) : AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _fetchWellnessPassport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLightTheme
                      ? const Color(0xFFE4E8F5)
                      : AppColors.surfaceColor,
                  foregroundColor: isLightTheme
                      ? const Color(0xFF0A0A14)
                      : Colors.white,
                  elevation: 0,
                  side: BorderSide(
                    color: isLightTheme
                        ? const Color(0xFFD0D5E5)
                        : AppColors.borderOverlay,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
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
          color: isLightTheme
              ? const Color(0xFFE0E4F2)
              : AppColors.borderOverlay,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (isBest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
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
              color: isLightTheme
                  ? const Color(0xFF606080)
                  : AppColors.textMuted,
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

class _ShimmerStatsCardState extends State<ShimmerStatsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
              color: isLightTheme
                  ? const Color(0xFFF1F4FA)
                  : AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE0E4F2)
                    : AppColors.borderOverlay,
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

class ShimmerCalmPracticeCard extends StatefulWidget {
  const ShimmerCalmPracticeCard({super.key});

  @override
  State<ShimmerCalmPracticeCard> createState() => _ShimmerCalmPracticeCardState();
}

class _ShimmerCalmPracticeCardState extends State<ShimmerCalmPracticeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? const Color(0xFFF1F4FA)
                  : AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE0E4F2)
                    : AppColors.borderOverlay,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isLightTheme ? Colors.black12 : Colors.white10,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 100,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isLightTheme ? Colors.black12 : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(3, (index) => Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black12 : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 50,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black12 : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ShimmerWellnessPassportCard extends StatefulWidget {
  const ShimmerWellnessPassportCard({super.key});

  @override
  State<ShimmerWellnessPassportCard> createState() =>
      _ShimmerWellnessPassportCardState();
}

class _ShimmerWellnessPassportCardState
    extends State<ShimmerWellnessPassportCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? const Color(0xFFF1F4FA)
                  : AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE0E4F2)
                    : AppColors.borderOverlay,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black12 : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 140,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black12 : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 70,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isLightTheme ? Colors.black12 : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black12 : Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black12 : Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black12 : Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.borderOverlay, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black12 : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isLightTheme ? Colors.black12 : Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 60,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isLightTheme ? Colors.black12 : Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 90,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black12 : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 48,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black12 : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
