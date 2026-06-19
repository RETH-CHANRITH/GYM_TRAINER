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

      return RefreshIndicator(
        onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 800)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                        '${controller.monthlyRevenueBookingsCount.value} bookings',
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
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Platform Campaign Center',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      'ADMIN TOOL',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Create & publish promotions to all clients instantly',
                style: GoogleFonts.dmSans(fontSize: 11, color: kMuted),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: _CampaignCenterCard(controller: controller),
              ),
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
        ),
      );
    });
  }
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

class _CampaignCenterCardState extends State<_CampaignCenterCard>
    with TickerProviderStateMixin {
  Color get _accent => Theme.of(context).colorScheme.primary;

  final _titleController = TextEditingController(text: 'Special Promo');
  final _labelController = TextEditingController(text: 'LIMITED TIME');
  double _discountValue = 30;
  int _selectedTypeIndex = 0;
  int _selectedDuration = 7;
  bool _isPublishing = false;
  bool _isCustomDuration = false;
  final _customDaysController = TextEditingController();

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnim;
  late Animation<double> _shimmerAnim;

  final List<Map<String, dynamic>> _campaignTypes = [
    {'label': 'Flash Sale', 'icon': Icons.bolt_rounded, 'color': const Color(0xFFFFB800)},
    {'label': 'Seasonal', 'icon': Icons.ac_unit_rounded, 'color': const Color(0xFF00D4FF)},
    {'label': 'Loyalty', 'icon': Icons.favorite_rounded, 'color': const Color(0xFFFF5C8A)},
    {'label': 'New Member', 'icon': Icons.person_add_rounded, 'color': const Color(0xFF9B59FF)},
  ];

  final List<int> _durations = [3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _titleController.addListener(() => setState(() {}));
    _labelController.addListener(() => setState(() {}));
    _customDaysController.addListener(() {
      final val = int.tryParse(_customDaysController.text);
      if (val != null && val > 0) {
        setState(() {
          _selectedDuration = val;
          _isCustomDuration = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _titleController.dispose();
    _labelController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  Color get _typeColor => _campaignTypes[_selectedTypeIndex]['color'] as Color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Live Preview Banner ──────────────────────────────────────────
        _buildLivePreview(),
        const SizedBox(height: 20),

        // ── Campaign Type Selector ────────────────────────────────────────
        _buildSectionLabel('Campaign Type', Icons.campaign_rounded),
        const SizedBox(height: 10),
        _buildTypeChips(),
        const SizedBox(height: 20),

        // ── Campaign Details Card ─────────────────────────────────────────
        _buildDetailsCard(),
        const SizedBox(height: 20),

        // ── Discount Slider ───────────────────────────────────────────────
        _buildDiscountSlider(),
        const SizedBox(height: 20),

        // ── Duration Selector ─────────────────────────────────────────────
        _buildSectionLabel('Campaign Duration', Icons.timer_rounded),
        const SizedBox(height: 10),
        _buildDurationPicker(),
        const SizedBox(height: 24),

        // ── Publish Button ────────────────────────────────────────────────
        _buildPublishButton(),
      ],
    );
  }

  // ── LIVE PREVIEW ──────────────────────────────────────────────────────────
  Widget _buildLivePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel('Live Preview', Icons.visibility_rounded),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _shimmerAnim,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _typeColor.withOpacity(0.25),
                    _accent.withOpacity(0.18),
                    _typeColor.withOpacity(0.12),
                  ],
                ),
                border: Border.all(color: _typeColor.withOpacity(0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _typeColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Shimmer sweep
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment(_shimmerAnim.value - 1, -0.5),
                          end: Alignment(_shimmerAnim.value, 0.5),
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ).createShader(bounds),
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _typeColor.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: -30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Discount badge
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [_typeColor, _typeColor.withOpacity(0.6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _typeColor.withOpacity(0.5),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_discountValue.round()}%',
                                style: GoogleFonts.dmSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'OFF',
                                style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Label badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _typeColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _typeColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  _labelController.text.isEmpty
                                      ? 'LABEL'
                                      : _labelController.text.toUpperCase(),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _typeColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _titleController.text.isEmpty
                                    ? 'Campaign Title'
                                    : _titleController.text,
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 11, color: kMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ends in $_selectedDuration days',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: kMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── SECTION LABEL ────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _accent),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── CAMPAIGN TYPE CHIPS ──────────────────────────────────────────────────
  Widget _buildTypeChips() {
    return Row(
      children: List.generate(_campaignTypes.length, (i) {
        final type = _campaignTypes[i];
        final isSelected = i == _selectedTypeIndex;
        final color = type['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTypeIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: isSelected ? color : Colors.white.withOpacity(0.1),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10)]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    type['icon'] as IconData,
                    size: 18,
                    color: isSelected ? color : kMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type['label'] as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? color : kMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── CAMPAIGN DETAILS CARD ────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Campaign Details', Icons.edit_rounded),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _titleController,
            label: 'Campaign Title',
            hint: 'e.g. Summer Body Challenge',
            icon: Icons.title_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _labelController,
            label: 'Label Badge',
            hint: 'e.g. LIMITED TIME, HOT DEAL',
            icon: Icons.label_rounded,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: kMuted.withOpacity(0.5), fontSize: 12),
        labelStyle: GoogleFonts.dmSans(color: kMuted, fontSize: 11),
        prefixIcon: Icon(icon, size: 16, color: kMuted),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  // ── DISCOUNT SLIDER ──────────────────────────────────────────────────────
  Widget _buildDiscountSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_typeColor.withOpacity(0.12), _accent.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _typeColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionLabel('Discount Rate', Icons.percent_rounded),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _typeColor.withOpacity(0.5)),
                ),
                child: Text(
                  '${_discountValue.round()}% OFF',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _typeColor,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: _typeColor,
              overlayColor: _typeColor.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              trackHeight: 4,
            ),
            child: Slider(
              value: _discountValue,
              min: 5,
              max: 90,
              divisions: 17,
              onChanged: (val) => setState(() => _discountValue = val),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5%', style: GoogleFonts.dmSans(fontSize: 10, color: kMuted)),
              // Quick preset chips
              Row(
                children: [10, 20, 30, 50].map((preset) {
                  final isActive = _discountValue.round() == preset;
                  return GestureDetector(
                    onTap: () => setState(() => _discountValue = preset.toDouble()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? _typeColor.withOpacity(0.25) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? _typeColor : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        '$preset%',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive ? _typeColor : kMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Text('90%', style: GoogleFonts.dmSans(fontSize: 10, color: kMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── DURATION PICKER ──────────────────────────────────────────────────────
  Widget _buildDurationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Preset chips ────────────────────────────────────────────────
        Row(
          children: _durations.map((days) {
            final isSelected = !_isCustomDuration && _selectedDuration == days;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _customDaysController.clear();
                  setState(() {
                    _selectedDuration = days;
                    _isCustomDuration = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: EdgeInsets.only(right: days != _durations.last ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? _accent.withOpacity(0.18) : Colors.white.withOpacity(0.06),
                    border: Border.all(
                      color: isSelected ? _accent : Colors.white.withOpacity(0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$days',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? _accent : Colors.white,
                        ),
                      ),
                      Text(
                        'days',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: isSelected ? _accent.withOpacity(0.8) : kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // ── Custom input ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customDaysController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.dmSans(
                  color: _isCustomDuration ? _accent : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Or type custom days (e.g. 45)',
                  hintStyle: TextStyle(color: kMuted.withOpacity(0.5), fontSize: 12),
                  prefixIcon: Icon(
                    Icons.edit_calendar_rounded,
                    size: 16,
                    color: _isCustomDuration ? _accent : kMuted,
                  ),
                  filled: true,
                  fillColor: _isCustomDuration
                      ? _accent.withOpacity(0.08)
                      : Colors.black.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isCustomDuration ? _accent.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                      width: _isCustomDuration ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),
            ),
            if (_isCustomDuration) ...
              [
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$_selectedDuration d',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
                ),
              ],
          ],
        ),
      ],
    );
  }

  // ── PUBLISH BUTTON ───────────────────────────────────────────────────────
  Widget _buildPublishButton() {
    return GestureDetector(
      onTap: _isPublishing
          ? null
          : () async {
              final title = _titleController.text.trim();
              final label = _labelController.text.trim();
              if (title.isEmpty || label.isEmpty) {
                showSnackbar('Invalid Input', 'Please enter a campaign title and label.');
                return;
              }
              setState(() => _isPublishing = true);
              try {
                await widget.controller.publishCampaignPromotion(
                  title: title,
                  discount: _discountValue.round(),
                  label: label,
                );
              } finally {
                if (mounted) setState(() => _isPublishing = false);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _isPublishing
              ? LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade700])
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_typeColor, _accent],
                ),
          boxShadow: _isPublishing
              ? []
              : [
                  BoxShadow(
                    color: _typeColor.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isPublishing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Publishing Campaign...',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _campaignTypes[_selectedTypeIndex]['icon'] as IconData,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Publish & Notify All Clients',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
