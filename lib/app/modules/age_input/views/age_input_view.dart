import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';
import '../../../routes/app_router.dart' show Routes;

class AgeInputView extends ConsumerStatefulWidget {
  const AgeInputView({Key? key}) : super(key: key);

  @override
  ConsumerState<AgeInputView> createState() => _AgeInputViewState();
}

class _AgeInputViewState extends ConsumerState<AgeInputView> {
  late final TextEditingController _ageController;
  int _age = 20;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileServiceProvider);
    _age = profile.age;
    _ageController = TextEditingController(text: _age.toString());
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _setAge(int value) {
    setState(() {
      _age = value;
      _ageController.text = value.toString();
    });
  }

  void _nextStep() {
    if (_age > 0 && _age < 150) {
      ref.read(userProfileServiceProvider.notifier).setAge(_age);
      context.go(Routes.WEIGHT_INPUT);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a valid age')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: 'Your Age',
        onBack: () => context.go(Routes.GENDER_SELECTION),
      ),
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
                      'How old\nare you?',
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
                    'Helps us create age-appropriate workouts',
                    style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback:
                              (b) => LinearGradient(
                                colors: [Colors.white, kNeon],
                              ).createShader(b),
                          child: Text(
                            '$_age',
                            style: const TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'years old',
                          style: GoogleFonts.dmSans(
                            color: kMuted,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: kNeon,
                            inactiveTrackColor: Colors.white.withOpacity(0.10),
                            thumbColor: kNeon,
                            overlayColor: kNeon.withOpacity(0.15),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _age.toDouble().clamp(13, 100),
                            min: 13,
                            max: 100,
                            divisions: 87,
                            onChanged: (v) => _setAge(v.toInt()),
                          ),
                        ),
                        const SizedBox(height: 24),
                        LiquidTile(
                          padding: EdgeInsets.zero,
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null) {
                                setState(() {
                                  _age = n;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'Or type here',
                              hintStyle: TextStyle(color: kMuted),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  neonButton(label: 'Continue', onPressed: _nextStep),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
