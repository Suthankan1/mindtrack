import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';
import '../services/dio_service.dart';
import '../widgets/mood_ring.dart';
import '../widgets/mood_face_icon.dart';
import '../widgets/streak_card.dart';
import '../widgets/wave_spark.dart';
import '../widgets/anomaly_radar_card.dart';
import '../widgets/cosmic_calm_sheet.dart';
import '../widgets/quote_card.dart';
import 'dart:math' as math;

/// The primary Home tab displaying the user's mood ring, quick-log buttons,
/// streak card, and a 7-day mini wave chart.
///
/// Manages optimistic loading state for mood logging and coordinates
/// [MoodRing], [MoodFaceButton], [StreakCard], and [WaveSpark] widgets.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLogging = false;
  String _userEmail = '';
  String? _dailyQuote;
  bool _isLoadingQuote = true;

  final List<String> _fallbackQuotes = const [
    "Your mental health is a priority. Your happiness is an essential. Your self-care is a necessity.",
    "Healing is not linear. Be gentle and patient with your mind as you navigate today's journey.",
    "You do not have to be perfect to be amazing. Every small step forward is progress.",
    "Quiet the mind and the soul will speak. Give yourself permission to pause and breathe.",
    "Be proud of how hard you are trying. You are doing much better than you think.",
    "Self-care is how you take your power back. Take a moment to ground yourself today.",
    "Your presence in this world matters. Trust in your ability to grow through what you go through.",
  ];

  final List<Color> _avatarColors = const [
    Color(0xFF00D2C8),
    Color(0xFFFF6B6B),
    Color(0xFFFFB347),
    Color(0xFF9B5DE5),
    Color(0xFF00F5D4),
    Color(0xFFF15BB5),
    Color(0xFF3A86C8),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _fetchDailyQuote();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).syncPending();
    });
  }

  Future<void> _fetchDailyQuote() async {
    try {
      final dio = ref.read(dioServiceProvider);
      final quote = await dio.getDailyQuote();
      if (!mounted) return;
      setState(() {
        _dailyQuote = quote;
        _isLoadingQuote = false;
      });
    } catch (e) {
      debugPrint('HomeScreen: Failed to fetch daily quote: $e');
      if (!mounted) return;
      
      // Select a random quote from the fallback list of 7 wellness quotes
      final random = math.Random();
      final fallbackQuote = _fallbackQuotes[random.nextInt(_fallbackQuotes.length)];
      setState(() {
        _dailyQuote = fallbackQuote;
        _isLoadingQuote = false;
      });
    }
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userEmail = prefs.getString('user_email') ?? '';
    });
  }

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

  /// Returns a time-appropriate greeting string based on the current local hour.
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  String _getDeterministicReflection(int score) {
    return switch (score) {
      1 => "It sounds like you're carrying a heavy burden right now. Please be gentle with yourself.",
      2 => "Your energy is feeling a bit low today, and that is completely okay.",
      4 => "It's wonderful to feel a sense of stable peace in your day.",
      5 => "Your spirit is shining bright today! Enjoy this wonderful feeling.",
      _ => "You're feeling centered and balanced today.",
    };
  }

  String _getDeterministicNextStep(int score) {
    return switch (score) {
      1 => "Try a quick grounding exercise or reach out to a trusted loved one.",
      2 => "Give yourself permission to rest or engage in a gentle activity.",
      4 => "Take a moment to appreciate this stable energy and keep doing what supports you.",
      5 => "Share your joy or anchor this moment in a quick journal entry.",
      _ => "Continue observing your day with gentle mindfulness.",
    };
  }

  String _getDeterministicTechnique(int score) {
    return switch (score) {
      1 => "grounding",
      2 => "breathing_deep",
      4 => "walk",
      5 => "journaling",
      _ => "journaling",
    };
  }

  /// Handles a mood log tap: debounces concurrent taps, fires haptic feedback,
  /// calls the Riverpod mood action, and shows a success or error snackbar.
  Future<void> _handleMoodLog(int score) async {
    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    try {
      // 1. Trigger medium impact haptic feedback as requested
      await HapticFeedback.mediumImpact();

      // 2. Fire the asynchronous Riverpod/Dio request
      final responseMap = await ref.read(moodActionsProvider).logMood(score);

      final hasCrisisAlert = responseMap['crisisAlert'] == true;
      final crisisMessage = responseMap['crisisMessage'] as String?;

      // 3. Fetch instant AI reflection from backend
      Map<String, dynamic> reflectionData;
      try {
        final dio = ref.read(dioServiceProvider);
        reflectionData = await dio.getMoodReflection(
          moodScore: score,
          tags: const [],
          note: 'Logged via quick-check on home screen',
        );
      } catch (reflectionErr) {
        debugPrint('HomeScreen: Failed to get AI reflection: $reflectionErr');
        // Elegant deterministic fallback on client-side
        reflectionData = {
          'oneSentenceReflection': _getDeterministicReflection(score),
          'suggestedNextStep': _getDeterministicNextStep(score),
          'recommendedTechnique': _getDeterministicTechnique(score),
          'showCrisisResources': score <= 1,
        };
      }

      if (mounted) {
        // If crisis is returned or detected, ensure the sheet displays it
        if (hasCrisisAlert) {
          reflectionData['showCrisisResources'] = true;
          if (crisisMessage != null) {
            reflectionData['oneSentenceReflection'] = crisisMessage;
          }
        }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (context) => CosmicCalmSheet(reflection: reflectionData),
        );
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.errorColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.borderOverlay),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLogging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayMoodAsync = ref.watch(todayMoodProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryColor,
          backgroundColor: AppColors.surfaceColor,
          onRefresh: () async {
            // Trigger haptic on pull-to-refresh
            await HapticFeedback.lightImpact();
            // Sync pending entries first
            await ref.read(syncProvider.notifier).syncPending();
            // Refresh history, which naturally recalibrates stats and today's score
            await ref.read(moodHistoryProvider.notifier).refresh();
            // Invalidate today's mood to re-trigger getTodayMoods check
            ref.invalidate(todayMoodProvider);
            // Refresh mood anomaly diagnostic radar
            await ref.read(moodAnomalyProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kDebugMode) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bug_report_outlined,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Debug Mode — Backend: ${ref.watch(dioServiceProvider).baseUrl}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 1. Premium Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'MindTracker',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getAvatarColor(_userEmail),
                        border: Border.all(
                          color: AppColors.primaryColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getAvatarColor(
                              _userEmail,
                            ).withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _getEmailInitials(_userEmail),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. Pulsing Mood Ring Widget
                todayMoodAsync.when(
                  data: (todayScore) => MoodRing(moodScore: todayScore),
                  loading: () => const SizedBox(
                    height: 170,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  error: (_, _) => const MoodRing(moodScore: null),
                ),
                const SizedBox(height: 28),

                // 3. Prompt & 5 Custom Painter Mood Buttons
                Center(
                  child: Text(
                    'How are you feeling today?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                todayMoodAsync.when(
                  data: (todayScore) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (index) {
                            final scoreValue = index + 1;
                            final isSelected = todayScore == scoreValue;
                            return MoodFaceButton(
                              score: scoreValue,
                              isSelected: isSelected,
                              onTap: () => _handleMoodLog(scoreValue),
                            );
                          }),
                        ),
                        if (_isLogging)
                          Positioned.fill(
                            child: Container(
                              color: Colors
                                  .transparent, // Disable interactions visually
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 80),
                  error: (_, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final scoreValue = index + 1;
                      return MoodFaceButton(
                        score: scoreValue,
                        isSelected: false,
                        onTap: () => _handleMoodLog(scoreValue),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 32),

                // 4. StreakCard Widget
                const StreakCard(),
                const SizedBox(height: 20),

                // QuoteCard Widget
                QuoteCard(
                  quote: _dailyQuote,
                  isLoading: _isLoadingQuote,
                ),
                const SizedBox(height: 20),

                // 5. Mini WaveSpark Widget (7-day fl_chart LineChart)
                const WaveSpark(),
                const SizedBox(height: 20),

                // 6. Compact Anomaly Radar Card Widget
                const AnomalyRadarCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
