import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';
import '../../../routes/app_router.dart' show Routes;

final selectedGenderProvider = StateProvider<String?>((ref) => null);

class GenderSelectionView extends ConsumerWidget {
  const GenderSelectionView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGender = ref.watch(selectedGenderProvider);
    // Dynamic accent colour — follows the user's chosen theme.
    final kNeon = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false, // Block hardware back during onboarding first step
      child: Scaffold(
        backgroundColor: kInk,
        extendBodyBehindAppBar: true,
        // No back button on first onboarding step
        appBar: glassAppBar(title: 'Your Gender'),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback:
                        (b) => LinearGradient(
                          colors: [Colors.white, kNeon],
                        ).createShader(b),
                    child: Text(
                      'What is your\ngender?',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 40,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This helps us personalise your fitness experience',
                    style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: Column(
                      children: [
                                        _buildOption(
                          label: 'Male',
                          value: 'male',
                          icon: Icons.male_rounded,
                          selectedGender: selectedGender,
                          ref: ref,
                          accent: kNeon,
                        ),
                        _buildOption(
                          label: 'Female',
                          value: 'female',
                          icon: Icons.female_rounded,
                          selectedGender: selectedGender,
                          ref: ref,
                          accent: kNeon,
                        ),
                        _buildOption(
                          label: 'Other',
                          value: 'other',
                          icon: Icons.transgender_rounded,
                          selectedGender: selectedGender,
                          ref: ref,
                          accent: kNeon,
                        ),
                      ],
                    ),
                  ),
                  neonButton(
                    label: 'Continue',
                    onPressed: () {
                      final selected = ref.read(selectedGenderProvider);
                      if (selected != null) {
                        ref.read(userProfileServiceProvider.notifier).setGender(selected);
                        context.go(Routes.AGE_INPUT);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select your gender')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    ),  // WillPopScope
  );
  }

  Widget _buildOption({
    required String label,
    required String value,
    required IconData icon,
    required String? selectedGender,
    required WidgetRef ref,
    required Color accent,
  }) {
    final isSelected = selectedGender == value;
    final kNeon = accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => ref.read(selectedGenderProvider.notifier).state = value,
        child: LiquidTile(
          selected: isSelected,
          accent: kNeon,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isSelected ? kNeon : Colors.white).withOpacity(
                    0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? kNeon : kMuted,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? kNeon : Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        !isSelected ? Colors.white.withOpacity(0.3) : kNeon,
                    width: 2,
                  ),
                  color: isSelected ? kNeon : Colors.transparent,
                ),
                child:
                    isSelected
                        ? const Icon(
                          Icons.check_rounded,
                          color: kInk,
                          size: 14,
                        )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
