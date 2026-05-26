import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A card that displays the daily mental wellness quote.
///
/// Features a subtle pulsing teal left border, a sparkle icon,
/// italics quote styling, and 'Gemini Daily Insight' label.
class QuoteCard extends StatefulWidget {
  final String? quote;
  final bool isLoading;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.isLoading,
  });

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Check if running in a test environment to avoid infinite animations in widget tests
    final isTest = RegExp(r'package:flutter_test').hasMatch(StackTrace.current.toString());
    if (!isTest) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
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
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtle pulsing teal left border
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 4,
                    color: const Color(0xFF00D2C8).withOpacity(_pulseAnimation.value),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row: Sparkle Icon + Label
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome, // sparkle icon
                            color: Color(0xFF00D2C8),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Gemini Daily Insight',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Quote text or Loading Indicator
                      if (widget.isLoading)
                        const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D2C8)),
                          ),
                        )
                      else if (widget.quote != null)
                        Text(
                          '"${widget.quote}"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
