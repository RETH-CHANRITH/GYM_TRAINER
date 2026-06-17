import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/glass_ui.dart';
import '../controllers/admin_dashboard_controller.dart';
import 'tabs/console_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/trainer_applications_tab.dart';
import 'tabs/bookings_and_finance_tabs.dart';
import 'tabs/security_tab.dart';

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  // Tab metadata
  static const List<IconData> _tabIcons = [
    Icons.dashboard_customize_rounded,
    Icons.manage_accounts_rounded,
    Icons.event_available_rounded,
    Icons.calendar_today_rounded,
    Icons.security_rounded,
  ];

  static const List<String> _tabLabels = [
    'Console',
    'Users',
    'Trainers',
    'Bookings',
    'Security',
  ];

  static const List<Color> _tabAccents = [
    Color(0xFF38C9FF),
    Color(0xFFC8FF33),
    Color(0xFFFF4F4F),
    Color(0xFFAB7EFF),
    Color(0xFF38C9FF),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Obx(
          () => Text(
            _tabLabels[controller.currentTab.value],
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context, controller),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          Obx(
            () => IndexedStack(
              index: controller.currentTab.value,
              children: [
                ConsoleTab(),
                UsersTab(),
                TrainerApplicationsTab(),
                BookingsTab(),
                SecurityTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: controller.currentTab.value,
          backgroundColor: const Color(0xFF07010E).withValues(alpha: 0.85),
          selectedItemColor: _tabAccents[controller.currentTab.value],
          unselectedItemColor: const Color(0xFF8484A0),
          onTap: controller.changeTab,
          items: List.generate(
            _tabLabels.length,
            (index) => BottomNavigationBarItem(
              icon: Icon(_tabIcons[index]),
              label: _tabLabels[index],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AdminDashboardController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1620),
        title: Text(
          'Logout',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: const Color(0xFFB8B8C8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF38C9FF),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.logout();
            },
            child: Text(
              'Logout',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFF4F4F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Obx extends ConsumerWidget {
  final Widget Function() builder;
  const Obx(this.builder, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminDashboardProvider);
    return builder();
  }
}
