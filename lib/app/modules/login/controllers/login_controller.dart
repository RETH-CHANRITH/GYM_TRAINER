import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../routes/app_router.dart' show routerProvider, Routes;
import '../../../providers/global_providers.dart';
import '../../../services/notification_service.dart';

class LoginState {
  final bool isLoading;
  final bool isGoogleLoading;
  LoginState({this.isLoading = false, this.isGoogleLoading = false});

  LoginState copyWith({bool? isLoading, bool? isGoogleLoading}) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
    );
  }
}

class LoginNotifier extends AutoDisposeNotifier<LoginState> {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  int _wrongPasswordCount = 0;

  @override
  LoginState build() {
    return LoginState();
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    state = state.copyWith(isGoogleLoading: true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in was cancelled.')),
          );
        }
        return;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Missing Google ID token. Check config.'),
              backgroundColor: Color(0xFFFF5C5C),
            ),
          );
        }
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      if (result.user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google authentication returned no user.'),
              backgroundColor: Color(0xFFFF5C5C),
            ),
          );
        }
        return;
      }

      await _redirectByRole(result.user);
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Google sign-in failed.';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message (code: ${e.code})'),
            backgroundColor: const Color(0xFFFF5C5C),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Platform error: ${e.code}: ${e.message}'),
            backgroundColor: const Color(0xFFFF5C5C),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: $e'),
            backgroundColor: const Color(0xFFFF5C5C),
          ),
        );
      }
    } finally {
      state = state.copyWith(isGoogleLoading: false);
    }
  }

  Future<void> login(BuildContext context, String email, String password) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Color(0xFFFF5C5C),
        ),
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );
      _wrongPasswordCount = 0;
      await _redirectByRole(result.user);
    } on FirebaseAuthException catch (e) {
      _wrongPasswordCount++;
      if (_wrongPasswordCount >= 3) {
        _wrongPasswordCount = 0;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Too many failed attempts. Redirecting to sign-up...'),
              backgroundColor: Color(0xFFFF5C5C),
            ),
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        ref.read(routerProvider).go(Routes.SIGN_UP);
        return;
      }

      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }

      final remaining = 3 - _wrongPasswordCount;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message $remaining attempt(s) left.'),
            backgroundColor: const Color(0xFFFF5C5C),
          ),
        );
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _redirectByRole(User? user) async {
    final router = ref.read(routerProvider);
    if (user == null) {
      router.go(Routes.LOGIN);
      return;
    }

    // Save FCM token so this device receives push notifications
    NotificationService.instance.saveFcmToken();

    try {
      final roleService = ref.read(userRoleServiceProvider);

      // Get the live role from Firestore (falls back to cache if offline)
      final role = await roleService.ensureAndGetRole(user);

      // Trainers: check profile completeness, admins skip entirely
      if (role == 'trainer') {
        final trainerComplete = await roleService.isTrainerProfileComplete(user);
        if (trainerComplete) {
          router.go(Routes.TRAINER_DASHBOARD);
        } else {
          router.go(Routes.TRAINER_ONBOARDING);
        }
        return;
      }
      if (role == 'admin') {
        router.go(Routes.ADMIN_DASHBOARD);
        return;
      }

      // Standard user: check if profile setup is complete
      final profileComplete = await roleService.isProfileComplete(user);
      if (!profileComplete) {
        router.go(Routes.WELCOME);
        return;
      }

      router.go(Routes.HOME);
    } catch (_) {
      router.go(Routes.HOME);
    }
  }
}

final loginNotifierProvider = AutoDisposeNotifierProvider<LoginNotifier, LoginState>(() {
  return LoginNotifier();
});
