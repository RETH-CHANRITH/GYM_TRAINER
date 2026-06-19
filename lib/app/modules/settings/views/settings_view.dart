import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/settings_controller.dart';
import '../../../routes/app_router.dart' show Routes;
import '../../../providers/theme_provider.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/global_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
const Color neon = Color(0xFFCBFF47);
const Color coral = Color(0xFFFF5C5C);
const Color sky = Color(0xFF5CE8FF);
const Color lilac = Color(0xFFA78BFA);
const Color muted = Color(0xFF6B6B7E);

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  Color _ink(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color _card(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color _raised(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color _text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
  Color _muted(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8484A0) : Colors.black45;
  Color _divider(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);
  Color _neon(BuildContext context) => Theme.of(context).colorScheme.primary;

  Future<void> _showEditProfileSheet(BuildContext context, WidgetRef ref) async {
    final p = ref.read(userProfileServiceProvider);
    final nameCtrl = TextEditingController(text: p.name);
    final emailCtrl = TextEditingController(text: p.email);
    final currentPasswordCtrl = TextEditingController();
    final hideCurrentPassword = ValueNotifier<bool>(true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Consumer(
                builder: (context, ref, _) {
                  final profileState = ref.watch(userProfileServiceProvider);
                  final settingsState = ref.watch(settingsNotifierProvider);

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _text(context).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Change Gmail',
                          style: TextStyle(
                            color: _text(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [_neon(context), sky],
                                      ),
                                      borderRadius: BorderRadius.circular(44),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(41),
                                      child: PremiumAvatar(
                                        name: profileState.name,
                                        customPhotoUrl: profileState.photoUrl,
                                        size: 82,
                                        borderRadius: 41,
                                        isTrainer: false,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: profileState.isUploadingPhoto
                                          ? null
                                          : () => ref
                                              .read(settingsNotifierProvider.notifier)
                                              .changeProfileImage(context),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: _neon(context),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: _card(context),
                                            width: 2,
                                          ),
                                        ),
                                        child: profileState.isUploadingPhoto
                                            ? Padding(
                                                padding: const EdgeInsets.all(7),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: _ink(context),
                                                ),
                                              )
                                            : Icon(
                                                CupertinoIcons.camera_fill,
                                                size: 15,
                                                color: _ink(context),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Change photo',
                                style: TextStyle(
                                  color: _neon(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sheetField(context, nameCtrl, 'Full Name', TextInputType.name),
                        const SizedBox(height: 10),
                        _sheetField(
                          context,
                          emailCtrl,
                          'Gmail Address',
                          TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        ValueListenableBuilder<bool>(
                          valueListenable: hideCurrentPassword,
                          builder: (_, hidden, __) {
                            return _sheetField(
                              context,
                              currentPasswordCtrl,
                              'Current Password (required for Gmail change)',
                              TextInputType.visiblePassword,
                              obscureText: hidden,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  hideCurrentPassword.value = !hidden;
                                },
                                icon: Icon(
                                  hidden
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  color: _muted(context),
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'For instant Gmail update, enter your current password.',
                          style: TextStyle(color: _muted(context), fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: settingsState.isSavingProfile
                                ? null
                                : () async {
                                    final ok = await ref
                                        .read(settingsNotifierProvider.notifier)
                                        .saveAccountIdentity(
                                          context,
                                          fullName: nameCtrl.text,
                                          email: emailCtrl.text,
                                          currentPassword:
                                              currentPasswordCtrl.text,
                                        );
                                    if (ok && context.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _neon(context),
                              foregroundColor: _ink(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: settingsState.isSavingProfile
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _ink(context),
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }

  Widget _sheetField(
    BuildContext context,
    TextEditingController controller,
    String hint,
    TextInputType type, {
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscureText,
      style: TextStyle(color: _text(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _muted(context)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _raised(context),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordSheet(BuildContext context, WidgetRef ref) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final hideCurrent = ValueNotifier<bool>(true);
    final hideNew = ValueNotifier<bool>(true);
    final hideConfirm = ValueNotifier<bool>(true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Consumer(
                builder: (context, ref, _) {
                  final settingsState = ref.watch(settingsNotifierProvider);

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _text(context).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Change Password',
                          style: TextStyle(
                            color: _text(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ValueListenableBuilder<bool>(
                          valueListenable: hideCurrent,
                          builder: (_, hidden, __) {
                            return _sheetField(
                              context,
                              currentCtrl,
                              'Current Password',
                              TextInputType.visiblePassword,
                              obscureText: hidden,
                              suffixIcon: IconButton(
                                onPressed: () => hideCurrent.value = !hidden,
                                icon: Icon(
                                  hidden
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  color: _muted(context),
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        ValueListenableBuilder<bool>(
                          valueListenable: hideNew,
                          builder: (_, hidden, __) {
                            return _sheetField(
                              context,
                              newCtrl,
                              'New Password',
                              TextInputType.visiblePassword,
                              obscureText: hidden,
                              suffixIcon: IconButton(
                                onPressed: () => hideNew.value = !hidden,
                                icon: Icon(
                                  hidden
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  color: _muted(context),
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        ValueListenableBuilder<bool>(
                          valueListenable: hideConfirm,
                          builder: (_, hidden, __) {
                            return _sheetField(
                              context,
                              confirmCtrl,
                              'Confirm New Password',
                              TextInputType.visiblePassword,
                              obscureText: hidden,
                              suffixIcon: IconButton(
                                onPressed: () => hideConfirm.value = !hidden,
                                icon: Icon(
                                  hidden
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  color: _muted(context),
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: settingsState.isSavingPassword
                                ? null
                                : () async {
                                    final ok = await ref
                                        .read(settingsNotifierProvider.notifier)
                                        .updatePasswordRealtime(
                                          context,
                                          currentPassword: currentCtrl.text,
                                          newPassword: newCtrl.text,
                                          confirmPassword: confirmCtrl.text,
                                        );
                                    if (ok && context.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _neon(context),
                              foregroundColor: _ink(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: settingsState.isSavingPassword
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _ink(context),
                                    ),
                                  )
                                : const Text(
                                    'Update Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: _card(context),
            title: Text('Log Out', style: TextStyle(color: _text(context))),
            content: Text(
              'Are you sure you want to log out?',
              style: TextStyle(color: _muted(context)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: _muted(context)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: Color(0xFFFF4F4F)),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(settingsNotifierProvider.notifier).logout();
    }
  }

  Future<void> _showSupportDialog(BuildContext context, WidgetRef ref) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: _card(context),
            title: Text(
              'Contact Support',
              style: TextStyle(color: _text(context)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectCtrl,
                  style: TextStyle(color: _text(context)),
                  decoration: InputDecoration(
                    hintText: 'Subject',
                    hintStyle: TextStyle(color: _muted(context)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  style: TextStyle(color: _text(context)),
                  decoration: InputDecoration(
                    hintText: 'Describe your issue',
                    hintStyle: TextStyle(color: _muted(context)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: _muted(context)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Submit',
                  style: TextStyle(color: _neon(context)),
                ),
              ),
            ],
          ),
    );

    if (submitted == true) {
      await ref.read(settingsNotifierProvider.notifier).submitSupportTicket(
            context,
            subject: subjectCtrl.text,
            message: messageCtrl.text,
          );
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: _card(context),
            title: Text(
              'Delete Account',
              style: TextStyle(color: _text(context)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your request will be reviewed by support before permanent deletion.',
                  style: TextStyle(color: _muted(context)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: TextStyle(color: _text(context)),
                  decoration: InputDecoration(
                    hintText: 'Reason for deletion',
                    hintStyle: TextStyle(color: _muted(context)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: _muted(context)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(color: Color(0xFFFF4F4F)),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(settingsNotifierProvider.notifier).deleteAccount(
            context,
            reason: reasonCtrl.text,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: _ink(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: _text(context)),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(color: _text(context), fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 20,
              20,
              20,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Profile section ────────────
              _buildUserCard(context, ref),
              const SizedBox(height: 28),

              // ── Trainer Registration ──────
              _buildTrainerRegistrationSection(context, ref),

              // ── Preferences ───────────────
              _buildSectionHeader(context, 'Preferences'),
              const SizedBox(height: 10),
              _buildCard(
                context,
                children: [
                  _buildToggle(
                    context,
                    ref,
                    icon: CupertinoIcons.moon_fill,
                    iconColor: lilac,
                    label: 'Dark Mode',
                    subtitle: 'Switch between light and dark themes',
                    value: ref.watch(themeProvider) == ThemeMode.dark,
                    onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                  _buildDivider(context),
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.paintbrush_fill,
                    iconColor: ref.watch(appearanceProvider).accentColor.color(context),
                    label: 'Appearance & Display',
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${ref.watch(appearanceProvider).accentColor.name} • ${ref.watch(appearanceProvider).fontSize.name}',
                        style: TextStyle(
                          color: ref.watch(appearanceProvider).accentColor.color(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: () => context.push(Routes.APPEARANCE),
                  ),
                  _buildDivider(context),
                  _buildToggle(
                    context,
                    ref,
                    icon: CupertinoIcons.bell_fill,
                    iconColor: sky,
                    label: 'Push Notifications',
                    subtitle: 'Session reminders & updates',
                    value: state.notificationsEnabled,
                    onChanged: (val) => notifier.toggleNotifications(context, val),
                  ),
                  _buildDivider(context),
                  _buildToggle(
                    context,
                    ref,
                    icon: CupertinoIcons.envelope_fill,
                    iconColor: lilac,
                    label: 'Email Updates',
                    subtitle: 'Weekly summaries & offers',
                    value: state.emailUpdatesEnabled,
                    onChanged: (val) => notifier.toggleEmailUpdates(context, val),
                  ),
                  _buildDivider(context),
                  _buildToggle(
                    context,
                    ref,
                    icon: CupertinoIcons.hand_thumbsup_fill,
                    iconColor: _neon(context),
                    label: 'Biometric Login',
                    subtitle: 'Use Face ID or fingerprint',
                    value: state.biometricsEnabled,
                    onChanged: (val) => notifier.toggleBiometrics(context, val),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Account ───────────────────
              _buildSectionHeader(context, 'Account'),
              const SizedBox(height: 10),
              _buildCard(
                context,
                children: [
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.pencil,
                    iconColor: sky,
                    label: 'Change Gmail',
                    onTap: () => _showEditProfileSheet(context, ref),
                  ),
                  _buildDivider(context),
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.lock_fill,
                    iconColor: lilac,
                    label: 'Change Password',
                    onTap: () => _showChangePasswordSheet(context, ref),
                  ),
                  _buildDivider(context),
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.creditcard_fill,
                    iconColor: _neon(context),
                    label: 'Payment Methods',
                    onTap: () => context.push(Routes.WALLET),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── About ─────────────────────
              _buildSectionHeader(context, 'About'),
              const SizedBox(height: 10),
              _buildCard(
                context,
                children: [
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.info_circle_fill,
                    iconColor: sky,
                    label: 'App Version',
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(color: _muted(context), fontSize: 13),
                    ),
                    onTap: () => notifier.openAppVersion(context),
                  ),
                  _buildDivider(context),
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.doc_text_fill,
                    iconColor: lilac,
                    label: 'Privacy Policy',
                    onTap: () => notifier.openPrivacyPolicy(context),
                  ),
                  _buildDivider(context),
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.doc_plaintext,
                    iconColor: muted,
                    label: 'Terms of Service',
                    onTap: () => notifier.openTermsOfService(context),
                  ),
                  _buildDivider(context),
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.question_circle_fill,
                    iconColor: sky,
                    label: 'Help & Support',
                    onTap: () => _showSupportDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Danger Zone ───────────────
              _buildCard(
                context,
                children: [
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.square_arrow_right,
                    iconColor: coral,
                    label: 'Log Out',
                    labelColor: coral,
                    showChevron: false,
                    onTap: () => _showLogoutDialog(context, ref),
                  ),
                  _buildDivider(context),
                  _buildArrowRow(
                    context,
                    icon: CupertinoIcons.trash_fill,
                    iconColor: coral,
                    label: 'Delete Account',
                    labelColor: coral,
                    showChevron: false,
                    onTap: () => _showDeleteAccountDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildUserCard(BuildContext context, WidgetRef ref) {
    final p = ref.watch(userProfileServiceProvider);

    return GestureDetector(
      onTap: () => _showEditProfileSheet(context, ref),
      child: LiquidTile(
        radius: 16,
        padding: const EdgeInsets.all(16),
        accent: kLilac,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_neon(context), sky],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PremiumAvatar(
                    name: p.name,
                    customPhotoUrl: p.photoUrl,
                    size: 52,
                    borderRadius: 14,
                    isTrainer: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      color: _text(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.email.isNotEmpty ? p.email : 'No email linked',
                    style: TextStyle(color: _muted(context), fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.pencil, color: _muted(context), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        color: _muted(context),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return LiquidTile(
      radius: 16,
      padding: EdgeInsets.zero,
      accent: kSky,
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 56),
        color: _divider(context),
      );

  Widget _buildToggle(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _text(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(subtitle, style: TextStyle(color: _muted(context), fontSize: 11)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: _neon(context),
            trackColor: _raised(context),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    bool showChevron = true,
    Widget? trailing,
  }) {
    final effectiveLabelColor = labelColor ?? _text(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: effectiveLabelColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (trailing != null) trailing,
            if (showChevron) Icon(CupertinoIcons.chevron_right, color: _muted(context), size: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    DateTime? dt;
    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    }
    if (dt == null) return 'N/A';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Direct-submit trainer application (no form) ──────────────────────────────
  Future<void> _submitTrainerApplication(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final profile = ref.read(userProfileServiceProvider);

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A28)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Register as Trainer?',
          style: TextStyle(
            color: _text(context),
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Your current profile information will be sent to the admin for review. You will be notified once approved.',
          style: TextStyle(color: _muted(context), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _muted(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _neon(context),
              foregroundColor: const Color(0xFF0A0A0F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('trainerApplications')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'fullName': profile.name,
        'email': profile.email,
        'photoUrl': profile.photoUrl,
        'specialty': '',
        'yearsOfExperience': '0',
        'hourlyRate': 0.0,
        'certifications': '',
        'bio': '',
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Application submitted! Waiting for admin review.'),
            backgroundColor: _neon(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: coral,
          ),
        );
      }
    }
  }

  Widget _buildTrainerRegistrationSection(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileServiceProvider);
    final role = profile.role.toLowerCase().trim();
    // Show for 'user' role, empty role, or any non-trainer/non-admin role
    if (role == 'admin') return const SizedBox.shrink();

    if (role == 'trainer') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Become a Trainer'),
          const SizedBox(height: 10),
          LiquidTile(
            radius: 16,
            padding: const EdgeInsets.all(16),
            accent: const Color(0xFFCBFF47),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBFF47).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: Color(0xFFCBFF47),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Application Approved! 🎉',
                            style: TextStyle(
                              color: _text(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You are now a certified trainer.',
                            style: TextStyle(
                              color: _muted(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Please sign out and sign back in to activate your trainer account and start setting up your profile.',
                  style: TextStyle(
                    color: _text(context).withOpacity(0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showLogoutDialog(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCBFF47),
                      foregroundColor: const Color(0xFF0A0A0F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign Out Now',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    final appAsync = ref.watch(userTrainerApplicationProvider);

    return appAsync.when(
      data: (app) {
        if (app == null) {
          // ── No application yet: show Register button ──
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Become a Trainer'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _submitTrainerApplication(context, ref),
                behavior: HitTestBehavior.opaque,
                child: LiquidTile(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  accent: Theme.of(context).colorScheme.primary,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fitness_center_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register as Trainer',
                              style: TextStyle(
                                color: _text(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to apply — no extra info needed',
                              style: TextStyle(
                                color: _muted(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        color: _muted(context),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }

        final status = (app['status'] ?? 'pending').toString().toLowerCase();

        if (status == 'pending') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Trainer Application'),
              const SizedBox(height: 10),
              LiquidTile(
                radius: 16,
                padding: const EdgeInsets.all(16),
                accent: Colors.orange,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_empty_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Application Pending Review',
                            style: TextStyle(
                              color: _text(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Submitted on ${_formatDate(app['submittedAt'])}',
                            style: TextStyle(
                              color: _muted(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }

        if (status == 'rejected') {
          final notes = app['rejectionNotes'] ?? 'No feedback provided';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Trainer Application'),
              const SizedBox(height: 10),
              LiquidTile(
                radius: 16,
                padding: const EdgeInsets.all(16),
                accent: Colors.red,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Application Rejected',
                                style: TextStyle(
                                  color: _text(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Feedback: $notes',
                                style: TextStyle(
                                  color: _muted(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _submitTrainerApplication(context, ref),
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Re-apply',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }

        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
