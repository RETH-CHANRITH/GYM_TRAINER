import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/forgot_password_controller.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  // Dynamic accent colour — follows the user's chosen theme.
  Color get _accent => Theme.of(context).colorScheme.primary;

  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _otpController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordNotifierProvider);
    final notifier = ref.read(forgotPasswordNotifierProvider.notifier);
    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: state.currentStep == 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: kSky),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: kSky),
                onPressed: () => notifier.goBack(context),
              ),
        title: Text(
          'Reset Password',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.05, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _buildStepContent(state, notifier),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(ForgotPasswordState state, ForgotPasswordNotifier notifier) {
    switch (state.currentStep) {
      case 0:
        return _buildChooseMethodStep(notifier);
      case 1:
        return _buildEnterContactStep(state, notifier);
      case 2:
        return _buildVerifyOtpStep(state, notifier);
      case 3:
        return _buildResetPasswordStep(state, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 0: Choose contact method ─────────────────────────────────────────
  Widget _buildChooseMethodStep(ForgotPasswordNotifier notifier) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'How would you like to reset your password?',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose your preferred recovery method',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: kMuted,
          ),
        ),
        const SizedBox(height: 48),
        // Email option
        _buildMethodCard(
          icon: Icons.email_rounded,
          title: 'Email',
          subtitle: 'Receive a password reset link via email',
          color: kSky,
          onTap: () => notifier.selectContactMethod('email'),
        ),
        const SizedBox(height: 20),
        // Phone option
        _buildMethodCard(
          icon: Icons.phone_rounded,
          title: 'Phone',
          subtitle: 'Get an OTP code via SMS',
          color: _accent,
          onTap: () => notifier.selectContactMethod('phone'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: kSky),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Enter contact method (email or phone) ──────────────────────────
  Widget _buildEnterContactStep(ForgotPasswordState state, ForgotPasswordNotifier notifier) {
    final isEmail = state.contactMethod == 'email';

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          isEmail ? 'Enter your email address' : 'Enter your phone number',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isEmail
              ? 'We will send a password reset link'
              : 'We will send an OTP verification code',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: kMuted,
          ),
        ),
        const SizedBox(height: 48),
        _buildGlassTextField(
          controller: isEmail ? _emailController : _phoneController,
          hintText: isEmail ? 'your@email.com' : '+1234567890',
          icon: isEmail ? Icons.email_rounded : Icons.phone_rounded,
          keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.phone,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () => notifier.sendOtp(
                      context,
                      email: _emailController.text,
                      phone: _phoneController.text,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: _accent.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kInk),
                    ),
                  )
                : Text(
                    'Send Code',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── Step 2: Verify OTP ─────────────────────────────────────────────────────
  Widget _buildVerifyOtpStep(ForgotPasswordState state, ForgotPasswordNotifier notifier) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Enter verification code',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Check your email or phone for the code',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: kMuted,
          ),
        ),
        const SizedBox(height: 48),
        _buildGlassTextField(
          controller: _otpController,
          hintText: 'Enter 6-digit code',
          icon: Icons.pin_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            state.otpResendCountdown > 0
                ? 'Resend code in ${state.otpResendCountdown}s'
                : 'Didn\'t receive code?',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: state.otpResendCountdown > 0 ? kMuted : kSky,
            ),
          ),
        ),
        if (state.otpResendCountdown == 0)
          Align(
            child: TextButton(
              onPressed: () => notifier.resendOtp(
                context,
                email: _emailController.text,
                phone: _phoneController.text,
              ),
              child: Text(
                'Resend Code',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _accent,
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isLoading ? null : () => notifier.verifyOtp(context, _emailController.text, _otpController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: _accent.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kInk),
                    ),
                  )
                : Text(
                    'Verify Code',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── Step 3: Reset Password ────────────────────────────────────────────────
  Widget _buildResetPasswordStep(ForgotPasswordState state, ForgotPasswordNotifier notifier) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Create new password',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Make it strong and unique',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: kMuted,
          ),
        ),
        const SizedBox(height: 40),
        _buildGlassTextField(
          controller: _newPasswordController,
          hintText: 'New Password',
          icon: Icons.lock_rounded,
          isPassword: true,
          showPassword: state.showPassword,
          onShowPasswordChanged: (value) => notifier.toggleShowPassword(),
        ),
        const SizedBox(height: 18),
        _buildGlassTextField(
          controller: _confirmPasswordController,
          hintText: 'Confirm Password',
          icon: Icons.lock_rounded,
          isPassword: true,
          showPassword: state.showConfirmPassword,
          onShowPasswordChanged: (value) => notifier.toggleShowConfirmPassword(),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () => notifier.resetPassword(
                      context,
                      _emailController.text,
                      _newPasswordController.text,
                      _confirmPasswordController.text,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: _accent.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kInk),
                    ),
                  )
                : Text(
                    'Reset Password',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── Reusable glass textfield ──────────────────────────────────────────────
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool showPassword = false,
    Function(bool)? onShowPasswordChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword && !showPassword,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: kMuted,
          ),
          prefixIcon: Icon(icon, color: kSky),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: () => onShowPasswordChanged?.call(!showPassword),
                  child: Icon(
                    showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: kMuted,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
