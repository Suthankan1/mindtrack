import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Interactive button using CustomPainter for beautiful custom vector faces.
class MoodFaceButton extends StatefulWidget {
  final int score;
  final bool isSelected;
  final VoidCallback onTap;

  const MoodFaceButton({
    super.key,
    required this.score,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<MoodFaceButton> createState() => _MoodFaceButtonState();
}

class _MoodFaceButtonState extends State<MoodFaceButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getMoodColor() {
    switch (widget.score) {
      case 1:
        return AppColors.errorColor; // Red-orange
      case 2:
        return Colors.orangeAccent;
      case 3:
        return AppColors.textMuted; // Slate neutral
      case 4:
        return Colors.indigoAccent;
      case 5:
        return AppColors.primaryColor; // Glowing teal
      default:
        return Colors.white;
    }
  }

  String _getMoodLabel() {
    switch (widget.score) {
      case 1:
        return 'Awful';
      case 2:
        return 'Down';
      case 3:
        return 'Neutral';
      case 4:
        return 'Good';
      case 5:
        return 'Radiant';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = _getMoodColor();
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _animController.forward(),
      onTapUp: (_) {
        _animController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected 
                    ? moodColor.withValues(alpha: 0.15) 
                    : AppColors.surfaceColor,
                border: Border.all(
                  color: widget.isSelected 
                      ? moodColor 
                      : AppColors.borderOverlay,
                  width: widget.isSelected ? 2.0 : 1.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: moodColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              padding: const EdgeInsets.all(12),
              child: CustomPaint(
                painter: MoodFacePainter(
                  score: widget.score,
                  color: widget.isSelected ? moodColor : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getMoodLabel(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.isSelected ? moodColor : AppColors.textMuted,
                fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter to draw premium vector facial details
class MoodFacePainter extends CustomPainter {
  final int score;
  final Color color;

  MoodFacePainter({
    required this.score,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;

    // Draw Eyes and Mouth based on Score
    switch (score) {
      case 1:
        // Awful: Sad slanted eyebrows/eyes and deep frown mouth
        // Left eye
        canvas.drawLine(Offset(w * 0.25, h * 0.35), Offset(w * 0.4, h * 0.4), paint);
        canvas.drawCircle(Offset(w * 0.3, h * 0.45), 1.5, paint..style = PaintingStyle.fill);
        // Right eye
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(Offset(w * 0.75, h * 0.35), Offset(w * 0.6, h * 0.4), paint);
        canvas.drawCircle(Offset(w * 0.7, h * 0.45), 1.5, paint..style = PaintingStyle.fill);

        // Frown Mouth
        paint.style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(w * 0.3, h * 0.75)
          ..quadraticBezierTo(w * 0.5, h * 0.55, w * 0.7, h * 0.75);
        canvas.drawPath(path, paint);
        break;

      case 2:
        // Down: Drooping sad eyes and slight frown
        // Left eye curve (downward arc)
        final leftEye = Path()
          ..moveTo(w * 0.25, h * 0.4)
          ..quadraticBezierTo(w * 0.35, h * 0.32, w * 0.45, h * 0.4);
        canvas.drawPath(leftEye, paint);
        // Right eye curve
        final rightEye = Path()
          ..moveTo(w * 0.55, h * 0.4)
          ..quadraticBezierTo(w * 0.65, h * 0.32, w * 0.75, h * 0.4);
        canvas.drawPath(rightEye, paint);

        // Slight Frown Mouth
        final path = Path()
          ..moveTo(w * 0.35, h * 0.72)
          ..quadraticBezierTo(w * 0.5, h * 0.62, w * 0.65, h * 0.72);
        canvas.drawPath(path, paint);
        break;

      case 3:
        // Neutral: Straight eyes and straight line mouth
        // Eyes (two small dots or simple small horizontal lines)
        canvas.drawCircle(Offset(w * 0.3, h * 0.42), 2, paint..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(w * 0.7, h * 0.42), 2, paint..style = PaintingStyle.fill);

        // Straight mouth
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(Offset(w * 0.32, h * 0.68), Offset(w * 0.68, h * 0.68), paint);
        break;

      case 4:
        // Good: Calm smiling eyes and happy curved mouth
        // Left Eye (upward arch)
        final leftEye = Path()
          ..moveTo(w * 0.25, h * 0.42)
          ..quadraticBezierTo(w * 0.35, h * 0.48, w * 0.45, h * 0.42);
        canvas.drawPath(leftEye, paint);
        // Right Eye
        final rightEye = Path()
          ..moveTo(w * 0.55, h * 0.42)
          ..quadraticBezierTo(w * 0.65, h * 0.48, w * 0.75, h * 0.42);
        canvas.drawPath(rightEye, paint);

        // Smile Mouth
        final path = Path()
          ..moveTo(w * 0.32, h * 0.62)
          ..quadraticBezierTo(w * 0.5, h * 0.76, w * 0.68, h * 0.62);
        canvas.drawPath(path, paint);
        break;

      case 5:
        // Radiant: Squinting happy eyes (arches) and wide open smile
        // Left Eye arch
        final leftEye = Path()
          ..moveTo(w * 0.22, h * 0.42)
          ..quadraticBezierTo(w * 0.35, h * 0.3, w * 0.45, h * 0.42);
        canvas.drawPath(leftEye, paint);
        // Right Eye arch
        final rightEye = Path()
          ..moveTo(w * 0.55, h * 0.42)
          ..quadraticBezierTo(w * 0.65, h * 0.3, w * 0.78, h * 0.42);
        canvas.drawPath(rightEye, paint);

        // Wide Open Smile
        paint.style = PaintingStyle.fill;
        final path = Path()
          ..moveTo(w * 0.28, h * 0.58)
          ..quadraticBezierTo(w * 0.5, h * 0.85, w * 0.72, h * 0.58)
          ..close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant MoodFacePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}
