import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';
import '../../../routes/app_router.dart' show Routes;

final selectedActivityLevelProvider = StateProvider<String?>((ref) => null);

final _activityLevelsList = const [
  {
    'id': 'sedentary',
    'label': 'Sedentary',
    'description': 'Little or no exercise',
  },
  {
    'id': 'lightly_active',
    'label': 'Lightly Active',
    'description': '1-3 days per week',
  },
  {
    'id': 'moderately_active',
    'label': 'Moderately Active',
    'description': '3-5 days per week',
  },
  {
    'id': 'very_active',
    'label': 'Very Active',
    'description': '6-7 days per week',
  },
];

class ActivityLevelView extends ConsumerWidget {
  const ActivityLevelView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLevel = ref.watch(selectedActivityLevelProvider);
    // Dynamic accent colour — follows the user's chosen theme.
    final kNeon = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: 'Activity Level',
        onBack: () => context.go(Routes.FITNESS_GOAL),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  ShaderMask(
                    shaderCallback:
                        (b) => LinearGradient(
                          colors: [kCoral, kNeon],
                        ).createShader(b),
                    child: Text(
                      'What is your\nactivity level?',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 40,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This helps us understand your lifestyle',
                    style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _activityLevelsList.length,
                      itemBuilder: (context, index) {
                        final level = _activityLevelsList[index];
                        final isSelected = selectedLevel == level['id'];
                        return GestureDetector(
                          onTap: () => ref.read(selectedActivityLevelProvider.notifier).state = level['id'] as String,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LiquidTile(
                              selected: isSelected,
                              accent: kCoral,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          level['label'] as String,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? kCoral : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          level['description'] as String,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            color: kMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? kCoral : kMuted,
                                        width: 2,
                                      ),
                                      color: isSelected ? kCoral : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
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
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  neonButton(
                    label: 'Continue',
                    accent: kCoral,
                    onPressed: () {
                      final selected = ref.read(selectedActivityLevelProvider);
                      if (selected != null) {
                        final label = _activityLevelsList.firstWhere(
                          (l) => l['id'] == selected,
                          orElse: () => {'label': selected},
                        )['label'] as String;
                        ref.read(userProfileServiceProvider.notifier).setActivityLevel(label);
                        context.go(Routes.FITNESS_LEVEL);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select your activity level')),
                        );
                      }
                    },
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
}
