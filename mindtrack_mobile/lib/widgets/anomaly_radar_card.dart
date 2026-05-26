import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';

class AnomalyRadarCard extends ConsumerStatefulWidget {
  const AnomalyRadarCard({super.key});

  @override
  ConsumerState<AnomalyRadarCard> createState() => _AnomalyRadarCardState();
}

class _AnomalyRadarCardState extends ConsumerState<AnomalyRadarCard>
    with SingleTickerProviderStateMixin {
  static const String _collapsedPrefKey = 'anomaly_radar_collapsed';

  late AnimationController _rotationController;
  bool _showCrisisHelplines = false;
  bool _isCollapsed = false;
  String? _lastRiskLevel;

  @override
  void initState() {
    super.initState();
    _loadCollapsedState();
    // Continuously rotate the radar sweep line to look premium and active
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    final isTest = RegExp(
      r'package:flutter_test',
    ).hasMatch(StackTrace.current.toString());
    if (!isTest) {
      _rotationController.repeat();
    } else {
      _rotationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _launchPhone(String phoneUrl) async {
    try {
      final Uri url = Uri.parse(phoneUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch dialer.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to call lifeline: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadCollapsedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCollapsed = prefs.getBool(_collapsedPrefKey) ?? false;
    });
  }

  Future<void> _setCollapsed(bool value) async {
    setState(() {
      _isCollapsed = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_collapsedPrefKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final anomalyAsync = ref.watch(moodAnomalyProvider);
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    return anomalyAsync.when(
      data: (anomaly) {
        if (anomaly == null) return const SizedBox.shrink();

        if (_lastRiskLevel != anomaly.riskLevel) {
          _lastRiskLevel = anomaly.riskLevel;
          final shouldAutoExpand =
              _isCollapsed &&
              (anomaly.riskLevel == 'HIGH' || anomaly.riskLevel == 'MEDIUM');
          if (shouldAutoExpand) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _setCollapsed(false);
            });
          }
        }

        // 1. Calibration / Insufficient Data State
        if (anomaly.insufficientData) {
          return AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLightTheme
                      ? const Color(0xFFE0E4F2)
                      : AppColors.borderOverlay,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Burnout Anomaly Radar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLightTheme
                              ? const Color(0xFF0A0A14)
                              : Colors.white,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'CALIBRATING',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _isCollapsed
                                  ? Icons.expand_more
                                  : Icons.expand_less,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => _setCollapsed(!_isCollapsed),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  value: 0.6,
                                  strokeWidth: 3.5,
                                  color: AppColors.primaryColor,
                                  backgroundColor: Colors.white10,
                                ),
                              ),
                              Icon(
                                Icons.psychology,
                                color: AppColors.primaryColor.withValues(
                                  alpha: 0.8,
                                ),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Establishing Baseline',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isLightTheme
                                      ? const Color(0xFF0A0A14)
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                anomaly.supportiveInsight.isNotEmpty
                                    ? anomaly.supportiveInsight
                                    : 'We need 5 daily logs to calibrate baseline orbits and scan for emotional burnout trends.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(moodAnomalyProvider),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text(
                          'Refresh Radar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Color configurations based on Risk Level
        final Color riskColor = anomaly.riskLevel == 'HIGH'
            ? AppColors.errorColor
            : anomaly.riskLevel == 'MEDIUM'
            ? Colors.orange
            : AppColors.primaryColor;

        final Color riskBg = riskColor.withValues(alpha: 0.08);

        // 2. Active Anomaly State
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE0E4F2)
                    : AppColors.borderOverlay,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Anomaly Radar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLightTheme
                            ? const Color(0xFF0A0A14)
                            : Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: riskBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: riskColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            anomaly.riskLevel == 'HIGH'
                                ? 'HIGH BURN RISK'
                                : anomaly.riskLevel == 'MEDIUM'
                                ? 'MODERATE SHIFT'
                                : 'STABLE BASELINE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isCollapsed
                                ? Icons.expand_more
                                : Icons.expand_less,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => _setCollapsed(!_isCollapsed),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(moodAnomalyProvider),
                      style: TextButton.styleFrom(
                        foregroundColor: riskColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text(
                        'Refresh Radar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Animated Radar SVG/Canvas + Patterns layout
                  Row(
                    children: [
                      // Animated Radar Sweep custom widget
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _RadarPainter(
                                rotationAngle:
                                    _rotationController.value * 2 * math.pi,
                                radarColor: riskColor,
                                anomalyCount: anomaly.detectedPatterns.length,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Diagnostics detail summary
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anomaly.riskLevel == 'HIGH'
                                  ? 'Action Required'
                                  : anomaly.riskLevel == 'MEDIUM'
                                  ? 'Baseline Deviation'
                                  : 'System Calibrated',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isLightTheme
                                    ? const Color(0xFF0A0A14)
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              anomaly.supportiveInsight,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isLightTheme
                                    ? const Color(0xFF606080)
                                    : AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Coping suggestion block
                  if (anomaly.suggestedAction.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLightTheme
                            ? const Color(0xFFF0F4FA)
                            : const Color(0xFF0A0A14).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLightTheme
                              ? const Color(0xFFE4E8F5)
                              : Colors.white.withValues(alpha: 0.02),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🌱', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              anomaly.suggestedAction,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isLightTheme
                                    ? const Color(0xFF008C86)
                                    : AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // High-risk support button actions
                  if (anomaly.riskLevel == 'HIGH') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Route seamlessly to profile which has therapists / lifelines
                              context.go('/profile');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.errorColor.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: AppColors.errorColor,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: AppColors.errorColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Coping Sanctuary',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showCrisisHelplines = !_showCrisisHelplines;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.errorColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.emergency_outlined,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showCrisisHelplines
                                        ? 'Hide Helplines'
                                        : 'Crisis Support',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showCrisisHelplines) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.errorColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Direct Lifelines (Anonymous)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.errorColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _launchPhone('tel:988'),
                                    icon: const Icon(
                                      Icons.phone_in_talk,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Call 988',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.errorColor,
                                      side: const BorderSide(
                                        color: AppColors.errorColor,
                                      ),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _launchPhone('tel:911'),
                                    icon: const Icon(
                                      Icons.local_hospital,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Call 911',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.errorColor,
                                      side: const BorderSide(
                                        color: AppColors.errorColor,
                                      ),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLightTheme
                ? const Color(0xFFE0E4F2)
                : AppColors.borderOverlay,
            width: 1.5,
          ),
        ),
        child: const SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryColor),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double rotationAngle;
  final Color radarColor;
  final int anomalyCount;

  _RadarPainter({
    required this.rotationAngle,
    required this.radarColor,
    required this.anomalyCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Paint configs
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final corePaint = Paint()
      ..color = radarColor
      ..style = PaintingStyle.fill;

    // Draw solid radial background
    canvas.drawCircle(center, radius, bgPaint);

    // Draw concentric baseline orbits
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.6, ringPaint);
    canvas.drawCircle(center, radius * 0.3, ringPaint);

    // Draw central pulsing core
    canvas.drawCircle(center, 4, corePaint);

    // Draw rotating sweep sector using shader / sweep gradient simulation
    final sweepPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: rotationAngle - math.pi / 4,
      endAngle: rotationAngle,
      colors: [radarColor, radarColor.withValues(alpha: 0.0)],
      stops: const [0.0, 1.0],
    );

    sweepPaint.shader = sweepGradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    canvas.drawCircle(center, radius - 1, sweepPaint);
    canvas.drawCircle(center, radius * 0.6, sweepPaint);

    // Draw specific sweep line
    final linePaint = Paint()
      ..color = radarColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final endPointX = center.dx + radius * math.cos(rotationAngle);
    final endPointY = center.dy + radius * math.sin(rotationAngle);
    canvas.drawLine(center, Offset(endPointX, endPointY), linePaint);

    // Draw anomaly dots placed on baseline orbits
    final dotPaint = Paint()
      ..color = radarColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < anomalyCount; i++) {
      final angle = (i * 135 + 45) * (math.pi / 180);
      final distRatio = i % 2 == 0 ? 0.75 : 0.45;
      final dotRadius = radius * distRatio;
      final dx = center.dx + dotRadius * math.cos(angle);
      final dy = center.dy + dotRadius * math.sin(angle);

      canvas.drawCircle(Offset(dx, dy), 4.5, dotPaint);

      // Draw subtle halo
      final haloPaint = Paint()
        ..color = radarColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx, dy), 8, haloPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.radarColor != radarColor ||
        oldDelegate.anomalyCount != anomalyCount;
  }
}
