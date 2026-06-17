import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routes/app_router.dart' show routerProvider, Routes;
import '../../../../infrastructure/api/api_client.dart';

class ForgotPasswordState {
  final int currentStep;
  final String? contactMethod;
  final bool isLoading;
  final bool isOtpSent;
  final bool showPassword;
  final bool showConfirmPassword;
  final int otpResendCountdown;
  final String? resetToken;

  ForgotPasswordState({
    this.currentStep = 0,
    this.contactMethod,
    this.isLoading = false,
    this.isOtpSent = false,
    this.showPassword = false,
    this.showConfirmPassword = false,
    this.otpResendCountdown = 0,
    this.resetToken,
  });

  ForgotPasswordState copyWith({
    int? currentStep,
    String? contactMethod,
    bool? isLoading,
    bool? isOtpSent,
    bool? showPassword,
    bool? showConfirmPassword,
    int? otpResendCountdown,
    String? resetToken,
  }) {
    return ForgotPasswordState(
      currentStep: currentStep ?? this.currentStep,
      contactMethod: contactMethod ?? this.contactMethod,
      isLoading: isLoading ?? this.isLoading,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      showPassword: showPassword ?? this.showPassword,
      showConfirmPassword: showConfirmPassword ?? this.showConfirmPassword,
      otpResendCountdown: otpResendCountdown ?? this.otpResendCountdown,
      resetToken: resetToken ?? this.resetToken,
    );
  }
}

class ForgotPasswordNotifier extends AutoDisposeNotifier<ForgotPasswordState> {
  final _auth = FirebaseAuth.instance;
  String? _verificationId;
  Timer? _countdownTimer;

  @override
  ForgotPasswordState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
    });
    return ForgotPasswordState();
  }

  void selectContactMethod(String method) {
    state = state.copyWith(contactMethod: method, currentStep: 1);
  }

  void toggleShowPassword() {
    state = state.copyWith(showPassword: !state.showPassword);
  }

  void toggleShowConfirmPassword() {
    state = state.copyWith(showConfirmPassword: !state.showConfirmPassword);
  }

  Future<void> sendOtp(BuildContext context, {required String email, required String phone}) async {
    if (state.contactMethod == 'email') {
      await _sendEmailOtp(context, email);
    } else {
      await _sendPhoneOtp(context, phone);
    }
  }

  Future<void> _sendEmailOtp(BuildContext context, String email) async {
    if (email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post<Map<String, dynamic>>(
        '/auth/password-reset',
        data: {'email': email.trim()},
      );

      final success = response['success'] as bool? ?? false;
      if (success) {
        state = state.copyWith(isOtpSent: true, currentStep: 2);
        _startCountdown();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'OTP code sent successfully')),
          );
        }
      } else {
        final errorMsg = response['error']?['message'] ?? 'Failed to send OTP code';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().contains('404')
            ? 'No account found with this email address.'
            : 'Failed to send verification code. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _sendPhoneOtp(BuildContext context, String phone) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    String phoneNumber = phone.trim();
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+$phoneNumber';
    }

    state = state.copyWith(isLoading: true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          state = state.copyWith(isOtpSent: true, currentStep: 3);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message ?? 'Phone verification failed')),
            );
          }
          state = state.copyWith(isLoading: false);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          state = state.copyWith(isOtpSent: true, currentStep: 2);
          _startCountdown();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('OTP sent to $phoneNumber')),
            );
          }
          state = state.copyWith(isLoading: false);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(minutes: 2),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send OTP')),
        );
      }
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> verifyOtp(BuildContext context, String email, String otp) async {
    if (otp.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }

    if (state.contactMethod == 'email') {
      state = state.copyWith(isLoading: true);
      try {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.post<Map<String, dynamic>>(
          '/auth/verify-otp',
          data: {
            'email': email.trim(),
            'otp': otp.trim(),
          },
        );

        final success = response['success'] as bool? ?? false;
        if (success) {
          final token = response['data']?['resetToken'] as String?;
          state = state.copyWith(
            resetToken: token,
            currentStep: 3,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification code verified successfully')),
            );
          }
        } else {
          final errorMsg = response['error']?['message'] ?? 'Invalid verification code';
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg)),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('ApiException:', '').trim())),
          );
        }
      } finally {
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification ID not found')),
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp.trim(),
      );
      await _auth.signInWithCredential(credential);
      state = state.copyWith(currentStep: 3);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verified successfully')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Invalid OTP')),
        );
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resetPassword(
    BuildContext context,
    String email,
    String newPassword,
    String confirmPassword,
  ) async {
    if (newPassword.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter new password')),
      );
      return;
    }
    if (newPassword.trim() != confirmPassword.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (newPassword.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (state.contactMethod == 'email') {
      if (state.resetToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid password reset session. Please request a new code.')),
        );
        return;
      }

      state = state.copyWith(isLoading: true);
      try {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.post<Map<String, dynamic>>(
          '/auth/update-password',
          data: {
            'email': email.trim(),
            'resetToken': state.resetToken,
            'newPassword': newPassword.trim(),
          },
        );

        final success = response['success'] as bool? ?? false;
        if (success) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password reset successfully. Please login with your new password.')),
            );
          }
          await Future.delayed(const Duration(seconds: 1));
          ref.read(routerProvider).go(Routes.LOGIN);
        } else {
          final errorMsg = response['error']?['message'] ?? 'Failed to reset password';
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg)),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('ApiException:', '').trim())),
          );
        }
      } finally {
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword.trim());
        await _auth.signOut();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset successfully. Please login with your new password.')),
          );
        }
        await Future.delayed(const Duration(seconds: 1));
        ref.read(routerProvider).go(Routes.LOGIN);
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to reset password')),
        );
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    state = state.copyWith(otpResendCountdown: 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.otpResendCountdown > 0) {
        state = state.copyWith(otpResendCountdown: state.otpResendCountdown - 1);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  Future<void> resendOtp(BuildContext context, {required String email, required String phone}) async {
    if (state.otpResendCountdown > 0) return;
    await sendOtp(context, email: email, phone: phone);
  }

  void goBack(BuildContext context) {
    if (state.currentStep > 0) {
      _countdownTimer?.cancel();
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        isOtpSent: false,
        otpResendCountdown: 0,
      );
    } else {
      context.pop();
    }
  }
}

final forgotPasswordNotifierProvider = AutoDisposeNotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>(() {
  return ForgotPasswordNotifier();
});
