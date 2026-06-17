import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../routes/app_router.dart' show Routes;

class GetStartedView extends StatelessWidget {
  const GetStartedView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: kInk,
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const Spacer(),
                  // Glass logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: glassDecoration(
                          radius: 24,
                          glowColor: kSky,
                        ),
                        child: ShaderMask(
                          shaderCallback:
                              (b) => const LinearGradient(
                                colors: [Colors.white, kSky],
                              ).createShader(b),
                          child: const Icon(
                            Icons.directions_run_rounded,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ShaderMask(
                    shaderCallback:
                        (b) => const LinearGradient(
                          colors: [Colors.white, kSky],
                        ).createShader(b),
                    child: Text(
                      "LET'S GET\nSTARTED",
                      style: GoogleFonts.bebasNeue(
                        fontSize: 46,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about yourself to personalise your fitness plan',
                    style: GoogleFonts.dmSans(fontSize: 14, color: kMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _featureRow(
                    icon: Icons.person_rounded,
                    title: 'Personal Info',
                    desc: 'Share your basic details',
                    color: kNeon,
                  ),
                  const SizedBox(height: 12),
                  _featureRow(
                    icon: Icons.sports_gymnastics_rounded,
                    title: 'Fitness Goals',
                    desc: 'Define your workout objectives',
                    color: kCoral,
                  ),
                  const SizedBox(height: 12),
                  _featureRow(
                    icon: Icons.bar_chart_rounded,
                    title: 'Track Progress',
                    desc: 'Monitor your improvements',
                    color: kLilac,
                  ),
                  const Spacer(),
                  neonButton(
                    label: 'Continue',
                    accent: kSky,
                    onPressed: () => context.go(Routes.GENDER_SELECTION),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return LiquidTile(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
