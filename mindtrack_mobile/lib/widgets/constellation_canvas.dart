import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../providers/mood_provider.dart';

class ConstellationCanvas extends StatefulWidget {
  final List<MoodEntry> entries;
  final ValueChanged<MoodEntry> onDotTapped;

  const ConstellationCanvas({
    super.key,
    required this.entries,
    required this.onDotTapped,
  });

  @override
  State<ConstellationCanvas> createState() => _ConstellationCanvasState();
}

class _ConstellationCanvasState extends State<ConstellationCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _twinkleController;
  final List<_BackgroundStar> _bgStars = [];

  // Edge paddings for safe star drawing and hit testing
  static const double horizontalPadding = 42.0;
  static const double verticalPadding = 36.0;

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Generate static deep space background stars
    final random = math.Random(42); // Seeded for consistency
    for (int i = 0; i < 40; i++) {
      _bgStars.add(
        _BackgroundStar(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: 0.6 + random.nextDouble() * 1.4,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  // Helper to calculate the screen offset for a given mood entry
  Offset _getOffset(MoodEntry entry, Size size) {
    final double usableWidth = size.width - (horizontalPadding * 2);
    final double usableHeight = size.height - (verticalPadding * 2);

    final weekday = entry.timestamp.toLocal().weekday; // 1 (Mon) to 7 (Sun)
    final score = entry.moodScore.clamp(1, 5);

    // Map Monday to 0.0, Sunday to 1.0
    final normalizedX = (weekday - 1) / 6.0;
    // Map score 5 to 0.0 (top), score 1 to 1.0 (bottom)
    final normalizedY = (5.0 - score) / 4.0;

    final x = horizontalPadding + normalizedX * usableWidth;
    final y = verticalPadding + normalizedY * usableHeight;
    return Offset(x, y);
  }

  void _handleTap(TapDownDetails details, Size size) {
    if (widget.entries.isEmpty) return;

    final tapOffset = details.localPosition;
    MoodEntry? closestEntry;
    double closestDistance = double.infinity;

    for (final entry in widget.entries) {
      final starOffset = _getOffset(entry, size);
      final distance = (tapOffset - starOffset).distance;

      // Tap threshold of 26.0 logical pixels for finger-friendly targets
      if (distance < 26.0 && distance < closestDistance) {
        closestDistance = distance;
        closestEntry = entry;
      }
    }

    if (closestEntry != null) {
      widget.onDotTapped(closestEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, 260.0);

        return GestureDetector(
          onTapDown: (details) => _handleTap(details, canvasSize),
          child: Container(
            height: canvasSize.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.borderOverlay.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedBuilder(
                animation: _twinkleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConstellationPainter(
                      entries: widget.entries,
                      bgStars: _bgStars,
                      animationValue: _twinkleController.value,
                      getOffset: _getOffset,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundStar {
  final double x;
  final double y;
  final double size;
  final double phase;

  _BackgroundStar({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });
}

class _ConstellationPainter extends CustomPainter {
  final List<MoodEntry> entries;
  final List<_BackgroundStar> bgStars;
  final double animationValue;
  final Offset Function(MoodEntry, Size) getOffset;

  _ConstellationPainter({
    required this.entries,
    required this.bgStars,
    required this.animationValue,
    required this.getOffset,
  });

  // Groups and returns consecutive entries in the same calendar week
  // Assumes input entries are sorted ascending chronologically
  DateTime _startOfWeek(DateTime date) {
    final local = date.toLocal();
    final dayOnly = DateTime(local.year, local.month, local.day);
    return dayOnly.subtract(Duration(days: local.weekday - 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double hPadding =
        _CustomScoreSliderState.horizontalMargin; // matching padding
    const double vPadding = 36.0;
    final double usableWidth = size.width - (hPadding * 2);
    final double usableHeight = size.height - (vPadding * 2);

    // 1. Paint Deep Space Background Stars (Faint, Twinkling)
    for (final star in bgStars) {
      final starX = star.x * size.width;
      final starY = star.y * size.height;

      // Calculate twinkling opacity independently using phase offsets
      final double starOpacity =
          0.05 +
          0.18 *
              (math.sin(animationValue * math.pi * 2 + star.phase) * 0.5 + 0.5);

      final bgStarPaint = Paint()
        ..color = Colors.white.withValues(alpha: starOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(starX, starY), star.size, bgStarPaint);
    }

    // 2. Draw Celestial Chart Gridlines & Labels
    final gridPaint = Paint()
      ..color = AppColors.borderOverlay.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = AppColors.borderOverlay.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw horizontal score gridlines (High=5, Calm=3, Low=1)
    final scoreYLevels = [0.0, 0.5, 1.0];
    final scoreLabels = ['High', 'Calm', 'Low'];

    for (int i = 0; i < scoreYLevels.length; i++) {
      final y = vPadding + scoreYLevels[i] * usableHeight;
      // Draw grid line
      canvas.drawLine(
        Offset(hPadding - 10, y),
        Offset(size.width - hPadding + 10, y),
        dashPaint,
      );

      // Render Text Label (Low, Calm, High)
      final textPainter = TextPainter(
        text: TextSpan(
          text: scoreLabels[i],
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(8.0, y - (textPainter.height / 2)));
    }

    // Draw vertical weekday gridlines (Mon to Sun)
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 0; i < 7; i++) {
      final x = hPadding + (i / 6.0) * usableWidth;
      // Paint vertical guide lines
      canvas.drawLine(
        Offset(x, vPadding - 5),
        Offset(x, size.height - vPadding + 5),
        gridPaint,
      );

      // Day of Week Label
      final dayPainter = TextPainter(
        text: TextSpan(
          text: daysOfWeek[i],
          style: TextStyle(
            color: i == DateTime.now().weekday - 1
                ? AppColors.primaryColor
                : AppColors.textMuted,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dayPainter.paint(
        canvas,
        Offset(x - (dayPainter.width / 2), size.height - 18.0),
      );
    }

    if (entries.isEmpty) return;

    // 3. Connect consecutive SAME-WEEK dots with faint lines (opacity 0.3)
    // First, let's sort entries chronologically (ascending) to safely draw lines
    final sortedEntries = List<MoodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final linePaint = Paint()
      ..color = AppColors.primaryColor.withValues(alpha: 0.24)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < sortedEntries.length; i++) {
      final prev = sortedEntries[i - 1];
      final curr = sortedEntries[i];

      // Check if they are in the same calendar week
      if (_startOfWeek(prev.timestamp) == _startOfWeek(curr.timestamp)) {
        final p1 = getOffset(prev, size);
        final p2 = getOffset(curr, size);

        // Draw a neat solid gradient or glowing line
        canvas.drawLine(p1, p2, linePaint);

        // Render secondary faint glow line
        final glowLinePaint = Paint()
          ..color = AppColors.primaryColor.withValues(alpha: 0.08)
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(p1, p2, glowLinePaint);
      }
    }

    // 4. Paint Glowing Mood Star Dots
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final pos = getOffset(entry, size);

      // Interpolate star color (Low: Coral, High: Teal)
      final scoreVal = entry.moodScore.clamp(1, 5).toDouble();
      final starColor = Color.lerp(
        AppColors.errorColor,
        AppColors.primaryColor,
        (scoreVal - 1.0) / 4.0,
      )!;

      // Unique phase for each mood star based on its timestamp hash
      final uniqueHash = entry.timestamp.millisecondsSinceEpoch.hashCode;
      final double starTwinkle =
          math.sin(animationValue * math.pi * 2 + (uniqueHash * 0.1)) * 0.35 +
          0.65;

      // A: Outer glowing bloom effect
      final double auraRadius = 10.0 + starTwinkle * 7.0;
      final glowPaint = Paint()
        ..color = starColor.withValues(alpha: 0.18 * starTwinkle)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          4.0 + starTwinkle * 3.0,
        );
      canvas.drawCircle(pos, auraRadius, glowPaint);

      // B: Lens flare crosshairs for highly positive moods (score 4 or 5)
      if (entry.moodScore >= 4) {
        final flarePaint = Paint()
          ..color = starColor.withValues(alpha: 0.5 * starTwinkle)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        final double flareLength = 6.0 + starTwinkle * 4.0;

        // Horizontal flare line
        canvas.drawLine(
          Offset(pos.dx - flareLength, pos.dy),
          Offset(pos.dx + flareLength, pos.dy),
          flarePaint,
        );
        // Vertical flare line
        canvas.drawLine(
          Offset(pos.dx, pos.dy - flareLength),
          Offset(pos.dx, pos.dy + flareLength),
          flarePaint,
        );
      }

      // C: Inner solid core dot
      final double coreRadius = 4.0 + starTwinkle * 0.5;
      final corePaint = Paint()
        ..color = starColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, coreRadius, corePaint);

      // D: Center high-intensity twinkle point (white core)
      final centerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 1.2, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.animationValue != animationValue;
  }
}

class _CustomScoreSliderState {
  static const double horizontalMargin = 42.0;
}
