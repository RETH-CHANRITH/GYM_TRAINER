import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../providers/global_providers.dart';
import '../../../routes/app_router.dart' show Routes;

class HeightInputView extends ConsumerStatefulWidget {
  const HeightInputView({Key? key}) : super(key: key);

  @override
  ConsumerState<HeightInputView> createState() => _HeightInputViewState();
}

class _HeightInputViewState extends ConsumerState<HeightInputView> {
  // Dynamic accent colour — follows the user's chosen theme.
  Color get _accent => Theme.of(context).colorScheme.primary;

  late final TextEditingController _heightController;
  int _height = 170;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileServiceProvider);
    _height = profile.height;
    _heightController = TextEditingController(text: _height.toString());
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  void _setHeight(int value) {
    setState(() {
      _height = value;
      _heightController.text = value.toString();
    });
  }

  void _nextStep() {
    if (_height > 0) {
      ref.read(userProfileServiceProvider.notifier).setHeight(_height);
      context.go(Routes.FITNESS_GOAL);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid height')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: 'Your Height',
        onBack: () => context.go(Routes.WEIGHT_INPUT),
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
                          colors: [Colors.white, _accent],
                        ).createShader(b),
                    child: Text(
                      'How tall\nare you?',
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
                    'Helps us tailor exercises for your body type',
                    style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback:
                              (b) => LinearGradient(
                                colors: [Colors.white, _accent],
                              ).createShader(b),
                          child: Text(
                            '$_height',
                            style: const TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'centimetres',
                          style: GoogleFonts.dmSans(
                            color: kMuted,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _accent,
                            inactiveTrackColor: Colors.white.withOpacity(0.10),
                            thumbColor: _accent,
                            overlayColor: _accent.withOpacity(0.15),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _height.toDouble().clamp(100, 250),
                            min: 100,
                            max: 250,
                            divisions: 150,
                            onChanged: (v) => _setHeight(v.toInt()),
                          ),
                        ),
                        const SizedBox(height: 24),
                        LiquidTile(
                          padding: EdgeInsets.zero,
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null) {
                                setState(() {
                                  _height = n;
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
                  neonButton(
                    label: 'Continue',
                    onPressed: _nextStep,
                  ),
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
