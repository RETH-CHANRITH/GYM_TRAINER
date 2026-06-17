import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../controllers/login_controller.dart';
import '../../../routes/app_router.dart' show Routes;
import '../../../../config/glass_ui.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    // Schedule checking extra arguments after build to avoid GoRouterState context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final state = GoRouterState.of(context);
        final extra = state.extra as Map<String, dynamic>?;
        if (extra != null && extra['email'] != null) {
          _emailController.text = extra['email'];
        }
      } catch (_) {
        // Safe to ignore if GoRouterState is not present
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginNotifierProvider);
    final notifier = ref.read(loginNotifierProvider.notifier);
    final kNeon = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(title: 'Welcome Back', onBack: () => context.pop()),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Glass logo icon
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: glassDecoration(
                            radius: 24,
                            glowColor: kNeon,
                          ),
                          child: ShaderMask(
                            shaderCallback:
                                (b) => LinearGradient(
                                  colors: [Colors.white, kNeon],
                                ).createShader(b),
                            child: const Icon(
                              Icons.fitness_center_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Title
                  ShaderMask(
                    shaderCallback:
                        (b) => LinearGradient(
                          colors: [Colors.white, kNeon],
                        ).createShader(b),
                    child: Text(
                      'Welcome\nBack',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 46,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to your account',
                    style: GoogleFonts.dmSans(color: kMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // Email
                  Text(
                    'Email Address',
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: glassFieldDecoration(
                          hint: 'Enter your email',
                          icon: CupertinoIcons.mail,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Password
                  Text(
                    'Password',
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: glassFieldDecoration(
                          hint: 'Enter your password',
                          icon: CupertinoIcons.lock,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(Routes.FORGOT_PASSWORD),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.dmSans(
                          color: kNeon.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login CTA
                  neonButton(
                    label: 'Login',
                    onPressed: () => notifier.login(
                      context,
                      _emailController.text,
                      _passwordController.text,
                    ),
                    child: loginState.isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: kInk,
                            strokeWidth: 2.5,
                          ),
                        )
                        : Text(
                          'Login',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                  ),
                  const SizedBox(height: 22),

                  // OR divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.1)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: GoogleFonts.dmSans(
                            color: kMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Google sign-in
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.30),
                            ),
                            backgroundColor: Colors.white.withOpacity(0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: () => notifier.signInWithGoogle(context),
                          child: loginState.isGoogleLoading
                              ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: kNeon,
                                  strokeWidth: 2.5,
                                ),
                              )
                              : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/google_logo.svg',
                                    width: 22,
                                    height: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Sign-up link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.dmSans(
                            color: kMuted,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(Routes.SIGN_UP),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.dmSans(
                              color: kNeon,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}
