import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomScoreSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const CustomScoreSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CustomScoreSlider> createState() => _CustomScoreSliderState();
}

class _CustomScoreSliderState extends State<CustomScoreSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isDragging = false;

  final List<String> _scoreLabels = [
    'Severely Muted',
    'Slightly Taxing',
    'Centered & Calm',
    'Resonant & Positive',
    'Radiant & Joyful',
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _updateValue(double localX, double totalWidth) {
    // Inset track left and right by 16px to prevent thumb clipping
    const horizontalMargin = 16.0;
    final usableWidth = totalWidth - (horizontalMargin * 2);
    final relativeX = (localX - horizontalMargin).clamp(0.0, usableWidth);
    final normalized = relativeX / usableWidth;
    final newValue = 1.0 + normalized * 4.0;
    widget.onChanged(newValue);
  }

  void _snapToInteger() {
    setState(() => _isDragging = false);
    _glowController.reverse();
    final snappedValue = widget.value.roundToDouble();
    widget.onChanged(snappedValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeIndex = (widget.value.round() - 1).clamp(0, 4);
    final currentLabel = _scoreLabels[activeIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slider Feeling Label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: Container(
            key: ValueKey<String>(currentLabel),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Color.lerp(
                AppColors.errorColor,
                AppColors.primaryColor,
                (widget.value - 1.0) / 4.0,
              )!.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color.lerp(
                  AppColors.errorColor,
                  AppColors.primaryColor,
                  (widget.value - 1.0) / 4.0,
                )!.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      AppColors.errorColor,
                      AppColors.primaryColor,
                      (widget.value - 1.0) / 4.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.lerp(
                          AppColors.errorColor,
                          AppColors.primaryColor,
                          (widget.value - 1.0) / 4.0,
                        )!,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Score ${widget.value.toStringAsFixed(1)}: $currentLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Custom Paint Slider Track & Gestures
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onPanStart: (details) {
                setState(() => _isDragging = true);
                _glowController.forward();
                _updateValue(details.localPosition.dx, constraints.maxWidth);
              },
              onPanUpdate: (details) {
                _updateValue(details.localPosition.dx, constraints.maxWidth);
              },
              onPanEnd: (_) => _snapToInteger(),
              onTapDown: (details) {
                setState(() => _isDragging = true);
                _glowController.forward();
                _updateValue(details.localPosition.dx, constraints.maxWidth);
              },
              onTapUp: (_) => _snapToInteger(),
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _ScoreSliderPainter(
                        value: widget.value,
                        isDragging: _isDragging,
                        glowProgress: _glowController.value,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScoreSliderPainter extends CustomPainter {
  final double value;
  final bool isDragging;
  final double glowProgress;

  _ScoreSliderPainter({
    required this.value,
    required this.isDragging,
    required this.glowProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 16.0;
    final trackWidth = size.width - (margin * 2);
    final trackHeight = 8.0;
    final centerY = size.height / 2;

    // 1. Draw Background Track (faint grey)
    final bgTrackPaint = Paint()
      ..color = AppColors.borderOverlay
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(margin, centerY),
      Offset(size.width - margin, centerY),
      bgTrackPaint,
    );

    // 2. Draw Gradient Active Track
    final activePaint = Paint()
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final thumbX = margin + ((value - 1.0) / 4.0) * trackWidth;

    final trackGradient = LinearGradient(
      colors: [AppColors.errorColor, AppColors.primaryColor],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    activePaint.shader = trackGradient.createShader(
      Rect.fromLTRB(
        margin,
        centerY - trackHeight,
        size.width - margin,
        centerY + trackHeight,
      ),
    );

    // Paint active line from start to current thumbX
    canvas.drawLine(
      Offset(margin, centerY),
      Offset(thumbX, centerY),
      activePaint,
    );

    // 3. Draw Snapping Ticks (1 to 5)
    for (int i = 0; i < 5; i++) {
      final tickX = margin + (i / 4.0) * trackWidth;
      final tickVal = (i + 1).toDouble();

      final isPassed = tickVal <= value;
      final isClosest = tickVal == value.roundToDouble();

      // Tick base color based on active gradient
      final tickColor = Color.lerp(
        AppColors.errorColor,
        AppColors.primaryColor,
        i / 4.0,
      )!;

      final tickPaint = Paint()
        ..color = isPassed
            ? Colors.white
            : AppColors.textMuted.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;

      // Draw tick circle
      final double tickRadius = isClosest ? 5.0 : 4.0;
      canvas.drawCircle(Offset(tickX, centerY), tickRadius, tickPaint);

      // Draw subtle ring outer border for ticks
      if (isClosest) {
        final borderPaint = Paint()
          ..color = tickColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(Offset(tickX, centerY), tickRadius + 3, borderPaint);
      }
    }

    // 4. Draw Thumb Glow & Aura
    final activeThumbColor = Color.lerp(
      AppColors.errorColor,
      AppColors.primaryColor,
      (value - 1.0) / 4.0,
    )!;

    // Animated glow aura
    final double maxAuraRadius = isDragging ? 22.0 : 16.0;
    final double auraOpacity = isDragging ? 0.35 : 0.2;

    final glowPaint = Paint()
      ..color = activeThumbColor.withValues(
        alpha: auraOpacity + (glowProgress * 0.1),
      )
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        6.0 + (glowProgress * 4.0),
      );

    canvas.drawCircle(Offset(thumbX, centerY), maxAuraRadius, glowPaint);

    // Core Thumb Border/Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(Offset(thumbX, centerY + 2), 11.0, shadowPaint);

    // Core Thumb Outer Ring
    final thumbBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumbX, centerY), 11.0, thumbBorderPaint);

    // Core Thumb Inner Solid
    final thumbCorePaint = Paint()
      ..color = activeThumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumbX, centerY), 8.0, thumbCorePaint);
  }

  @override
  bool shouldRepaint(covariant _ScoreSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.glowProgress != glowProgress;
  }
}
