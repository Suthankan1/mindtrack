import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';
import '../widgets/mood_ring.dart';
import '../widgets/mood_face_icon.dart';
import '../widgets/streak_card.dart';
import '../widgets/wave_spark.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLogging = false;

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

  Future<void> _handleMoodLog(int score) async {
    if (_isLogging) return;

    setState(() {
      _isLogging = true;
    });

    try {
      // 1. Trigger medium impact haptic feedback as requested
      await HapticFeedback.mediumImpact();

      // 2. Fire the asynchronous Riverpod/Dio request
      await ref.read(moodActionsProvider).logMood(score);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.primaryColor, size: 18),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.errorColor, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Handshake failed. Ensure local backend is active.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        border: Border.all(color: AppColors.primaryColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: const CircleAvatar(
                        backgroundColor: AppColors.surfaceColor,
                        child: Icon(Icons.person_outline, color: AppColors.primaryColor),
                      ),
                    )
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
                              color: Colors.transparent, // Disable interactions visually
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
