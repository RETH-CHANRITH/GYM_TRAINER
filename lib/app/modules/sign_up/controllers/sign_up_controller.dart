import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../routes/app_router.dart' show routerProvider, Routes;
import '../../../providers/global_providers.dart';

class SignUpNotifier extends AutoDisposeNotifier<bool> {
  final _auth = FirebaseAuth.instance;

  @override
  bool build() {
    return false;
  }

  Future<void> signUp(
    BuildContext context, {
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    final trimmedConfirmPassword = confirmPassword.trim();

    if (trimmedName.isEmpty ||
        trimmedEmail.isEmpty ||
        trimmedPassword.isEmpty ||
        trimmedConfirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Color(0xFFFF5C5C),
        ),
      );
      return;
    }
    if (trimmedPassword != trimmedConfirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Color(0xFFFF5C5C),
        ),
      );
      return;
    }
    if (trimmedPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Color(0xFFFF5C5C),
        ),
      );
      return;
    }

    state = true;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );
      await credential.user?.updateDisplayName(trimmedName);
      await credential.user?.reload();
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final roleService = ref.read(userRoleServiceProvider);
        // Create the Firestore doc with profileCompleted: false
        await roleService.ensureAndGetRole(currentUser, displayName: trimmedName);
      }
      // Do NOT sign out — send new user directly into profile setup flow.
      ref.read(routerProvider).go(Routes.WELCOME);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFFF5C5C),
          ),
        );
      }
    } finally {
      state = false;
    }
  }
}

final signUpNotifierProvider = AutoDisposeNotifierProvider<SignUpNotifier, bool>(() {
  return SignUpNotifier();
});
