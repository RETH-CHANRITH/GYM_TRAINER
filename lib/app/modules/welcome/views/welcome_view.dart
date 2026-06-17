import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../../../routes/app_router.dart' show Routes;

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // Dynamic accent colour — follows the user's chosen theme.
    final kNeon = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: kInk,
      body: Stack(
        children: [
          // Deep premium gradient background
          Positioned.fill(child: liquidBackground()),
          
          // Glow Orbs to add depth and neon vibes
          const Positioned(
            top: 80,
            left: -50,
            child: GlowOrb(color: kSky, radius: 150),
          ),
          Positioned(
            bottom: 120,
            right: -80,
            child: GlowOrb(color: kNeon, radius: 180),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  
                  // Premium Logo Container with Glassmorphism and Glow
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kNeon.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/image/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Welcome Header with Gradient Text
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, kNeon],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      'WELCOME',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 56,
                        color: Colors.white,
                        letterSpacing: 3,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'TO YOUR FITNESS JOURNEY',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const Spacer(flex: 1),
                  
                  // Description Glass Tile
                  LiquidTile(
                    radius: 24,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: kNeon.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kNeon.withOpacity(0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.bolt_rounded,
                            color: kNeon,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Get ready to transform your body and achieve your fitness goals with professional personal trainers.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Call-to-action Neon Button
                  neonButton(
                    label: 'GET STARTED',
                    accent: kNeon,
                    onPressed: () => context.go(Routes.GET_STARTED),
                  ),
                  
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
