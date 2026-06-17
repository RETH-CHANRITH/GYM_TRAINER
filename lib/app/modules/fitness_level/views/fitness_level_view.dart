import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';
import '../../../routes/app_router.dart' show Routes;

final selectedFitnessLevelProvider = StateProvider<String?>((ref) => null);

final _fitnessLevelsList = const [
  {'id': 'beginner', 'label': 'Beginner', 'description': 'Just starting out'},
  {
    'id': 'intermediate',
    'label': 'Intermediate',
    'description': 'Some experience',
  },
  {'id': 'advanced', 'label': 'Advanced', 'description': 'Very experienced'},
];

class FitnessLevelView extends ConsumerWidget {
  const FitnessLevelView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLevel = ref.watch(selectedFitnessLevelProvider);
    final kNeon = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: 'Fitness Level',
        onBack: () => context.go(Routes.ACTIVITY_LEVEL),
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
                          colors: [kSky, kNeon],
                        ).createShader(b),
                    child: Text(
                      'What is your\nfitness level?',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 40,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Help us tailor workouts to your experience',
                    style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _fitnessLevelsList.length,
                      itemBuilder: (context, index) {
                        final level = _fitnessLevelsList[index];
                        final isSelected = selectedLevel == level['id'];
                        return GestureDetector(
                          onTap: () => ref.read(selectedFitnessLevelProvider.notifier).state = level['id'] as String,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LiquidTile(
                              selected: isSelected,
                              accent: kSky,
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
                                            color: isSelected ? kSky : Colors.white,
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
                                        color: isSelected ? kSky : kMuted,
                                        width: 2,
                                      ),
                                      color: isSelected ? kSky : Colors.transparent,
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
                    accent: kSky,
                    onPressed: () {
                      final selected = ref.read(selectedFitnessLevelProvider);
                      if (selected != null) {
                        final label = _fitnessLevelsList.firstWhere(
                          (l) => l['id'] == selected,
                          orElse: () => {'label': selected},
                        )['label'] as String;
                        ref.read(userProfileServiceProvider.notifier).setFitnessLevel(label);
                        context.go(Routes.NOTIFICATION_PERMISSION);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select your fitness level')),
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
