import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';
import '../widgets/mood_ring.dart';
import '../widgets/mood_face_icon.dart';
import '../widgets/streak_card.dart';
import '../widgets/wave_spark.dart';
import '../widgets/anomaly_radar_card.dart';

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

      if (mounted) {
        if (hasCrisisAlert && crisisMessage != null) {
          _showCrisisBottomSheet(context, crisisMessage);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily calm secure in ledger.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.surfaceColor,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderOverlay),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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

  void _showCrisisBottomSheet(BuildContext context, String crisisMessage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        final theme = Theme.of(context);
        final isLightTheme = theme.brightness == Brightness.light;

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: isLightTheme ? const Color(0xFFF4F6FC) : AppColors.backgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(
              color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pull bar / drag handle
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: (isLightTheme ? const Color(0xFF8B8BBA) : AppColors.textMuted).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Empathy Graphic / Heart
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.errorColor.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.errorColor.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.favorite_rounded,
                        color: AppColors.errorColor,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Warm Header
                Center(
                  child: Text(
                    'We are here for you',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),

                // Empathetic AI Message Card
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isLightTheme ? Colors.white : AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isLightTheme ? 0.02 : 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        crisisMessage,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                          height: 1.6,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Teal "I'm okay" button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: isLightTheme ? Colors.white : AppColors.backgroundColor,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "I'm okay",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Coral "Find Support" button
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/profile');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorColor,
                    side: const BorderSide(color: AppColors.errorColor, width: 2),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Find Support",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayMoodAsync = ref.watch(todayMoodProvider);
    final historyAsync = ref.watch(moodHistoryProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryColor,
          backgroundColor: AppColors.surfaceColor,
          onRefresh: () async {
            // Trigger haptic on pull-to-refresh
            await HapticFeedback.lightImpact();
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
                        border: Border.all(
                          color: AppColors.primaryColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        backgroundColor: AppColors.surfaceColor,
                        child: Icon(
                          Icons.person_outline,
                          color: AppColors.primaryColor,
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
                  error: (_, __) => const MoodRing(moodScore: null),
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
                  error: (_, __) => Row(
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
