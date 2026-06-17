 import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../config/glass_ui.dart';
import '../../controllers/admin_dashboard_controller.dart';
import '../components/admin_components.dart';
import '../../../../providers/rx_compat.dart';

class ConsoleTab extends ConsumerWidget {
  const ConsoleTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(adminDashboardProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return Obx(() {
      if (controller.isLoading.value) {
        return _buildLoadingState(accent);
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── System Status Banner ─────────────────────────────────────────
            _buildStatusBanner(accent),
            const SizedBox(height: 24),

            // ─── KPI Grid 1: Core Metrics ───────────────────────────────────
            Text(
              'Platform Overview',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Obx(
                  () => KpiCard(
                    title: 'Active Users',
                    value: '${controller.activeUsersCount.value}',
                    icon: Icons.people_rounded,
                    accentColor: kSky,
                  ),
                ),
                Obx(
                  () => KpiCard(
                    title: 'Active Trainers',
                    value: '${controller.activeTrainersCount.value}',
                    icon: Icons.verified_rounded,
                    accentColor: kLilac,
                  ),
                ),
                Obx(
                  () => KpiCard(
                    title: 'Open Bookings',
                    value: '${controller.openBookingsCount.value}',
                    icon: Icons.calendar_month_rounded,
                    accentColor: accent,
                  ),
                ),
                Obx(
                  () => KpiCard(
                    title: 'Pending Apps',
                    value:
                        '${controller.pendingTrainerApplicationsCount.value}',
                    icon: Icons.pending_actions_rounded,
                    accentColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── KPI Grid 2: Operational Metrics ─────────────────────────────
            Text(
              'Operational Status',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Obx(
                  () => KpiCard(
                    title: 'Support Queue',
                    value: '${controller.supportOpenCount.value}',
                    icon: Icons.support_agent_rounded,
                    accentColor: kCoral,
                  ),
                ),
                Obx(
                  () => KpiCard(
                    title: 'Open Disputes',
                    value: '${controller.disputeOpenCount.value}',
                    icon: Icons.gavel_rounded,
                    accentColor: Colors.red,
                  ),
                ),
                Obx(
                  () => KpiCard(
                    title: 'Pending Payouts',
                    value: '${controller.payoutPendingCount.value}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: kSky,
                  ),
                ),
                Obx(
                  () => KpiCard(
                    title: 'Pending Refunds',
                    value: '${controller.refundPendingCount.value}',
                    icon: Icons.money_off_rounded,
                    accentColor: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Finance KPI ────────────────────────────────────────────────
            Text(
              'Finance',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withOpacity(0.15), kLilac.withOpacity(0.15)],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Revenue',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kMuted,
                        ),
                      ),
                       Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Active',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => Text(
                      '\$${controller.monthlyRevenue.value.toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Text(
                      '${controller.transactions.length} transactions',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: kMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── GDPR & Audit Status ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    title: 'GDPR Requests',
                    value: '${controller.gdprPendingCount.value}',
                    icon: Icons.privacy_tip_rounded,
                    accentColor: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(
                    () => KpiCard(
                      title: 'Audit Logs',
                      value: '${controller.auditLogs.length}',
                      icon: Icons.history_rounded,
                      accentColor: kSky,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Platform Campaign Center ───────────────────────────────────
            Text(
              'Platform Campaign Center',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _CampaignCenterCard(controller: controller),
            const SizedBox(height: 24),

            // ─── Recent Activity ─────────────────────────────────────────────
            Text(
              'Recent Activity',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Obx(() {
                if (controller.recentActivity.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Activity',
                    message: 'No recent activity to display',
                    icon: Icons.history_rounded,
                  );
                }

                return Column(
                  children: List.generate(controller.recentActivity.length, (
                    index,
                  ) {
                    final activity = controller.recentActivity[index];
                    return Column(
                      children: [
                        ActivityItem(
                          title: activity['title'] ?? 'Activity',
                          subtitle: activity['subtitle'] ?? '',
                          time: activity['time'] ?? 'Now',
                        ),
                        if (index < controller.recentActivity.length - 1)
                          Divider(
                            color: Colors.white.withOpacity(0.08),
                            height: 16,
                          ),
                      ],
                    );
                  }),
                );
              }),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  Widget _buildStatusBanner([Color? accent]) {
    final c = accent ?? const Color(0xFFC8FF33);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withOpacity(0.1), kLilac.withOpacity(0.1)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Colors.green.withOpacity(0.6), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Status: Operational',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All systems running normally',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: kMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState([Color? accent]) {
    final c = accent ?? const Color(0xFFC8FF33);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 100),
          CircularProgressIndicator(color: c),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard...',
            style: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
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

class _CampaignCenterCard extends StatefulWidget {
  final AdminDashboardController controller;
  const _CampaignCenterCard({required this.controller});

  @override
  State<_CampaignCenterCard> createState() => _CampaignCenterCardState();
}

class _CampaignCenterCardState extends State<_CampaignCenterCard> {
  // Dynamic accent colour — follows the user's chosen theme.
  Color get _accent => Theme.of(context).colorScheme.primary;

  final _titleController = TextEditingController(text: '30% Off\nSpecial Promo');
  final _labelController = TextEditingController(text: 'LIMITED TIME');
  int _selectedDiscount = 30;

  @override
  void dispose() {
    _titleController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create a global campaign promotion. This will update the home screen banner and send a push notification to all clients.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Campaign Title',
                    labelStyle: const TextStyle(color: kMuted, fontSize: 11),
                    filled: true,
                    fillColor: Colors.black12,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _labelController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Label Badge',
                    labelStyle: const TextStyle(color: kMuted, fontSize: 11),
                    filled: true,
                    fillColor: Colors.black12,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discount Percentage:',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: DropdownButton<int>(
                  value: _selectedDiscount,
                  dropdownColor: const Color(0xFF17171F),
                  style: GoogleFonts.dmSans(
                    color: _accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  underline: const SizedBox.shrink(),
                  items: [10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val% Off'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDiscount = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () async {
                final title = _titleController.text.trim();
                final label = _labelController.text.trim();
                if (title.isEmpty || label.isEmpty) {
                  showSnackbar('Invalid Input', 'Please enter a title and label.');
                  return;
                }
                await widget.controller.publishCampaignPromotion(
                  title: title,
                  discount: _selectedDiscount,
                  label: label,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Publish & Notify Clients',
                style: GoogleFonts.dmSans(
                  color: kInk,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
