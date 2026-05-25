import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/breathing_orb.dart';
import '../services/dio_service.dart';
import '../providers/mood_provider.dart';

enum BreathingPhase { inhale, holdFull, exhale, holdEmpty }

/// A single time-boxed phase within a [BreathingTechnique] (e.g. Inhale 4s).
///
/// Carries its label text, visual colors for the orb, and duration.
class BreathingStep {
  final BreathingPhase phase;
  final int durationSeconds;
  final String label;
  final String subLabel;
  final Color startColor;
  final Color endColor;

  const BreathingStep({
    required this.phase,
    required this.durationSeconds,
    required this.label,
    required this.subLabel,
    required this.startColor,
    required this.endColor,
  });
}

/// Represents a named multi-phase breathing exercise (e.g. Box Breathing).
///
/// Contains an ordered list of [BreathingStep]s and computes [totalCycleDuration].
class BreathingTechnique {
  final String name;
  final String subtitle;
  final List<BreathingStep> steps;

  const BreathingTechnique({
    required this.name,
    required this.subtitle,
    required this.steps,
  });

  int get totalCycleDuration => steps.fold(0, (sum, step) => sum + step.durationSeconds);
}

/// The Breathe tab — a guided breathing exercise screen.
///
/// Manages three selectable [BreathingTechnique]s (4-7-8, Box, Deep).
/// Drives the [BreathingOrb] with a phase [AnimationController] and advances
/// through [BreathingStep]s automatically, logging a coping session to the
/// backend after 3 completed cycles.
class BreatheScreen extends ConsumerStatefulWidget {
  const BreatheScreen({super.key});

  @override
  ConsumerState<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends ConsumerState<BreatheScreen>
    with TickerProviderStateMixin {
  
  // Techniques Configuration
  static const List<BreathingTechnique> _techniques = [
    BreathingTechnique(
      name: '4-7-8 Technique',
      subtitle: 'Dr. Weil’s classic for deep anxiety relief',
      steps: [
        BreathingStep(
          phase: BreathingPhase.inhale,
          durationSeconds: 4,
          label: 'Breathe In...',
          subLabel: 'Fill your lungs quietly through your nose',
          startColor: Color(0xFF00D2C8), // Teal
          endColor: Color(0xFF008080),
        ),
        BreathingStep(
          phase: BreathingPhase.holdFull,
          durationSeconds: 7,
          label: 'Hold...',
          subLabel: 'Suspend the breath with absolute calm',
          startColor: Color(0xFF9D4EDD), // Violet
          endColor: Color(0xFF5A189A),
        ),
        BreathingStep(
          phase: BreathingPhase.exhale,
          durationSeconds: 8,
          label: 'Breathe Out...',
          subLabel: 'Exhale completely with a whoosh sound',
          startColor: Color(0xFFFF70A6), // Coral
          endColor: Color(0xFFFF9770),
        ),
      ],
    ),
    BreathingTechnique(
      name: 'Box Breathing 4-4-4-4',
      subtitle: 'Navy SEAL method for instant cognitive clarity',
      steps: [
        BreathingStep(
          phase: BreathingPhase.inhale,
          durationSeconds: 4,
          label: 'Breathe In...',
          subLabel: 'Inhale steadily counting to four',
          startColor: Color(0xFF00D2C8), // Teal
          endColor: Color(0xFF008080),
        ),
        BreathingStep(
          phase: BreathingPhase.holdFull,
          durationSeconds: 4,
          label: 'Hold...',
          subLabel: 'Suspend breath with lungs full',
          startColor: Color(0xFF9D4EDD), // Violet
          endColor: Color(0xFF5A189A),
        ),
        BreathingStep(
          phase: BreathingPhase.exhale,
          durationSeconds: 4,
          label: 'Breathe Out...',
          subLabel: 'Release breath slowly and completely',
          startColor: Color(0xFFFF70A6), // Coral
          endColor: Color(0xFFFF9770),
        ),
        BreathingStep(
          phase: BreathingPhase.holdEmpty,
          durationSeconds: 4,
          label: 'Hold...',
          subLabel: 'Stay empty before the next breath',
          startColor: Color(0xFF4361EE), // Royal Indigo
          endColor: Color(0xFF3F37C9),
        ),
      ],
    ),
    BreathingTechnique(
      name: 'Deep Breathing 5-5',
      subtitle: 'Resonant breathing to balance nervous system',
      steps: [
        BreathingStep(
          phase: BreathingPhase.inhale,
          durationSeconds: 5,
          label: 'Breathe In...',
          subLabel: 'Deep, slow inhalation',
          startColor: Color(0xFF00D2C8), // Teal
          endColor: Color(0xFF008080),
        ),
        BreathingStep(
          phase: BreathingPhase.exhale,
          durationSeconds: 5,
          label: 'Breathe Out...',
          subLabel: 'Gentle, soothing exhalation',
          startColor: Color(0xFFFF70A6), // Coral
          endColor: Color(0xFFFF9770),
        ),
      ],
    ),
  ];

  int _selectedTechniqueIndex = 0;
  BreathingTechnique get _currentTechnique => _techniques[_selectedTechniqueIndex];

  // Animation Controllers
  late AnimationController _phaseController; // Drives active phase timing
  late AnimationController _pulseController; // Constant tiny organic pulse (1Hz)
  late AnimationController _bgController;    // Drives background shifting

  // State Variables
  bool _isPlaying = false;
  int _currentStepIndex = 0;
  int _completedCycles = 0;
  
  // Timers
  Timer? _sessionTimer;
  int _sessionDurationSeconds = 0;
  
  // Starburst Trigger
  bool _showStarburst = false;
  bool _isSavingSession = false;
  bool _hasLoggedCompletion = false;
  bool _sessionSyncFailed = false;

  // Secondary overlay for mindfulness completion report
  bool _showCompletionCard = false;

  // AI Recommendation State Variables
  bool _isLoadingRecommendation = false;
  Map<String, dynamic>? _aiRecommendation;
  String? _recommendationError;

  @override
  void initState() {
    super.initState();

    // Set up phase controller with default duration
    _phaseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _currentTechnique.steps[0].durationSeconds),
    );

    // Minor continuous breathing pulse for holding/relaxing states
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Background color morphing controller
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Listen for phase timing completions
    _phaseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _advanceStep();
      }
    });

    // Fetch AI recommendation on screen initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAiRecommendation();
    });
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _pulseController.dispose();
    _bgController.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // Session Duration Timer
  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying) {
        setState(() {
          _sessionDurationSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  // Toggle exercise state
  void _togglePlayPause() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_sessionTimer == null) _startTimer();
        _phaseController.forward();
      } else {
        _phaseController.stop();
      }
    });
  }

  // Advance to the next step of the technique
  void _advanceStep() {
    if (!mounted) return;
    
    // Play subtle haptic tick to announce step shift
    HapticFeedback.lightImpact();

    setState(() {
      _currentStepIndex++;
      
      // Complete full cycle (rep)
      if (_currentStepIndex >= _currentTechnique.steps.length) {
        _currentStepIndex = 0;
        _completedCycles++;

        // Trigger Milestone rewards at 3 cycles
        if (_completedCycles == 3 && !_hasLoggedCompletion) {
          _handleMilestoneReached();
        }
      }

      // Configure next step timings
      final nextStep = _currentTechnique.steps[_currentStepIndex];
      _phaseController.reset();
      _phaseController.duration = Duration(seconds: nextStep.durationSeconds);
      
      if (_isPlaying) {
        _phaseController.forward();
      }
    });
  }

  // Action executed upon hitting 3 completed cycles
  void _handleMilestoneReached() {
    _hasLoggedCompletion = true;
    _showStarburst = true;
    HapticFeedback.heavyImpact();

    // Auto-log to backend in background
    _logSessionToBackend();

    // Reveal final completion overlay card after 1.5 seconds so they enjoy the starburst
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _showCompletionCard = true;
          _isPlaying = false;
          _phaseController.stop();
          _stopTimer();
        });
      }
    });

    // Reset starburst trigger so it can fire again
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showStarburst = false;
        });
      }
    });
  }

  // Request to log the coping session using Dio
  Future<void> _logSessionToBackend() async {
    setState(() {
      _isSavingSession = true;
      _sessionSyncFailed = false;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      // logCopingSession returns {} on failure — it never throws.
      final result = await dio.logCopingSession(
        type: 'breathing',
        durationSeconds: _sessionDurationSeconds,
      );
      // An empty map means the service swallowed an error; surface it.
      if (result.isEmpty) {
        debugPrint('BreatheScreen: coping session log returned empty — treating as non-fatal failure.');
        if (mounted) {
          setState(() {
            _sessionSyncFailed = true;
          });
        }
      }
    } catch (e) {
      // Should not happen given DioService's defensive return, but guard anyway.
      debugPrint('BreatheScreen: Unexpected error during coping session log: $e');
      if (mounted) {
        setState(() {
          _sessionSyncFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSession = false;
        });
      }
    }
  }

  // Change active technique
  void _changeTechnique(int index) {
    if (_isPlaying) {
      _togglePlayPause();
    }
    
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTechniqueIndex = index;
      _currentStepIndex = 0;
      _completedCycles = 0;
      _sessionDurationSeconds = 0;
      _hasLoggedCompletion = false;
      _showCompletionCard = false;
      _sessionSyncFailed = false;
      
      // Update duration config
      _phaseController.reset();
      _phaseController.duration = Duration(
        seconds: _currentTechnique.steps[0].durationSeconds,
      );
    });
  }

  // Reset session manually
  void _resetSession() {
    HapticFeedback.mediumImpact();
    _stopTimer();
    setState(() {
      _isPlaying = false;
      _currentStepIndex = 0;
      _completedCycles = 0;
      _sessionDurationSeconds = 0;
      _hasLoggedCompletion = false;
      _showCompletionCard = false;
      _sessionSyncFailed = false;
      _phaseController.reset();
      _phaseController.duration = Duration(
        seconds: _currentTechnique.steps[0].durationSeconds,
      );
    });
  }

  // Compute active scale based on current phase
  double _calculateScale() {
    final step = _currentTechnique.steps[_currentStepIndex];
    final double value = _phaseController.value;

    switch (step.phase) {
      case BreathingPhase.inhale:
        // Expand orb smoothly from 0.8 to 1.4
        return 0.8 + (0.6 * Curves.easeInOutCubic.transform(value));
      case BreathingPhase.holdFull:
        // Suspend at maximum scale 1.4
        return 1.4;
      case BreathingPhase.exhale:
        // Contract orb smoothly from 1.4 down to 0.8
        return 1.4 - (0.6 * Curves.easeInOutCubic.transform(value));
      case BreathingPhase.holdEmpty:
        // Suspend at minimum scale 0.8
        return 0.8;
    }
  }

  // Format seconds into MM:SS format
  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }

  Future<void> _fetchAiRecommendation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecommendation = true;
      _recommendationError = null;
    });

    try {
      // Get current mood from todayMoodProvider
      final todayMood = ref.read(todayMoodProvider).value;
      final moodScore = todayMood ?? 3; // Default to 3 if no log today

      final timeOfDay = _getTimeOfDay();

      // Compute recent average and last tags from mood history
      final history = ref.read(moodHistoryProvider).value ?? [];
      double recentAverage = 3.0;
      List<String> lastTags = [];

      if (history.isNotEmpty) {
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        final recentEntries = history.where((e) => e.timestamp.isAfter(sevenDaysAgo)).toList();

        if (recentEntries.isNotEmpty) {
          final sum = recentEntries.map((e) => e.moodScore).reduce((a, b) => a + b);
          recentAverage = sum / recentEntries.length;
          lastTags = recentEntries.expand((e) => e.tags).toSet().toList();
        } else {
          final sum = history.map((e) => e.moodScore).reduce((a, b) => a + b);
          recentAverage = sum / history.length;
          lastTags = history.expand((e) => e.tags).toSet().toList();
        }
      }

      final dio = ref.read(dioServiceProvider);
      final suggestion = await dio.getAiCopingSuggestion(
        moodScore: moodScore,
        timeOfDay: timeOfDay,
        recentAverage: recentAverage,
        lastTags: lastTags,
      );

      if (mounted) {
        setState(() {
          _aiRecommendation = suggestion;
          _isLoadingRecommendation = false;

          // Pre-select recommended technique if applicable
          final tech = suggestion['technique'] as String?;
          int? recommendedIndex;
          if (tech == 'breathing_478') {
            recommendedIndex = 0;
          } else if (tech == 'breathing_box') {
            recommendedIndex = 1;
          } else if (tech == 'breathing_deep') {
            recommendedIndex = 2;
          }

          if (recommendedIndex != null && recommendedIndex != _selectedTechniqueIndex) {
            _changeTechnique(recommendedIndex);
          }
        });
      }
    } catch (e) {
      debugPrint('BreatheScreen: Failed to get AI coping suggestion: $e');
      if (mounted) {
        setState(() {
          _recommendationError = e.toString();
          _isLoadingRecommendation = false;
        });
      }
    }
  }

  Widget _buildAiRecommendationCard(ThemeData theme) {
    if (_isLoadingRecommendation) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.borderOverlay,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primaryColor),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Personalizing your sanctuary with Gemini...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_aiRecommendation == null) {
      return const SizedBox.shrink();
    }

    final suggestion = _aiRecommendation!;
    final techniqueId = suggestion['technique'] as String? ?? '';
    final reason = suggestion['reason'] as String? ?? '';
    final encouragement = suggestion['encouragement'] as String? ?? '';
    final duration = suggestion['durationMinutes'] as int? ?? 5;

    String humanName = 'Mindful Exercise';
    IconData techniqueIcon = Icons.spa_rounded;
    if (techniqueId == 'breathing_478') {
      humanName = '4-7-8 Breathing';
      techniqueIcon = Icons.air_rounded;
    } else if (techniqueId == 'breathing_box') {
      humanName = 'Box Breathing (4-4-4-4)';
      techniqueIcon = Icons.grid_view_rounded;
    } else if (techniqueId == 'breathing_deep') {
      humanName = 'Deep Breathing (5-5)';
      techniqueIcon = Icons.favorite_rounded;
    } else if (techniqueId == 'grounding') {
      humanName = '5-4-3-2-1 Sensory Grounding';
      techniqueIcon = Icons.self_improvement_rounded;
    } else if (techniqueId == 'journaling') {
      humanName = 'Guided Journal Prompt';
      techniqueIcon = Icons.edit_note_rounded;
    } else if (techniqueId == 'walk') {
      humanName = 'Mindful Nature Walk';
      techniqueIcon = Icons.directions_walk_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceColor,
              AppColors.surfaceColor.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RECOMMENDED FOR YOU',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${duration}m',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  techniqueIcon,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    humanName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              encouragement,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStep = _currentTechnique.steps[_currentStepIndex];
    final currentScale = _calculateScale();

    // Determine blended ambient background colors
    final ambientColor = currentStep.startColor.withValues(alpha: 0.08);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Ambient Background Layer (Animated Shifts)
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              // Create slow rotating background tint
              final angle = _bgController.value * 2 * math.pi;
              final alignmentX = math.cos(angle) * 0.4;
              final alignmentY = math.sin(angle) * 0.4;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(alignmentX, alignmentY - 0.2),
                    radius: 1.6,
                    colors: [
                      ambientColor,
                      AppColors.backgroundColor,
                    ],
                    stops: const [0.0, 0.85],
                  ),
                ),
              );
            },
          ),

          // 2. Main Content ScrollView / Screen Elements
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Space
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calm Sanctuary',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sync your breathing, soothe your mind.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      
                      // Refresh/Reset Button when active
                      if (_isPlaying || _sessionDurationSeconds > 0)
                        IconButton(
                          onPressed: _resetSession,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                          tooltip: 'Reset Exercise',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _buildAiRecommendationCard(theme),

                const SizedBox(height: 8),

                // Technique Selection Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(
                        _techniques.length,
                        (index) => _buildTechniqueChip(index),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Morphing Breathing Orb
                Center(
                  child: BreathingOrb(
                    scale: currentScale,
                    startColor: currentStep.startColor,
                    endColor: currentStep.endColor,
                    isPlaying: _isPlaying,
                    showStarburst: _showStarburst,
                    pulseValue: _pulseController.value,
                    onTap: _togglePlayPause,
                  ),
                ),

                const Spacer(),

                // State Text Labels (with animation transition)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.1),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _isPlaying ? currentStep.label : 'Tap Orb to Begin',
                          key: ValueKey<String>(_isPlaying ? currentStep.label : 'paused'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: currentStep.startColor.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isPlaying
                              ? currentStep.subLabel
                              : 'Recommended duration: 3 full cycles',
                          key: ValueKey<String>(
                            _isPlaying ? currentStep.subLabel : 'paused_sub',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Stats Dashboard Row (Timer, Current Step Progress, Rep Counter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.borderOverlay.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatBox(
                          title: 'SESSION',
                          value: _formatTimer(_sessionDurationSeconds),
                          icon: Icons.timer_outlined,
                          color: AppColors.primaryColor,
                        ),
                        _buildDivider(),
                        _buildStatBox(
                          title: 'CYCLES',
                          value: '$_completedCycles / 3',
                          icon: Icons.repeat_rounded,
                          color: const Color(0xFFFFD700), // Star Gold
                        ),
                        _buildDivider(),
                        _buildStatBox(
                          title: 'ACTIVE PHASE',
                          value: '${currentStep.durationSeconds}s',
                          icon: Icons.insights_rounded,
                          color: currentStep.startColor,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // 3. Completion Reward Modal (Overlay)
          if (_showCompletionCard)
            _buildCompletionOverlay(theme),
        ],
      ),
    );
  }

  // Technique Chip Builder
  Widget _buildTechniqueChip(int index) {
    final technique = _techniques[index];
    final isSelected = _selectedTechniqueIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () => _changeTechnique(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryColor.withValues(alpha: 0.12)
                : AppColors.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryColor.withValues(alpha: 0.45)
                  : AppColors.borderOverlay,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                technique.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${technique.totalCycleDuration}s per cycle',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.primaryColor.withValues(alpha: 0.85)
                      : AppColors.textMuted.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Stat item builder
  Widget _buildStatBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'ClashDisplay',
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1.5,
      height: 36,
      color: AppColors.borderOverlay.withValues(alpha: 0.6),
    );
  }

  // Completion modal overlay
  Widget _buildCompletionOverlay(ThemeData theme) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        key: const ValueKey('completion_card_view'),
        child: Container(
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.45),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glowing ring
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.primaryColor,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: AppColors.primaryColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Calm Achieved',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have completed the recommended 3 breathing cycles. Great job taking this time for your wellbeing!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // Local loading indicator for backend sync
              if (_isSavingSession)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Saving practice details...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                )
              else if (_sessionSyncFailed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Couldn't save session — check your connection",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_done_outlined,
                      size: 14,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Session synced successfully',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showCompletionCard = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.borderOverlay, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Reflect',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _resetSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.backgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Practice Again',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
