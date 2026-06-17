import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../services/user_profile_service.dart';
import '../../../services/user_role_service.dart';
import '../../../routes/app_router.dart' show Routes;
import '../../../../config/glass_ui.dart';

class ProfileSummaryView extends ConsumerWidget {
  const ProfileSummaryView({Key? key}) : super(key: key);

  Future<void> _openEditSheet(BuildContext context, WidgetRef ref, UserProfileState p) async {
    final kNeon = Theme.of(context).colorScheme.primary;
    final nameCtrl = TextEditingController(text: p.name);
    final ageCtrl = TextEditingController(text: p.age.toString());
    final weightCtrl = TextEditingController(text: p.weight.toString());
    final heightCtrl = TextEditingController(text: p.height.toString());

    final genders = ['Male', 'Female', 'Other'];
    final goals = [
      'Weight Loss',
      'Muscle Gain',
      'Build Endurance',
      'Improve Flexibility',
    ];
    final activities = [
      'Sedentary',
      'Lightly Active',
      'Moderately Active',
      'Very Active',
    ];
    final fitnessLevels = ['Beginner', 'Intermediate', 'Advanced'];

    String selectedGender = genders.contains(p.gender) ? p.gender : genders.first;
    String selectedGoal = goals.contains(p.fitnessGoal) ? p.fitnessGoal : goals.first;
    String selectedActivity = activities.contains(p.activityLevel) ? p.activityLevel : activities.first;
    String selectedFitness = fitnessLevels.contains(p.fitnessLevel) ? p.fitnessLevel : fitnessLevels.first;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter sheetSetState) {
                  final currentProfileState = ref.watch(userProfileServiceProvider);

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
                              color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Edit Profile',
                          style: GoogleFonts.dmSans(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
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
                                        colors: [kNeon, kSky],
                                      ),
                                      borderRadius: BorderRadius.circular(48),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(45),
                                      child: SizedBox(
                                        width: 90,
                                        height: 90,
                                        child: currentProfileState.photoUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: currentProfileState.photoUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => InitialsAvatar(
                                                  name: currentProfileState.name,
                                                  size: 90,
                                                  fontSize: 30,
                                                  borderRadius: 45,
                                                ),
                                                errorWidget: (context, url, error) => InitialsAvatar(
                                                  name: currentProfileState.name,
                                                  size: 90,
                                                  fontSize: 30,
                                                  borderRadius: 45,
                                                ),
                                              )
                                            : InitialsAvatar(
                                                name: currentProfileState.name,
                                                size: 90,
                                                fontSize: 30,
                                                borderRadius: 45,
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [kNeon, kSky],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF),
                                          width: 2,
                                        ),
                                      ),
                                      child: currentProfileState.isUploadingPhoto
                                          ? const Padding(
                                              padding: EdgeInsets.all(7),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: kInk,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt_rounded,
                                              size: 16,
                                              color: kInk,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: currentProfileState.isUploadingPhoto
                                    ? null
                                    : () async {
                                        await ref
                                            .read(userProfileServiceProvider.notifier)
                                            .pickAndUploadProfilePhoto(
                                          onNotification: (title, message) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(message)),
                                            );
                                          },
                                        );
                                      },
                                child: Text(
                                  currentProfileState.isUploadingPhoto
                                      ? 'Uploading...'
                                      : 'Change photo',
                                  style: GoogleFonts.dmSans(
                                    color: isDark ? kNeon : kLilac,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _editField(
                          context,
                          nameCtrl,
                          'Full Name',
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 10),
                        _editField(
                          context,
                          ageCtrl,
                          'Age',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        _editField(
                          context,
                          weightCtrl,
                          'Weight (kg)',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        _editField(
                          context,
                          heightCtrl,
                          'Height (cm)',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          context: context,
                          label: 'Gender',
                          value: selectedGender,
                          items: genders,
                          onChanged: (v) => sheetSetState(() => selectedGender = v),
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          context: context,
                          label: 'Fitness Goal',
                          value: selectedGoal,
                          items: goals,
                          onChanged: (v) => sheetSetState(() => selectedGoal = v),
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          context: context,
                          label: 'Activity Level',
                          value: selectedActivity,
                          items: activities,
                          onChanged: (v) => sheetSetState(() => selectedActivity = v),
                        ),
                        const SizedBox(height: 10),
                        _dropdownField(
                          context: context,
                          label: 'Fitness Level',
                          value: selectedFitness,
                          items: fitnessLevels,
                          onChanged: (v) => sheetSetState(() => selectedFitness = v),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final ageVal = int.tryParse(ageCtrl.text.trim());
                              final weightVal = int.tryParse(weightCtrl.text.trim());
                              final heightVal = int.tryParse(heightCtrl.text.trim());

                              if (nameCtrl.text.trim().isEmpty ||
                                  ageVal == null ||
                                  weightVal == null ||
                                  heightVal == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill all fields correctly.')),
                                );
                                return;
                              }

                              await ref.read(userProfileServiceProvider.notifier).updateProfile(
                                    fullName: nameCtrl.text.trim(),
                                    selectedGender: selectedGender,
                                    selectedAge: ageVal,
                                    selectedWeight: weightVal,
                                    selectedHeight: heightVal,
                                    selectedGoal: selectedGoal,
                                    selectedActivity: selectedActivity,
                                    selectedFitness: selectedFitness,
                                  );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Your profile has been updated.')),
                                );
                                Navigator.pop(sheetContext);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? kNeon : kLilac,
                              foregroundColor: isDark ? kInk : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Save Changes',
                              style: GoogleFonts.dmSans(
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

  Widget _editField(
    BuildContext context,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kNeon = Theme.of(context).colorScheme.primary;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: isDark ? kMuted : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? kNeon : kLilac),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required BuildContext context,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kNeon = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF),
          style: GoogleFonts.dmSans(color: isDark ? Colors.white : Colors.black87),
          iconEnabledColor: isDark ? kNeon : kLilac,
          items: items
              .map(
                (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          hint: Text(label, style: GoogleFonts.dmSans(color: isDark ? kMuted : Colors.black38)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(userProfileServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;
    final neon = Theme.of(context).colorScheme.primary;
    final kNeon = neon;

    return Scaffold(
      backgroundColor: ink,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: 'Profile Summary',
        onBack: () => context.pop(),
        context: context,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 18),
                  Expanded(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [kNeon, kSky],
                                ),
                                borderRadius: BorderRadius.circular(52),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(49),
                                child: SizedBox(
                                  width: 98,
                                  height: 98,
                                  child: p.photoUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: p.photoUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => InitialsAvatar(
                                            name: p.name,
                                            size: 98,
                                            fontSize: 34,
                                            borderRadius: 49,
                                          ),
                                          errorWidget: (context, url, error) => InitialsAvatar(
                                            name: p.name,
                                            size: 98,
                                            fontSize: 34,
                                            borderRadius: 49,
                                          ),
                                        )
                                      : InitialsAvatar(
                                          name: p.name,
                                          size: 98,
                                          fontSize: 34,
                                          borderRadius: 49,
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: p.isUploadingPhoto
                                    ? null
                                    : () async {
                                        await ref
                                            .read(userProfileServiceProvider.notifier)
                                            .pickAndUploadProfilePhoto(
                                          onNotification: (title, message) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(message)),
                                            );
                                          },
                                        );
                                      },
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [kNeon, kSky],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF),
                                      width: 2,
                                    ),
                                  ),
                                  child: p.isUploadingPhoto
                                      ? const Padding(
                                          padding: EdgeInsets.all(7),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: kInk,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 17,
                                          color: kInk,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          p.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.email.isNotEmpty ? p.email : 'No email linked',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: muted,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Review your information before continuing',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: muted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                _profileInfoCard(
                                  context,
                                  icon: Icons.person_rounded,
                                  title: 'Gender',
                                  value: p.gender,
                                  accent: neon,
                                ),
                                const SizedBox(height: 12),
                                _profileInfoCard(
                                  context,
                                  icon: Icons.cake_rounded,
                                  title: 'Age',
                                  value: '${p.age} years',
                                  accent: kCoral,
                                ),
                                const SizedBox(height: 12),
                                _profileInfoCard(
                                  context,
                                  icon: Icons.monitor_weight_rounded,
                                  title: 'Weight',
                                  value: '${p.weight} kg',
                                  accent: kSky,
                                ),
                                const SizedBox(height: 12),
                                _profileInfoCard(
                                  context,
                                  icon: Icons.straighten_rounded,
                                  title: 'Height',
                                  value: '${p.height} cm',
                                  accent: kLilac,
                                ),
                                const SizedBox(height: 12),
                                _profileInfoCard(
                                  context,
                                  icon: Icons.emoji_events_rounded,
                                  title: 'Fitness Goal',
                                  value: p.fitnessGoal,
                                  accent: neon,
                                ),
                                const SizedBox(height: 12),
                                _profileInfoCard(
                                  context,
                                  icon: Icons.bolt_rounded,
                                  title: 'Activity Level',
                                  value: p.activityLevel,
                                  accent: kCoral,
                                ),
                                const SizedBox(height: 12),
                                _profileInfoCard(
                                  context,
                                  icon: Icons.fitness_center_rounded,
                                  title: 'Fitness Level',
                                  value: p.fitnessLevel,
                                  accent: kSky,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openEditSheet(context, ref, p),
                          child: SizedBox(
                            height: 56,
                            child: LiquidTile(
                              radius: 28,
                              padding: EdgeInsets.zero,
                              child: Center(
                                child: Text(
                                  'Edit',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: neon,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: neonButton(
                          label: 'Continue',
                          accent: neon,
                          onPressed: () async {
                            // Save all profile data to Firestore.
                            final profileNotifier = ref.read(userProfileServiceProvider.notifier);
                            final profile = ref.read(userProfileServiceProvider);
                            await profileNotifier.saveFullProfile(
                              fullName: profile.name,
                              selectedGender: profile.gender,
                              selectedAge: profile.age,
                              selectedWeight: profile.weight,
                              selectedHeight: profile.height,
                              selectedGoal: profile.fitnessGoal,
                              selectedActivity: profile.activityLevel,
                              selectedFitness: profile.fitnessLevel,
                            );
                            // Mark profile setup as complete.
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                               final roleService = UserRoleService();
                              await roleService.markProfileComplete(user);
                            }
                            if (context.mounted) {
                              context.go(Routes.HOME);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black54;

    return LiquidTile(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
