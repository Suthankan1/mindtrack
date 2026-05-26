import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../providers/mood_provider.dart';
import '../theme/app_theme.dart';

/// A premium, beautiful Weekly Summary screen that presents:
/// 1. A 7-day fl_chart LineChart of mood scores (matching WaveSpark styling).
/// 2. The Gemini AI weekly insight in a glowing card.
/// 3. Top 3 used tags as colored chips.
/// 4. An entry count badge.
/// 5. A circular 'Mood Consistency Score' (entry count / 7 * 100%).
class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;
    
    // Watch weekly insight from Spring Boot API
    final weeklyInsightAsync = ref.watch(weeklyInsightProvider);
    // Watch mood history from local/sync provider
    final moodHistoryAsync = ref.watch(moodHistoryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Weekly Report',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.primaryColor,
          onRefresh: () async {
            ref.invalidate(weeklyInsightProvider);
            await ref.read(moodHistoryProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Overview Badges (Consistency & Logs Count)
                weeklyInsightAsync.when(
                  data: (insight) => _buildOverviewRow(context, insight),
                  loading: () => _buildOverviewShimmer(),
                  error: (err, stack) => _buildOverviewRow(
                    context,
                    WeeklyInsight(
                      insight: 'Error loading stats',
                      weeklyAverage: 0.0,
                      peakDay: 'N/A',
                      entryCount: 0,
                      aiAvailable: false,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Emotional Trajectory Sparkline
                Text(
                  'Emotional Trajectory',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTrajectoryChartCard(context, moodHistoryAsync),
                const SizedBox(height: 24),

                // Section 3: Gemini AI Weekly Insight Card
                Text(
                  'Gemini AI Insight',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                weeklyInsightAsync.when(
                  data: (insight) => _buildGlowingInsightCard(context, insight),
                  loading: () => _buildInsightShimmer(context),
                  error: (err, stack) => _buildErrorCard(context, err.toString()),
                ),
                const SizedBox(height: 24),

                // Section 4: Top Used Tags
                Text(
                  'Top Tags this Week',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTopTagsCard(context, moodHistoryAsync),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- OVERVIEW SECTION ---

  Widget _buildOverviewRow(BuildContext context, WeeklyInsight insight) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;
    
    final int entryCount = insight.entryCount;
    final double consistencyPct = (entryCount / 7.0).clamp(0.0, 1.0);
    final int consistencyScore = (consistencyPct * 100).round();

    return Row(
      children: [
        // Consistency Card
        Expanded(
          child: Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                // Circular Progress Ring
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: consistencyPct,
                        strokeWidth: 6,
                        backgroundColor: isLightTheme
                            ? const Color(0xFFE4E8F5)
                            : AppColors.borderOverlay,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                      Text(
                        '$consistencyScore%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Mood Consistency',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        consistencyScore >= 80
                            ? 'Excellent habit!'
                            : consistencyScore >= 50
                                ? 'Stable routine'
                                : 'Keep logging!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Log Count Card
        Expanded(
          child: Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$entryCount logs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Entry Count Badge',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Out of 7 tracking days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewShimmer() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  // --- TRAJECTORY CHART CARD ---

  Widget _buildTrajectoryChartCard(
    BuildContext context,
    AsyncValue<List<MoodEntry>> historyAsync,
  ) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Sparkline',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Last 7 entries',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _buildEmptyChart(context);
                }

                // Get last 7 entries chronologically (oldest to newest)
                final last7 = entries.take(7).toList().reversed.toList();

                final List<FlSpot> spots = [];
                if (last7.length == 1) {
                  final val = last7.first.moodScore.toDouble();
                  spots.add(FlSpot(0, val));
                  spots.add(FlSpot(1, val));
                } else {
                  for (int i = 0; i < last7.length; i++) {
                    spots.add(
                      FlSpot(i.toDouble(), last7[i].moodScore.toDouble()),
                    );
                  }
                }

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      show: false, // Match WaveSpark sparkline minimal look
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0.5,
                    maxY: 5.5,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) =>
                            isLightTheme ? const Color(0xFFE4E8F5) : AppColors.navBarBackground,
                        tooltipBorderRadius: BorderRadius.circular(8),
                        tooltipBorder: BorderSide(
                          color: theme.dividerColor,
                        ),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            if (idx >= 0 && idx < last7.length) {
                              final entry = last7[idx];
                              return LineTooltipItem(
                                'Score: ${entry.moodScore}/5\n${_getFormattedDate(entry.timestamp)}',
                                TextStyle(
                                  color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            return LineTooltipItem(
                              'Score: ${spot.y.toInt()}/5',
                              TextStyle(
                                color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                                fontSize: 10,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: theme.primaryColor,
                        barWidth: 4.0,
                        isStrokeCapRound: true,
                        shadow: Shadow(
                          color: theme.primaryColor.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: isLightTheme ? Colors.white : AppColors.backgroundColor,
                              strokeColor: theme.primaryColor,
                              strokeWidth: 2.5,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              theme.primaryColor.withOpacity(0.25),
                              theme.primaryColor.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: theme.primaryColor,
                ),
              ),
              error: (err, stack) => _buildEmptyChart(context, isError: true),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    final local = date.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[local.month - 1]} ${local.day}';
  }

  Widget _buildEmptyChart(BuildContext context, {bool isError = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.show_chart,
            color: AppColors.textMuted.withOpacity(0.5),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            isError
                ? 'Failed to synchronize logs'
                : 'No records logged this week',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- GEMINI AI INSIGHT CARD ---

  Widget _buildGlowingInsightCard(BuildContext context, WeeklyInsight insight) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

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
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.0), // Gradient border width
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
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: isLightTheme
                      ? const Color(0xFF009C94)
                      : const Color(0xFF00D2C8),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Weekly AI Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              insight.insight,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isLightTheme ? const Color(0xFF2C2C3E) : const Color(0xFFE4E4FF),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (insight.weeklyAverage > 0 || insight.peakDay != 'N/A') ...[
              const SizedBox(height: 20),
              const Divider(color: AppColors.borderOverlay),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (insight.weeklyAverage > 0)
                    _buildInsightPill(
                      context,
                      'Avg Mood: ${insight.weeklyAverage.toStringAsFixed(1)}',
                      Icons.star_half_rounded,
                    ),
                  if (insight.peakDay != 'N/A')
                    _buildInsightPill(
                      context,
                      'Peak Stress: ${insight.peakDay}',
                      Icons.warning_amber_rounded,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightPill(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isLightTheme ? const Color(0xFFE4E8F5) : AppColors.surfaceColor).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightShimmer(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryColor,
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.errorColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorColor, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Failed to retrieve weekly insights',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- TOP TAGS CARD ---

  Widget _buildTopTagsCard(
    BuildContext context,
    AsyncValue<List<MoodEntry>> historyAsync,
  ) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: historyAsync.when(
        data: (entries) {
          final last7 = entries.take(7).toList();
          final tagCounts = <String, int>{};
          for (final entry in last7) {
            for (final tag in entry.tags) {
              tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
            }
          }

          if (tagCounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No tags logged in the last 7 days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          final sortedTags = tagCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top3 = sortedTags.take(3).map((e) => e.key).toList();

          final List<Color> chipColors = isLightTheme
              ? [const Color(0xFF009C94), const Color(0xFFFF6B6B), const Color(0xFFFFB347)]
              : [const Color(0xFF00D2C8), const Color(0xFFFF6B6B), const Color(0xFFFFB347)];

          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: List.generate(top3.length, (index) {
              final tag = top3[index];
              final color = chipColors[index % chipColors.length];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag_rounded, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      tag,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isLightTheme ? color.withRed(30).withGreen(120) : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (err, stack) => const Text('Error loading tags'),
      ),
    );
  }
}
