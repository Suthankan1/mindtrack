import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/dio_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isObscured = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Common email regex validator
  bool _isValidEmail(String email) {
    return RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(email);
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      // Perform sign-in on the backend
      await dio.login(_emailController.text.trim(), _passwordController.text);

      // Mark onboarding as completed just in case
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      
      // Save profile info for personalized profile screen
      final emailVal = _emailController.text.trim();
      await prefs.setString('user_email', emailVal);
      if (prefs.getString('user_display_name') == null) {
        // Fallback display name from email prefix
        final namePart = emailVal.split('@').first;
        final capitalized = namePart.isNotEmpty 
            ? '${namePart[0].toUpperCase()}${namePart.substring(1)}'
            : 'Cosmic Practitioner';
        await prefs.setString('user_display_name', capitalized);
      }
      if (prefs.getString('user_join_date') == null) {
        await prefs.setString('user_join_date', DateTime.now().toIso8601String());
      }

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAnonymousAccess() async {
    if (_isLoading) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = math.Random().nextInt(100000);
    final anonEmail = 'anonymous_${timestamp}_$randomPart@mindtrack.com';
    final anonPassword = 'anon_secure_pass_$timestamp';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      // Register with anonymousMode = true
      await dio.register(anonEmail, anonPassword, anonymousMode: true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      // Save anonymous profile info
      await prefs.setString('user_email', anonEmail);
      await prefs.setString('user_display_name', 'Cosmic Traveler');
      if (prefs.getString('user_join_date') == null) {
        await prefs.setString('user_join_date', DateTime.now().toIso8601String());
      }

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo / Greeting Text
                  Text(
                    'Welcome Back',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the sanctuary to resume tracking your pulse.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Error Message Banner (if any)
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.errorColor.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.errorColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.errorColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Email Address Input Field (Custom styled, underline-only, teal focus)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      hintText: 'name@example.com',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      floatingLabelStyle: const TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.borderOverlay,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primaryColor,
                          width: 2.0,
                        ),
                      ),
                      errorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.errorColor,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.errorColor,
                          width: 2.0,
                        ),
                      ),
                      errorStyle: const TextStyle(color: AppColors.errorColor),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email address';
                      }
                      if (!_isValidEmail(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Password Input Field (Underline-only, teal focus, obscure toggle)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscured,
                    autofillHints: const [AutofillHints.password],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      floatingLabelStyle: const TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isObscured = !_isObscured;
                          });
                        },
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.borderOverlay,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primaryColor,
                          width: 2.0,
                        ),
                      ),
                      errorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.errorColor,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.errorColor,
                          width: 2.0,
                        ),
                      ),
                      errorStyle: const TextStyle(color: AppColors.errorColor),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password recovery is not supported in this version.',
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Action Buttons stacked
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    )
                  else ...[
                    // Primary neon Sign In button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.backgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // "Continue anonymously" secondary flat text button
                    Center(
                      child: TextButton(
                        onPressed: _handleAnonymousAccess,
                        child: const Text(
                          'Continue anonymously',
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // Route link to Register Screen
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/register'),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
