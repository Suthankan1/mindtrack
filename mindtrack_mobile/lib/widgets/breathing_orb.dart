import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';

/// Represents a single particle in the starburst completion animation.
class StarParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double rotation;
  double rotationSpeed;
  final Color color;
  final int type; // 0 = Circle, 1 = Diamond, 2 = Star
  final double maxLifespan;
  double lifespan;

  StarParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.color,
    required this.type,
    required this.maxLifespan,
    required this.lifespan,
    required this.rotation,
    required this.rotationSpeed,
  });

  bool update() {
    x += vx;
    y += vy;
    // Apply friction/drag
    vx *= 0.96;
    vy *= 0.96;
    // Add very light upward draft or gravity
    vy -= 0.04;
    
    lifespan -= 16.0; // Assume roughly 60fps frame time in ms
    alpha = math.max(0.0, lifespan / maxLifespan);
    rotation += rotationSpeed;
    return lifespan > 0;
  }
}

/// A high-fidelity, custom-painted breathing orb widget.
/// Implements dynamic morphing, pulsing glow effects, and a native starburst particle system.
class BreathingOrb extends StatefulWidget {
  final double scale;
  final Color startColor;
  final Color endColor;
  final bool isPlaying;
  final bool showStarburst;
  final double pulseValue;
  final VoidCallback onTap;

  const BreathingOrb({
    super.key,
    required this.scale,
    required this.startColor,
    required this.endColor,
    required this.isPlaying,
    required this.showStarburst,
    required this.pulseValue,
    required this.onTap,
  });

  @override
  State<BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<BreathingOrb>
    with SingleTickerProviderStateMixin {
  late Ticker _particleTicker;
  final List<StarParticle> _particles = [];
  final math.Random _random = math.Random();
  
  @override
  void initState() {
    super.initState();
    _particleTicker = createTicker((elapsed) {
      if (_particles.isEmpty) {
        _particleTicker.stop();
        return;
      }
      setState(() {
        _particles.removeWhere((p) => !p.update());
      });
    });
  }

  @override
  void didUpdateWidget(covariant BreathingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger the starburst when the completion flag is raised
    if (widget.showStarburst && !oldWidget.showStarburst) {
      _triggerStarburst();
    }
  }

  @override
  void dispose() {
    _particleTicker.dispose();
    super.dispose();
  }

  void _triggerStarburst() {
    _particles.clear();
    final colors = [
      widget.startColor,
      widget.endColor,
      const Color(0xFFFFD700), // Sparkling Gold
      Colors.white,
      AppColors.primaryColor,
    ];

    // Generate 75 particles for an epic and glowing burst
    for (int i = 0; i < 75; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 2.0 + _random.nextDouble() * 12.0;
      final maxLifespan = 1000.0 + _random.nextDouble() * 1500.0; // 1s to 2.5s

      _particles.add(
        StarParticle(
          x: 0,
          y: 0,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          size: 4.0 + _random.nextDouble() * 12.0,
          alpha: 1.0,
          color: colors[_random.nextInt(colors.length)],
          type: _random.nextInt(3), // Circle, Diamond, Star
          maxLifespan: maxLifespan,
          lifespan: maxLifespan,
          rotation: _random.nextDouble() * 2 * math.pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.15,
        ),
      );
    }

    if (!_particleTicker.isTicking) {
      _particleTicker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add dynamic micro-scaling based on the minor pulsing value (Hold or quiet phases)
    final double finalScale = widget.scale + (widget.pulseValue * 0.05);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 340,
        height: 340,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Custom Painter drawing the complex orb glow & organic layers
            CustomPaint(
              size: const Size(340, 340),
              painter: _OrbPainter(
                scale: finalScale,
                startColor: widget.startColor,
                endColor: widget.endColor,
                pulseValue: widget.pulseValue,
                isPlaying: widget.isPlaying,
                particles: _particles,
              ),
            ),

            // Inner Central Button (Material / Tap Target)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80 * finalScale,
              height: 80 * finalScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(
                  color: widget.startColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.startColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey<bool>(widget.isPlaying),
                    color: Colors.white,
                    size: 32 * math.max(0.8, finalScale * 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double scale;
  final Color startColor;
  final Color endColor;
  final double pulseValue;
  final bool isPlaying;
  final List<StarParticle> particles;

  const _OrbPainter({
    required this.scale,
    required this.startColor,
    required this.endColor,
    required this.pulseValue,
    required this.isPlaying,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 80.0 * scale;

    // 1. Draw outer glowing breathing ring (layered opacity)
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = startColor.withValues(alpha: 0.2);
    
    // Draw 3 soft halo rings expanding outwards
    canvas.drawCircle(center, baseRadius * 1.55, outerRingPaint);
    
    outerRingPaint.strokeWidth = 1.0;
    outerRingPaint.color = startColor.withValues(alpha: 0.1);
    canvas.drawCircle(center, baseRadius * 1.85, outerRingPaint);
    
    // 2. Draw glowing soft radial background under the orb
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          startColor.withValues(alpha: 0.35),
          endColor.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 2.2));
    
    canvas.drawCircle(center, baseRadius * 2.2, radialPaint);

    // 3. Draw middle soft organic glow layer
    final middleGlowPaint = Paint()
      ..color = startColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);
    canvas.drawCircle(center, baseRadius * 1.3, middleGlowPaint);

    // 4. Draw main solid morphing core
    final coreGradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 0.95,
      colors: [
        startColor,
        endColor,
        endColor.darken(0.3),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final corePaint = Paint()
      ..shader = coreGradient.createShader(Rect.fromCircle(center: center, radius: baseRadius));
    
    // Add high quality blur shadow manually using drop shadow paint
    final coreShadowPaint = Paint()
      ..color = startColor.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25.0);
    
    canvas.drawCircle(center, baseRadius, coreShadowPaint);
    canvas.drawCircle(center, baseRadius, corePaint);

    // 5. Draw concentric subtle ripple rings
    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawCircle(center, baseRadius * 0.95, ripplePaint);

    // 6. Draw particle systems above all elements
    if (particles.isNotEmpty) {
      for (final p in particles) {
        final particlePaint = Paint()
          ..color = p.color.withValues(alpha: p.alpha)
          ..style = PaintingStyle.fill;
        
        final double px = center.dx + p.x;
        final double py = center.dy + p.y;
        
        // Setup canvas transformation for rotation
        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(p.rotation);

        if (p.type == 0) {
          // Draw sparkling circle
          canvas.drawCircle(Offset.zero, p.size / 2, particlePaint);
        } else if (p.type == 1) {
          // Draw diamond shape
          final path = Path()
            ..moveTo(0, -p.size)
            ..lineTo(p.size * 0.6, 0)
            ..lineTo(0, p.size)
            ..lineTo(-p.size * 0.6, 0)
            ..close();
          canvas.drawPath(path, particlePaint);
        } else {
          // Draw 4-point glowing star
          final path = Path()
            ..moveTo(0, -p.size)
            ..quadraticBezierTo(0, 0, p.size, 0)
            ..quadraticBezierTo(0, 0, 0, p.size)
            ..quadraticBezierTo(0, 0, -p.size, 0)
            ..quadraticBezierTo(0, 0, 0, -p.size)
            ..close();
          canvas.drawPath(path, particlePaint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.particles != particles ||
        particles.isNotEmpty;
  }
}

// Helper extension on Color to darken
extension _ColorDarken on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsv = HSVColor.fromColor(this);
    final hsvDark = hsv.withValue(math.max(0.0, hsv.value - amount));
    return hsvDark.toColor();
  }
}
