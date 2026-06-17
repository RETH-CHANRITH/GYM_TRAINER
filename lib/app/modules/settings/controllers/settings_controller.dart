import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../routes/app_router.dart' show routerProvider, Routes;
import '../../../services/user_profile_service.dart';
import '../../../services/user_support_service.dart';
import '../../../providers/global_providers.dart' show userRoleServiceProvider;

class SettingsState {
  final bool notificationsEnabled;
  final bool emailUpdatesEnabled;
  final bool biometricsEnabled;
  final bool isSavingProfile;
  final bool isSavingEmail;
  final bool isSavingPassword;
  final bool isSubmittingSupport;
  final bool isSubmittingDeletion;

  SettingsState({
    this.notificationsEnabled = true,
    this.emailUpdatesEnabled = false,
    this.biometricsEnabled = false,
    this.isSavingProfile = false,
    this.isSavingEmail = false,
    this.isSavingPassword = false,
    this.isSubmittingSupport = false,
    this.isSubmittingDeletion = false,
  });

  SettingsState copyWith({
    bool? notificationsEnabled,
    bool? emailUpdatesEnabled,
    bool? biometricsEnabled,
    bool? isSavingProfile,
    bool? isSavingEmail,
    bool? isSavingPassword,
    bool? isSubmittingSupport,
    bool? isSubmittingDeletion,
  }) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailUpdatesEnabled: emailUpdatesEnabled ?? this.emailUpdatesEnabled,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      isSavingProfile: isSavingProfile ?? this.isSavingProfile,
      isSavingEmail: isSavingEmail ?? this.isSavingEmail,
      isSavingPassword: isSavingPassword ?? this.isSavingPassword,
      isSubmittingSupport: isSubmittingSupport ?? this.isSubmittingSupport,
      isSubmittingDeletion: isSubmittingDeletion ?? this.isSubmittingDeletion,
    );
  }
}

class SettingsNotifier extends AutoDisposeNotifier<SettingsState> {
  @override
  SettingsState build() {
    _loadPreferences();
    return SettingsState();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      notificationsEnabled: prefs.getBool('settings.notifications') ?? true,
      emailUpdatesEnabled: prefs.getBool('settings.email_updates') ?? false,
      biometricsEnabled: prefs.getBool('settings.biometrics') ?? false,
    );
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> toggleNotifications(BuildContext context, bool val) async {
    state = state.copyWith(notificationsEnabled: val);
    await _savePreference('settings.notifications', val);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Push notifications ${val ? 'enabled' : 'disabled'}.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> toggleEmailUpdates(BuildContext context, bool val) async {
    state = state.copyWith(emailUpdatesEnabled: val);
    await _savePreference('settings.email_updates', val);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email updates ${val ? 'enabled' : 'disabled'}.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> toggleBiometrics(BuildContext context, bool val) async {
    state = state.copyWith(biometricsEnabled: val);
    await _savePreference('settings.biometrics', val);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric login ${val ? 'enabled' : 'disabled'}.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void openAppVersion(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gym Trainer v1.0.0'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<bool> saveAccountIdentity(
    BuildContext context, {
    required String fullName,
    required String email,
    required String currentPassword,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in and try again.')),
      );
      return false;
    }

    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();

    if (trimmedName.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmedEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid name and email.')),
      );
      return false;
    }

    state = state.copyWith(isSavingProfile: true, isSavingEmail: true);
    try {
      final currentName = current.displayName?.trim() ?? '';
      final currentEmail = current.email?.trim() ?? '';

      if (trimmedName != currentName) {
        await current.updateDisplayName(trimmedName);
        ref.read(userProfileServiceProvider.notifier).updateProfile(
          fullName: trimmedName,
          selectedGender: ref.read(userProfileServiceProvider).gender,
          selectedAge: ref.read(userProfileServiceProvider).age,
          selectedWeight: ref.read(userProfileServiceProvider).weight,
          selectedHeight: ref.read(userProfileServiceProvider).height,
          selectedGoal: ref.read(userProfileServiceProvider).fitnessGoal,
          selectedActivity: ref.read(userProfileServiceProvider).activityLevel,
          selectedFitness: ref.read(userProfileServiceProvider).fitnessLevel,
        );
      }

      if (trimmedEmail != currentEmail) {
        final providers = current.providerData.map((p) => p.providerId).toSet();
        final hasPasswordProvider = providers.contains('password');
        if (!hasPasswordProvider) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gmail for Google Sign-In accounts must be changed in your Google account settings.')),
            );
          }
          return false;
        }

        if (currentPassword.trim().isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter your current password to change Gmail instantly.')),
            );
          }
          return false;
        }

        final credential = EmailAuthProvider.credential(
          email: currentEmail,
          password: currentPassword,
        );
        await current.reauthenticateWithCredential(credential);
        await current.updateEmail(trimmedEmail);

        ref.read(userProfileServiceProvider.notifier).updateProfile(
          fullName: ref.read(userProfileServiceProvider).name,
          selectedGender: ref.read(userProfileServiceProvider).gender,
          selectedAge: ref.read(userProfileServiceProvider).age,
          selectedWeight: ref.read(userProfileServiceProvider).weight,
          selectedHeight: ref.read(userProfileServiceProvider).height,
          selectedGoal: ref.read(userProfileServiceProvider).fitnessGoal,
          selectedActivity: ref.read(userProfileServiceProvider).activityLevel,
          selectedFitness: ref.read(userProfileServiceProvider).fitnessLevel,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gmail changed successfully.')));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully.')));
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Failed to update profile.';
      if (e.code == 'requires-recent-login') {
        message = 'Please login again before changing your email.';
      } else if (e.code == 'email-already-in-use') {
        message = 'That email is already in use.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    } finally {
      state = state.copyWith(isSavingProfile: false, isSavingEmail: false);
    }
  }

  Future<void> changeProfileImage(BuildContext context) async {
    await ref.read(userProfileServiceProvider.notifier).pickAndUploadProfilePhoto(
      onNotification: (title, message) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<bool> updatePasswordRealtime(
    BuildContext context, {
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim() ?? '';

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login and try again.')),
      );
      return false;
    }

    final providers = user.providerData.map((p) => p.providerId).toSet();
    final hasPasswordProvider = providers.contains('password');
    final isGoogleOnly = providers.contains('google.com') && !hasPasswordProvider;

    if (isGoogleOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This account uses Google Sign-In. Change your password from Google settings.')),
      );
      return false;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email is linked to this account.')),
      );
      return false;
    }

    if (currentPassword.trim().isEmpty || newPassword.trim().isEmpty || confirmPassword.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return false;
    }

    if (newPassword.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters.')),
      );
      return false;
    }

    if (newPassword.trim() != confirmPassword.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirm password do not match.')),
      );
      return false;
    }

    state = state.copyWith(isSavingPassword: true);
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully.')));
      }
      return true;
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Could not change password.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Current password is incorrect.';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please login again and then change password.';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    } finally {
      state = state.copyWith(isSavingPassword: false);
    }
  }

  Future<void> openPrivacyPolicy(BuildContext context) async {
    await _launchUrl(context, 'https://www.termsfeed.com/live/17f6a095-6f8b-45b6-bdcf-9f9f6146cfa2');
  }

  Future<void> openTermsOfService(BuildContext context) async {
    await _launchUrl(context, 'https://www.termsfeed.com/live/e188f17e-179f-478f-ae79-331dd882f84f');
  }

  Future<void> _launchUrl(BuildContext context, String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    ref.read(routerProvider).go(Routes.LOGIN);
  }

  Future<bool> submitSupportTicket(BuildContext context, {required String subject, required String message}) async {
    state = state.copyWith(isSubmittingSupport: true);
    try {
      final supportService = ref.read(userSupportServiceProvider);
      final ok = await supportService.createSupportTicket(
        subject: subject,
        message: message,
        category: 'in_app_support',
        onNotification: (title, msg) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Our support team will respond as soon as possible.')),
        );
      }
      return ok;
    } finally {
      state = state.copyWith(isSubmittingSupport: false);
    }
  }

  Future<bool> deleteAccount(BuildContext context, {required String reason}) async {
    state = state.copyWith(isSubmittingDeletion: true);
    try {
      final supportService = ref.read(userSupportServiceProvider);
      final ok = await supportService.requestAccountDeletion(
        reason: reason,
        onNotification: (title, msg) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );
      if (!ok) return false;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account deletion request has been recorded.')),
        );
      }

      await FirebaseAuth.instance.signOut();
      ref.read(routerProvider).go(Routes.LOGIN);
      return true;
    } finally {
      state = state.copyWith(isSubmittingDeletion: false);
    }
  }
}

final settingsNotifierProvider = AutoDisposeNotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
