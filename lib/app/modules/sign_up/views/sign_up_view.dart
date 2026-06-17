import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../controllers/sign_up_controller.dart';
import '../../../routes/app_router.dart' show Routes;
import '../../../../config/glass_ui.dart';

class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(signUpNotifierProvider);
    final notifier = ref.read(signUpNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(title: 'Create Account', onBack: () => context.pop()),
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
                            glowColor: kLilac,
                          ),
                          child: ShaderMask(
                            shaderCallback:
                                (b) => const LinearGradient(
                                  colors: [Colors.white, kLilac],
                                ).createShader(b),
                            child: const Icon(
                              Icons.account_circle,
                              size: 54,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  ShaderMask(
                    shaderCallback:
                        (b) => const LinearGradient(
                          colors: [Colors.white, kLilac],
                        ).createShader(b),
                    child: Text(
                      'Create\nAccount',
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
                    'Join us and start your fitness journey',
                    style: GoogleFonts.dmSans(color: kMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // Full Name
                  _fieldLabel('Full Name'),
                  const SizedBox(height: 8),
                  _glassField(
                    ctrl: _nameController,
                    hint: 'Enter your full name',
                    icon: CupertinoIcons.person,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _fieldLabel('Email Address'),
                  const SizedBox(height: 8),
                  _glassField(
                    ctrl: _emailController,
                    hint: 'Enter your email',
                    icon: CupertinoIcons.mail,
                    type: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  _fieldLabel('Password'),
                  const SizedBox(height: 8),
                  _glassField(
                    ctrl: _passwordController,
                    hint: 'Create a password',
                    icon: CupertinoIcons.lock,
                    obscure: true,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  _fieldLabel('Confirm Password'),
                  const SizedBox(height: 8),
                  _glassField(
                    ctrl: _confirmPasswordController,
                    hint: 'Re-enter your password',
                    icon: CupertinoIcons.lock_shield,
                    obscure: true,
                  ),
                  const SizedBox(height: 28),

                  // Create Account CTA
                  neonButton(
                    label: 'Create Account',
                    accent: kLilac,
                    onPressed: () => notifier.signUp(
                      context,
                      name: _nameController.text,
                      email: _emailController.text,
                      password: _passwordController.text,
                      confirmPassword: _confirmPasswordController.text,
                    ),
                    child: isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : Text(
                          'Create Account',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Sign-in link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.dmSans(
                            color: kMuted,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(Routes.LOGIN),
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.dmSans(
                              color: kLilac,
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

  Widget _fieldLabel(String text) => Text(
    text,
    style: GoogleFonts.dmSans(
      color: Colors.white.withOpacity(0.8),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _glassField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? type,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: type,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: glassFieldDecoration(
            hint: hint,
            icon: icon,
            accent: kLilac,
          ),
        ),
      ),
    );
  }
}
