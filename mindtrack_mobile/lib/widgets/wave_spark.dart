import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/mood_provider.dart';
import '../theme/app_theme.dart';

class WaveSpark extends ConsumerWidget {
  const WaveSpark({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(moodHistoryProvider);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emotional Trajectory',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Last 7 entries',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _buildEmptySpark();
                }

                // Get last 7 entries chronologically (oldest to newest)
                final last7 = entries.take(7).toList().reversed.toList();
                
                final List<FlSpot> spots = [];
                if (last7.length == 1) {
                  // If only 1 spot, add an extra dummy spot to form a straight line
                  final val = last7.first.moodScore.toDouble();
                  spots.add(FlSpot(0, val));
                  spots.add(FlSpot(1, val));
                } else {
                  for (int i = 0; i < last7.length; i++) {
                    spots.add(FlSpot(i.toDouble(), last7[i].moodScore.toDouble()));
                  }
                }

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      show: false, // Keep it completely minimal and pure sparkline-like
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0.5,
                    maxY: 5.5,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => AppColors.navBarBackground,
                        tooltipBorderRadius: BorderRadius.circular(8),
                        tooltipBorder: const BorderSide(color: AppColors.borderOverlay),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            if (idx >= 0 && idx < last7.length) {
                              final entry = last7[idx];
                              return LineTooltipItem(
                                'Score: ${entry.moodScore}/5\n${_getFormattedDate(entry.timestamp)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            return LineTooltipItem(
                              'Score: ${spot.y.toInt()}/5',
                              const TextStyle(color: Colors.white, fontSize: 9),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.primaryColor,
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        shadow: Shadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.backgroundColor,
                              strokeColor: AppColors.primaryColor,
                              strokeWidth: 2,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryColor.withValues(alpha: 0.25),
                              AppColors.primaryColor.withValues(alpha: 0.0),
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
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              error: (err, stack) => _buildEmptySpark(isError: true),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    final local = date.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}';
  }

  Widget _buildEmptySpark({bool isError = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.show_chart,
            color: AppColors.textMuted.withValues(alpha: 0.5),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            isError ? 'Failed to synchronize logs' : 'No records logged in this timeframe',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
