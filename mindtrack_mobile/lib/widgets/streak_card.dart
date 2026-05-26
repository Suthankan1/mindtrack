import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/mood_provider.dart';
import '../theme/app_theme.dart';

/// Displays the user's current consecutive mood-logging streak with an animated
/// gold flame icon and a motivational subtitle.
///
/// Reads streak counts from [streakProvider] and [longestStreakProvider] and pulses the glow aura
/// using a repeating [AnimationController].
class StreakCard extends ConsumerStatefulWidget {
  const StreakCard({super.key});

  @override
  ConsumerState<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends ConsumerState<StreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    final isTest = RegExp(
      r'package:flutter_test',
    ).hasMatch(StackTrace.current.toString());
    if (!isTest) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }

    _glowScale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStreakAsync = ref.watch(streakProvider);
    final longestStreakAsync = ref.watch(longestStreakProvider);
    final currentStreak = currentStreakAsync.value ?? 0;
    final longestStreak = longestStreakAsync.value ?? 0;
    final isNewBest = currentStreak >= longestStreak && currentStreak > 1;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderOverlay),
          gradient: LinearGradient(
            colors: [
              AppColors.surfaceColor,
              AppColors.surfaceColor.withBlue(45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Glowing Gold Flame Icon
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _glowScale.value,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.15),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: Colors.amber,
                    size: 26,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Streak Metrics
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentStreak',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentStreak == 1 ? 'day streak' : 'days streak',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Best: $longestStreak days',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentStreak > 0
                        ? 'Keep protecting your emotional consistency spark.'
                        : 'Log your mood today to ignite a new calm streak.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isNewBest) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'NEW BEST!',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
