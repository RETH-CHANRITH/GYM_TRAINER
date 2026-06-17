import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/notification_permission_controller.dart';
import '../../../../config/glass_ui.dart';

class NotificationPermissionView extends ConsumerWidget {
  const NotificationPermissionView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationPermissionProvider);
    final notifier = ref.read(notificationPermissionProvider.notifier);

    return Scaffold(
      backgroundColor: kInk,
      extendBodyBehindAppBar: true,
      appBar: glassAppBar(
        title: 'Notifications',
        onBack: () => context.pop(),
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
                      'Stay\nUpdated',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 40,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enable notifications to get reminders about your workouts',
                    style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kSky.withOpacity(0.12),
                                border: Border.all(
                                  color: kSky.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_rounded,
                                size: 52,
                                color: kSky,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        GestureDetector(
                          onTap: () => notifier.toggleNotification(!enabled),
                          child: LiquidTile(
                            selected: enabled,
                            accent: kSky,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notifications_active_rounded,
                                  color: enabled ? kSky : kMuted,
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enable Notifications',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: enabled ? kSky : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Get reminders and updates',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          color: kMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: enabled,
                                  onChanged: notifier.toggleNotification,
                                  activeColor: kInk,
                                  activeTrackColor: kSky,
                                  inactiveThumbColor: kMuted,
                                  inactiveTrackColor: Colors.white.withOpacity(0.08),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'You can change this anytime in settings',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: kMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  neonButton(
                    label: 'Continue',
                    accent: kSky,
                    onPressed: () => context.push('/profile-summary'),
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
