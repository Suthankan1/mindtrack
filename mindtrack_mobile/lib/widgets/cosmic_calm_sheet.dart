import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class CosmicCalmSheet extends StatelessWidget {
  final Map<String, dynamic> reflection;

  const CosmicCalmSheet({super.key, required this.reflection});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;

    final oneSentenceReflection = reflection['oneSentenceReflection'] as String? ?? 
        "Take a slow, deep breath and ground yourself in this moment.";
    final suggestedNextStep = reflection['suggestedNextStep'] as String? ?? 
        "Practice a gentle breathing pattern to help restore balance.";
    final recommendedTechnique = reflection['recommendedTechnique'] as String? ?? "breathing_deep";
    final showCrisisResources = reflection['showCrisisResources'] as bool? ?? false;

    // Map recommended technique name, icon, and navigation route
    String techniqueName = 'Deep Breathing';
    IconData techniqueIcon = Icons.spa_rounded;
    String routePath = '/breathe';
    String actionLabel = 'Practice Breathing';

    if (recommendedTechnique == 'breathing_478') {
      techniqueName = '4-7-8 Breathing';
      techniqueIcon = Icons.air_rounded;
      routePath = '/breathe';
      actionLabel = 'Practice 4-7-8';
    } else if (recommendedTechnique == 'breathing_box') {
      techniqueName = 'Box Breathing (4-4-4-4)';
      techniqueIcon = Icons.grid_view_rounded;
      routePath = '/breathe';
      actionLabel = 'Start Box Breathing';
    } else if (recommendedTechnique == 'breathing_deep') {
      techniqueName = 'Deep Breathing (5-5)';
      techniqueIcon = Icons.favorite_rounded;
      routePath = '/breathe';
      actionLabel = 'Breathe Soothingly';
    } else if (recommendedTechnique == 'grounding') {
      techniqueName = '5-4-3-2-1 Sensory Grounding';
      techniqueIcon = Icons.self_improvement_rounded;
      routePath = '/breathe'; // Also selectable inside breathe screen
      actionLabel = 'Ground Yourself';
    } else if (recommendedTechnique == 'journaling') {
      techniqueName = 'Guided Journaling';
      techniqueIcon = Icons.edit_note_rounded;
      routePath = '/journal';
      actionLabel = 'Write in Journal';
    } else if (recommendedTechnique == 'walk') {
      techniqueName = 'Mindful Nature Walk';
      techniqueIcon = Icons.directions_walk_rounded;
      routePath = '/breathe';
      actionLabel = 'Begin Mindful Walk';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isLightTheme ? const Color(0xFFF4F6FC) : AppColors.backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(
          color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pull bar / drag handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: (isLightTheme ? const Color(0xFF8B8BBA) : AppColors.textMuted).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Empathy Graphic / Star Orb
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primaryColor,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Warm Header Title
            Center(
              child: Text(
                'Cosmic Reflection',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Reflection Card
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AI Reflection Body
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isLightTheme ? Colors.white : AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isLightTheme ? const Color(0xFFE0E4F2) : AppColors.borderOverlay,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isLightTheme ? 0.02 : 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            oneSentenceReflection,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                              height: 1.5,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.borderOverlay, height: 1),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.wb_sunny_outlined,
                                color: AppColors.primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  suggestedNextStep,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isLightTheme ? const Color(0xFF4A4A68) : AppColors.textMuted,
                                    height: 1.45,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recommended Coping Technique Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isLightTheme
                              ? [Colors.white, const Color(0xFFEFF3FB)]
                              : [AppColors.surfaceColor, AppColors.surfaceColor.withValues(alpha: 0.7)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: AppColors.primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'RECOMMENDED TECHNIQUE',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                techniqueIcon,
                                color: isLightTheme ? const Color(0xFF4A4A68) : Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  techniqueName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isLightTheme ? const Color(0xFF0A0A14) : Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Show crisis card if flag is enabled
                    if (showCrisisResources) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.errorColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  color: AppColors.errorColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'We care about your safety',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppColors.errorColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'If you are feeling extremely overwhelmed or are in distress, please consider seeking immediate support. Help is always available.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isLightTheme ? const Color(0xFF6B2D2D) : Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(routePath);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            
            if (showCrisisResources) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/profile/therapists');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorColor,
                  side: const BorderSide(color: AppColors.errorColor, width: 2),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Access Support Directory',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: isLightTheme ? const Color(0xFF4A4A68) : AppColors.textMuted,
              ),
              child: const Text(
                'Acknowledge & Close',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
