import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../config/glass_ui.dart';
import '../../controllers/admin_dashboard_controller.dart';
import '../components/admin_components.dart';

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(adminDashboardProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: accent,
            unselectedLabelColor: kMuted,
            indicatorColor: accent,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Sessions'),
              Tab(text: 'Payouts'),
              Tab(text: 'Refunds'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSessionsTab(context, controller),
                _buildPayoutsTab(context, controller),
                _buildRefundsTab(context, controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context, AdminDashboardController controller) {
    final accent = Theme.of(context).colorScheme.primary;
    return RefreshIndicator(
      onRefresh: () => Future.wait([
        controller.loadBookings(),
        Future.delayed(const Duration(milliseconds: 800)),
      ]),
      child: Obx(() {
        if (controller.loadingBookings.value) {
          return Center(child: CircularProgressIndicator(color: accent));
        }

        if (controller.bookings.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: EmptyStateWidget(
                    title: 'No Bookings',
                    message: 'No bookings to display',
                    icon: Icons.calendar_today_rounded,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: controller.bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => Builder(
            builder: (context) => _buildBookingCard(
              context,
              controller,
              controller.bookings[index],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    AdminDashboardController controller,
    Map<String, dynamic> booking,
  ) {
    final bookingId = booking['id'] as String? ?? '';
    final trainerName = booking['trainerName'] as String? ?? 'Unknown';
    final status = booking['status'] as String? ?? 'pending';
    final scheduledAt = _formatScheduledAt(booking['scheduledAt']);
    final price = booking['price'] as num? ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trainerName,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    scheduledAt,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
              StatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: kMuted,
                ),
              ),
              Text(
                '\$$price',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (status != 'completed' && status != 'cancelled')
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => AdminActionButton(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      isDestructive: true,
                      isLoading: controller.actionLoading.value,
                      onPressed:
                          bookingId.isNotEmpty
                              ? () => _showCancelDialog(context, bookingId, controller)
                              : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminActionButton(
                    label: 'Reassign',
                    icon: Icons.type_specimen_rounded,
                    isOutlined: true,
                    onPressed:
                        bookingId.isNotEmpty
                            ? () => _showReassignDialog(context, bookingId, controller)
                            : null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    String bookingId,
    AdminDashboardController controller,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0330),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Booking',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Cancellation reason...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AdminActionButton(
                  label: 'Keep',
                  isOutlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(
                  () => AdminActionButton(
                    label: 'Cancel',
                    isDestructive: true,
                    isLoading: controller.actionLoading.value,
                    onPressed: () {
                      controller.cancelBooking(bookingId, reasonController.text);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReassignDialog(
    BuildContext context,
    String bookingId,
    AdminDashboardController controller,
  ) {
    final trainerIdController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0330),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reassign Booking',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: TextField(
          controller: trainerIdController,
          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'New Trainer ID...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AdminActionButton(
                  label: 'Cancel',
                  isOutlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AdminActionButton(
                  label: 'Reassign',
                  onPressed: () {
                    if (trainerIdController.text.isNotEmpty) {
                      controller.reassignBooking(bookingId, trainerIdController.text);
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab(BuildContext context, AdminDashboardController controller) {
    return RefreshIndicator(
      onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 800)),
      child: Obx(() {
        if (controller.loadingFinance.value) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }

        if (controller.payouts.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: EmptyStateWidget(
                    title: 'No Payouts',
                    message: 'No payout requests',
                    icon: Icons.account_balance_rounded,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: controller.payouts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
          final payout = controller.payouts[index];
          final status = payout['status'] as String? ?? 'pending';
          final amount = payout['amount'] as num? ?? 0;
          final trainerId = payout['trainerId']?.toString() ?? '';
          final requestedAt = _formatScheduledAt(payout['requestedAt']);

          // Look up trainer details dynamically from users list
          final trainerUser = controller.users.firstWhere(
            (u) => u['id'] == trainerId,
            orElse: () => <String, dynamic>{},
          );
          final trainerName = (trainerUser['name'] ??
                  trainerUser['fullName'] ??
                  trainerUser['displayName'] ??
                  'Trainer')
              .toString();

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payout to $trainerName',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Trainer ID: $trainerId',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: kMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requested: $requestedAt',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: kMuted,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$$amount',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (status == 'pending' || status == 'requested')
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => AdminActionButton(
                            label: 'Approve Payout',
                            isLoading: controller.actionLoading.value,
                            onPressed: () => controller.approvePayout(payout['id']),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (status == 'approved')
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => AdminActionButton(
                            label: 'Mark as Paid',
                            isLoading: controller.actionLoading.value,
                            onPressed: () => controller.markPayoutAsPaid(payout['id']),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }),
  );
}

  Widget _buildRefundsTab(BuildContext context, AdminDashboardController controller) {
    return RefreshIndicator(
      onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 800)),
      child: Obx(() {
        if (controller.loadingFinance.value) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }

        if (controller.refunds.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: EmptyStateWidget(
                    title: 'No Refunds',
                    message: 'No refund requests',
                    icon: Icons.money_off_rounded,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: controller.refunds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
          final refund = controller.refunds[index];
          final status = refund['status'] as String? ?? 'pending';
          final amount = refund['amount'] as num? ?? 0;

          final clientName = refund['clientName']?.toString() ?? 'Client';
          final trainerName = refund['trainerName']?.toString() ?? 'Trainer';
          final date = refund['sessionDate']?.toString() ?? '';
          final time = refund['sessionTime']?.toString() ?? '';
          final type = refund['sessionType']?.toString() ?? 'Session';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refund to $clientName',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$type with $trainerName',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: kMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (date.isNotEmpty)
                            Text(
                              '$date at $time',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: kMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$$amount',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF5C5C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (status == 'pending' || status == 'requested')
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => AdminActionButton(
                            label: 'Approve & Refund',
                            isLoading: controller.actionLoading.value,
                            onPressed: () => controller.approveRefund(refund),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }),
  );
}

  String _formatScheduledAt(dynamic raw) {
    if (raw == null) return 'N/A';
    if (raw is String) return raw;
    if (raw is Timestamp) {
      final dt = raw.toDate();
      return _formatDateTime(dt);
    }
    if (raw is DateTime) {
      return _formatDateTime(raw);
    }
    return raw.toString();
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year;
    
    final hourNum = dt.hour;
    final amPm = hourNum >= 12 ? 'PM' : 'AM';
    final displayHour = hourNum == 0 ? 12 : (hourNum > 12 ? hourNum - 12 : hourNum);
    final minute = dt.minute.toString().padLeft(2, '0');
    
    return '$month $day, $year at ${displayHour.toString().padLeft(2, '0')}:$minute $amPm';
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
