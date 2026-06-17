import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';
import '../../../routes/app_router.dart' show Routes;

final selectedGoalProvider = StateProvider<String?>((ref) => null);

final _goalsList = const [
  {
    'id': 'weight_loss',
    'label': 'Weight Loss',
    'icon': Icons.monitor_weight_rounded,
  },
  {
    'id': 'muscle_gain',
    'label': 'Muscle Gain',
    'icon': Icons.fitness_center_rounded,
  },
  {
    'id': 'endurance',
    'label': 'Build Endurance',
    'icon': Icons.directions_run_rounded,
  },
  {
    'id': 'flexibility',
    'label': 'Improve Flexibility',
    'icon': Icons.self_improvement_rounded,
  },
];

class FitnessGoalView extends ConsumerWidget {
  const FitnessGoalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGoal = ref.watch(selectedGoalProvider);

    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: 'Fitness Goal',
        onBack: () => context.go(Routes.HEIGHT_INPUT),
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
                        (b) => const LinearGradient(
                          colors: [kLilac, kPink],
                        ).createShader(b),
                    child: Text(
                      'What is your\nfitness goal?',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 40,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the goal that matters most to you',
                    style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _goalsList.length,
                      itemBuilder: (context, index) {
                        final goal = _goalsList[index];
                        final isSelected = selectedGoal == goal['id'];
                        return GestureDetector(
                           onTap: () => ref.read(selectedGoalProvider.notifier).state = goal['id'] as String,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LiquidTile(
                              selected: isSelected,
                              accent: kLilac,
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: (isSelected ? kLilac : Colors.white).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: (isSelected ? kLilac : Colors.white).withOpacity(0.24),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      goal['icon'] as IconData,
                                      color: isSelected ? kLilac : Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      goal['label'] as String,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? kLilac : Colors.white,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? kLilac : kMuted,
                                        width: 2,
                                      ),
                                      color: isSelected ? kLilac : Colors.transparent,
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
                    accent: kLilac,
                    onPressed: () {
                      final selected = ref.read(selectedGoalProvider);
                      if (selected != null) {
                        final label = _goalsList.firstWhere(
                          (g) => g['id'] == selected,
                          orElse: () => {'label': selected},
                        )['label'] as String;
                        ref.read(userProfileServiceProvider.notifier).setFitnessGoal(label);
                        context.go(Routes.ACTIVITY_LEVEL);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select your fitness goal')),
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
