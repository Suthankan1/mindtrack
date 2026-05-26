import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/mood_ring.dart';
import '../widgets/constellation_canvas.dart';
import '../widgets/breathing_orb.dart';
import '../providers/mood_provider.dart';
import '../services/dio_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRegisteringAnon = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Generates 5 mock entries to preview the constellation canvas beautifully
  List<MoodEntry> _getMockConstellationEntries() {
    final now = DateTime.now();
    return [
      MoodEntry(
        id: 'mock-1',
        userId: 'user',
        moodScore: 4,
        note: 'Grateful for a fresh start',
        timestamp: now.subtract(const Duration(days: 4)),
        tags: ['Grateful', 'Calm'],
      ),
      MoodEntry(
        id: 'mock-2',
        userId: 'user',
        moodScore: 3,
        note: 'Feeling slightly reflective',
        timestamp: now.subtract(const Duration(days: 3)),
        tags: ['Reflective'],
      ),
      MoodEntry(
        id: 'mock-3',
        userId: 'user',
        moodScore: 5,
        note: 'Full of creative energy today!',
        timestamp: now.subtract(const Duration(days: 2)),
        tags: ['Creative', 'Inspired'],
      ),
      MoodEntry(
        id: 'mock-4',
        userId: 'user',
        moodScore: 2,
        note: 'A bit drained in the evening',
        timestamp: now.subtract(const Duration(days: 1)),
        tags: ['Tired'],
      ),
      MoodEntry(
        id: 'mock-5',
        userId: 'user',
        moodScore: 4,
        note: 'Regained focus and peace',
        timestamp: now,
        tags: ['Peaceful'],
      ),
    ];
  }

  Future<void> _handleAnonymousAccess() async {
    if (_isRegisteringAnon) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = math.Random().nextInt(100000);
    final anonEmail = 'anonymous_${timestamp}_$randomPart@mindtrack.com';
    final anonPassword = 'anon_secure_pass_$timestamp';

    setState(() {
      _isRegisteringAnon = true;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      // Register with anonymousMode: true, saving token automatically
      await dio.register(anonEmail, anonPassword, anonymousMode: true);

      // Save onboarding completion flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', anonEmail);
      await prefs.setBool('onboarding_complete_$anonEmail', true);
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to establish anonymous session: ${e.toString()}'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRegisteringAnon = false;
        });
      }
    }
  }

  Future<void> _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    if (email.isNotEmpty) {
      await prefs.setBool('onboarding_complete_$email', true);
    }
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    final token = prefs.getString('auth_jwt_token');
    if (token != null && email.isNotEmpty) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. PageView for swipeable slides
            PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                // Card 1: Emotional Pulse
                _buildOnboardingCard(
                  child: const SizedBox(
                    height: 240,
                    child: Center(
                      child: MoodRing(moodScore: 5),
                    ),
                  ),
                  title: 'Track your emotional pulse',
                  subtitle: 'Check in with your feelings daily. Observe patterns, log mood triggers, and track the flow of your emotional well-being.',
                ),

                // Card 2: Constellation Star Patterns
                _buildOnboardingCard(
                  child: SizedBox(
                    height: 240,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ConstellationCanvas(
                          entries: _getMockConstellationEntries(),
                          onDotTapped: (entry) {
                            // Secondary visual interactions
                          },
                        ),
                      ),
                    ),
                  ),
                  title: 'See your patterns in the stars',
                  subtitle: 'Watch your logs weave together into celestial constellations. Uncover deeper cycles and emotional rhythms over time.',
                ),

                // Card 3: Breathing orb animation
                _buildOnboardingCard(
                  child: const SizedBox(
                    height: 240,
                    child: Center(
                      child: AutoBreathingOrb(),
                    ),
                  ),
                  title: 'Find your calm',
                  subtitle: 'Align your posture and take a slow breath. Restore clarity and center your mind with relaxing, guided breathing sessions.',
                ),
              ],
            ),

            // 2. Persistent Top Header Bar (Brand Name & Faint Line)
            Positioned(
              top: 12,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MINDTRACK',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Bottom controls (Dots indicators and Navigation Action buttons)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => _buildPageDot(index)),
                  ),
                  const SizedBox(height: 36),

                  // Bottom Action Buttons
                  if (_currentPage < 2)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _skipOnboarding,
                          child: const Text(
                            'Skip All',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: AppColors.borderOverlay,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            children: [
                              Text('Next'),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        if (_isRegisteringAnon)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryColor,
                            ),
                          )
                        else ...[
                          // "Get Started" Primary Neon button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryColor.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final email = prefs.getString('user_email') ?? '';
                                  if (email.isNotEmpty) {
                                    await prefs.setBool('onboarding_complete_$email', true);
                                  }
                                  await prefs.setBool('onboarding_completed', true);
                                  if (!context.mounted) return;
                                  final token = prefs.getString('auth_jwt_token');
                                  if (token != null && email.isNotEmpty) {
                                    context.go('/home');
                                  } else {
                                    context.go('/login');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: AppColors.backgroundColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // "Use Anonymously" Secondary Text Button
                          TextButton(
                            onPressed: _handleAnonymousAccess,
                            child: const Text(
                              'Use Anonymously',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 6.0,
      width: isActive ? 20.0 : 6.0,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryColor
            : AppColors.textMuted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildOnboardingCard({
    required Widget child,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic container
          child,
          const SizedBox(height: 48),

          // Title (ClashDisplay typography via custom Theme settings)
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle description (DM Sans text)
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

/// A high-fidelity animated Breathing Orb proxy that manages its own pulsing
/// animation to present the third onboarding card cleanly without complexity.
class AutoBreathingOrb extends StatefulWidget {
  const AutoBreathingOrb({super.key});

  @override
  State<AutoBreathingOrb> createState() => _AutoBreathingOrbState();
}

class _AutoBreathingOrbState extends State<AutoBreathingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.82, end: 1.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 0.82)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(_controller);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Keep the orb breathing automatically in a beautiful endless cycle
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return BreathingOrb(
          scale: _scaleAnim.value,
          startColor: AppColors.primaryColor,
          endColor: const Color(0xFF005B60), // Beautiful deep teal gradient end
          isPlaying: true,
          showStarburst: false,
          pulseValue: _pulseAnim.value,
          onTap: () {
            // Static display only
          },
        );
      },
    );
  }
}
