import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/glass_ui.dart';
import '../../../services/bookings_service.dart';
import '../../wallet/controllers/wallet_controller.dart';
import '../../trainer/views/trainer_rating_sheet.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
const Color ink = Color(0xFF0A0A0F);
const Color surface = Color(0xFF111118);
const Color card = Color(0xFF17171F);
const Color raised = Color(0xFF1E1E28);
const Color stroke = Color(0xFF2A2A36);
const Color neon = Color(0xFFCBFF47);
const Color coral = Color(0xFFFF5C5C);
const Color sky = Color(0xFF5CE8FF);
const Color lilac = Color(0xFFA78BFA);
const Color muted = Color(0xFF6B6B7E);

class MyBookingsView extends ConsumerStatefulWidget {
  const MyBookingsView({super.key});

  @override
  ConsumerState<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends ConsumerState<MyBookingsView> {
  int _tabIndex = 0;

  Color get ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get surface => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFE5E7EB);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black54;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  @override
  void initState() {
    super.initState();
    // Schedule checking extra arguments after build to avoid GoRouterState context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final state = GoRouterState.of(context);
        final extra = state.extra as Map<String, dynamic>?;
        if (extra != null && extra['tab'] == 1) {
          setState(() {
            _tabIndex = 1;
          });
        }
      } catch (_) {
        // Safe to ignore if GoRouterState is not present
      }
    });
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final id = booking['id'] as String? ?? '';
    if (id.isEmpty) return;
    await ref.read(bookingsServiceProvider.notifier).cancelBooking(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has been cancelled.'),
        backgroundColor: coral,
      ),
    );
  }

  Future<void> _payForSession(Map<String, dynamic> booking) async {
    final id = booking['id'] as String? ?? '';
    final trainerName = (booking['trainerName'] ?? booking['trainer'] ?? '') as String;
    final totalPrice = (booking['price'] as num?)?.toInt() ?? 0;
    final portrait = booking['portrait'] as int?;

    final discountApplied = (booking['discountApplied'] as num?)?.toInt() ?? 0;
    final hasDiscount = discountApplied > 0;
    final targetPrice = hasDiscount 
        ? (totalPrice * (1 - (discountApplied / 100))).round() 
        : totalPrice;

    final amountPaid = (booking['amountPaid'] as num?)?.toInt() ?? 0;
    final remainingPrice = targetPrice - amountPaid;
    final hasPaidDeposit = !hasDiscount && amountPaid > 0 && amountPaid < targetPrice;

    final middlePrice = (targetPrice / 2).round();
    int selectedAmount = hasPaidDeposit ? remainingPrice : targetPrice; // Default to remaining or full

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final balance = ref.read(walletNotifierProvider).balance;
            final hasSufficientFunds = balance >= selectedAmount;

            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: stroke, width: 1.5),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: stroke,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Session Payment Options',
                      style: TextStyle(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Select a payment plan for your session with $trainerName',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Session Summary Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: stroke),
                          ),
                          child: PremiumAvatar(
                            name: trainerName,
                            customPhotoUrl: booking['trainerPhotoUrl']?.toString(),
                            size: 44,
                            borderRadius: 10,
                            isTrainer: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trainerName,
                                style: TextStyle(
                                  color: text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                (booking['specialty'] ?? booking['sessionType'] ?? 'Strength Training').toString(),
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (hasPaidDeposit) ...[
                    // Render single option card for remaining balance
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: neon.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: neon,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: neon,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Remaining Balance',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pay the remaining session balance (50%)',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$$remainingPrice',
                            style: TextStyle(
                              color: neon,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasDiscount) ...[
                    // Render single option card for full discounted price
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: neon.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: neon,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: neon,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Full Session Payment',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pay the discounted session fee ($discountApplied% Off)',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$$targetPrice',
                            style: TextStyle(
                              color: neon,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Option 1: Middle Session (50%)
                    GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          selectedAmount = middlePrice;
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedAmount == middlePrice ? neon.withOpacity(0.04) : card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedAmount == middlePrice ? neon : stroke,
                            width: selectedAmount == middlePrice ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedAmount == middlePrice
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: selectedAmount == middlePrice ? neon : muted,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Middle Session',
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pay 50% of the session fee now',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$$middlePrice',
                              style: TextStyle(
                                color: selectedAmount == middlePrice ? neon : text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option 2: Full Session (100%)
                    GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          selectedAmount = totalPrice;
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedAmount == totalPrice ? neon.withOpacity(0.04) : card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedAmount == totalPrice ? neon : stroke,
                            width: selectedAmount == totalPrice ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedAmount == totalPrice
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: selectedAmount == totalPrice ? neon : muted,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Full Session',
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pay 100% of the session fee now',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$$totalPrice',
                              style: TextStyle(
                                color: selectedAmount == totalPrice ? neon : text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Wallet Balance Summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: raised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stroke),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            color: muted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '\$${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pay Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(sheetContext); // Close selection sheet

                        final success = ref.read(walletNotifierProvider.notifier).payForSession(
                          trainerName,
                          selectedAmount,
                          portrait: portrait,
                          trainerPhotoUrl: booking['trainerPhotoUrl'],
                          onNotifyUser: (msg) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: coral),
                            );
                          },
                        );

                        if (success && id.isNotEmpty) {
                          await ref.read(bookingsServiceProvider.notifier).markPaid(id, selectedAmount);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment Successful: \$$selectedAmount paid for your session with $trainerName.'),
                              backgroundColor: neon,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasSufficientFunds ? neon : raised,
                        foregroundColor: hasSufficientFunds ? ink : muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: hasSufficientFunds ? 4 : 0,
                      ),
                      child: Text(
                        hasSufficientFunds
                            ? 'Confirm & Pay \$$selectedAmount'
                            : 'Insufficient Funds (Top up)',
                        style: TextStyle(
                          color: hasSufficientFunds ? ink : muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingsState = ref.watch(bookingsServiceProvider);
    ref.watch(walletNotifierProvider);
    
    final list = _tabIndex == 0 ? bookingsState.upcomingBookings : bookingsState.pastBookings;
    final isLoading = bookingsState.isLoading;

    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: text),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'My Bookings',
          style: TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          Column(
            children: [
              _buildTabs(),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: neon),
                      )
                    : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.calendar_badge_minus,
                              color: muted,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No bookings here',
                              style: TextStyle(color: muted, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _buildBookingCard(list[i]),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Upcoming', 'Past'];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stroke),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? neon : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? ink : muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showBookingDetail(
    BuildContext context,
    Map<String, dynamic> b,
  ) {
    final status = (b['status'] ?? 'pending').toString();
    final Color statusColor = status == 'confirmed'
        ? neon
        : status == 'pending'
            ? sky
            : status == 'completed'
                ? lilac
                : coral;
    final bool isActive = status == 'confirmed' || status == 'pending';

    final paid = b['paid'] == true;
    final amountPaid = (b['amountPaid'] as num?)?.toInt() ?? 0;
    final price = (b['price'] as num?)?.toInt() ?? 0;
    final discountApplied = (b['discountApplied'] as num?)?.toInt() ?? 0;
    final targetPrice = discountApplied > 0 
        ? (price * (1 - (discountApplied / 100))).round() 
        : price;
    final remaining = targetPrice - amountPaid;
    var paymentStatus = b['paymentStatus'] as String? ?? (paid ? 'fully_paid' : (amountPaid > 0 ? 'partially_paid' : 'unpaid'));
    if (paymentStatus == 'completed') paymentStatus = 'fully_paid';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color paymentColor = paymentStatus == 'fully_paid'
        ? neon
        : paymentStatus == 'partially_paid'
            ? (isDark ? const Color(0xFFFFBB33) : const Color(0xFFD97706))
            : const Color(0xFFFF5C5C);

    final String paymentText = paymentStatus == 'fully_paid'
        ? 'Paid'
        : paymentStatus == 'partially_paid'
            ? '50% Paid (\$$amountPaid paid / \$$remaining left)'
            : 'Unpaid';

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final offsetY = (1 - value) * 18;
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, offsetY),
                  child: child,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: stroke,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Booking Details',
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(
                        '/trainer-details',
                        extra: {
                          'id': b['trainerId'] ?? '',
                          'trainerId': b['trainerId'] ?? '',
                          'name': b['trainer'] ?? b['trainerName'] ?? 'Trainer',
                          'specialty': b['specialty'] ?? 'Personal Training',
                          'portrait': b['portrait'] ?? 10,
                          'price': b['price'] ?? 0,
                          'image': b['trainerPhotoUrl'] ?? '',
                          'isAvailable': true,
                        },
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: stroke),
                          ),
                            child: PremiumAvatar(
                              name: (b['trainer'] ?? b['trainerName'] ?? 'Trainer').toString(),
                              customPhotoUrl: b['trainerPhotoUrl']?.toString(),
                              size: 56,
                              borderRadius: 14,
                              isTrainer: true,
                            ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      (b['trainer'] ?? b['trainerName'] ?? 'Trainer').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: text,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    color: muted,
                                    size: 14,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                (b['specialty'] ?? 'Personal Training').toString(),
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1).toLowerCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: stroke),
                  const SizedBox(height: 16),
                  _detailRow(
                    CupertinoIcons.calendar,
                    'Date',
                    (b['date'] ?? '').toString(),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(CupertinoIcons.clock, 'Time', (b['time'] ?? '').toString()),
                  const SizedBox(height: 10),
                  _detailRow(
                    CupertinoIcons.person_2,
                    'Type',
                    (b['type'] ?? '1-on-1').toString(),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    CupertinoIcons.money_dollar_circle,
                    'Price',
                    discountApplied > 0 
                        ? '\$$targetPrice (\$$price - $discountApplied%)' 
                        : '\$$price',
                    valueColor: neon,
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    CupertinoIcons.checkmark_shield,
                    'Payment',
                    paymentText,
                    valueColor: paymentColor,
                  ),
                  const SizedBox(height: 18),
                  if (isActive) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                              _cancelBooking(b);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: coral,
                              side: const BorderSide(color: coral),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: paymentStatus == 'fully_paid'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: neon.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: neon.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.checkmark_circle_fill,
                                        color: neon,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Paid',
                                        style: TextStyle(
                                          color: neon,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(context);
                                    _payForSession(b);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: paymentStatus == 'partially_paid' ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFBB33) : const Color(0xFFD97706)) : neon,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 6,
                                    shadowColor: (paymentStatus == 'partially_paid' ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFBB33) : const Color(0xFFD97706)) : neon).withValues(alpha: 0.4),
                                  ),
                                  child: Text(
                                    paymentStatus == 'partially_paid'
                                        ? 'Pay Balance (\$$remaining)'
                                        : 'Pay \$$targetPrice',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: paymentStatus == 'partially_paid' ? text : ink,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                          final tId = (b['trainerId'] ?? '').toString();
                          final tName = (b['trainer'] ?? b['trainerName'] ?? 'Trainer').toString();
                          if (tId.isNotEmpty) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => TrainerRatingSheet(
                                trainerId: tId,
                                trainerName: tName,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not find trainer details for this booking.'),
                                backgroundColor: coral,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: raised,
                          foregroundColor: text,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Icon(CupertinoIcons.star, color: text, size: 16),
                        label: Text(
                          'Leave a Review',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
    ).whenComplete(HapticFeedback.selectionClick);
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final effectiveValueColor = valueColor ?? text;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: stroke),
          ),
          child: Icon(icon, color: muted, size: 16),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: muted, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: effectiveValueColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final status = (b['status'] ?? 'pending').toString();
    final Color statusColor = status == 'confirmed'
        ? neon
        : status == 'pending'
            ? sky
            : status == 'completed'
            ? lilac
            : coral;

    final paid = b['paid'] == true;
    final amountPaid = (b['amountPaid'] as num?)?.toInt() ?? 0;
    final price = (b['price'] as num?)?.toInt() ?? 0;
    final discountApplied = (b['discountApplied'] as num?)?.toInt() ?? 0;
    final targetPrice = discountApplied > 0 
        ? (price * (1 - (discountApplied / 100))).round() 
        : price;
    final remaining = targetPrice - amountPaid;
    var paymentStatus = b['paymentStatus'] as String? ?? (paid ? 'fully_paid' : (amountPaid > 0 ? 'partially_paid' : 'unpaid'));
    if (paymentStatus == 'completed') paymentStatus = 'fully_paid';

    return GestureDetector(
      onTap: () => _showBookingDetail(context, b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: neon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neon.withValues(alpha: 0.25)),
                  ),
                    child: PremiumAvatar(
                      name: (b['trainer'] ?? b['trainerName'] ?? 'Trainer').toString(),
                      customPhotoUrl: b['trainerPhotoUrl']?.toString(),
                      size: 46,
                      borderRadius: 12,
                      isTrainer: true,
                    ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (b['trainer'] ?? b['trainerName'] ?? 'Trainer').toString(),
                        style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        (b['specialty'] ?? 'Personal Training').toString(),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1).toLowerCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: stroke),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(CupertinoIcons.calendar, (b['date'] ?? '').toString()),
                const SizedBox(width: 14),
                _infoChip(CupertinoIcons.clock, (b['time'] ?? '').toString()),
                const SizedBox(width: 14),
                _paymentInfoChip(
                  paymentStatus == 'fully_paid'
                      ? 'Fully Paid'
                      : paymentStatus == 'partially_paid'
                          ? '50% Paid'
                          : 'Unpaid',
                  paymentStatus == 'fully_paid'
                      ? neon
                      : paymentStatus == 'partially_paid'
                          ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFBB33) : const Color(0xFFD97706))
                          : const Color(0xFFFF5C5C),
                ),
              ],
            ),
            if (status == 'confirmed' || status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelBooking(b),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: coral,
                        side: const BorderSide(color: coral),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: paymentStatus == 'fully_paid'
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: neon.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: neon.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: neon,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Paid',
                                  style: TextStyle(
                                    color: neon,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () => _payForSession(b),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: paymentStatus == 'partially_paid' ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFBB33) : const Color(0xFFD97706)) : neon,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              paymentStatus == 'partially_paid'
                                  ? 'Pay Balance (\$$remaining)'
                                  : 'Pay \$$targetPrice',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: paymentStatus == 'partially_paid' ? text : ink,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: muted, size: 13),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: muted, fontSize: 12)),
      ],
    );
  }

  Widget _paymentInfoChip(String label, Color color) {
    return Row(
      children: [
        Icon(CupertinoIcons.creditcard_fill, color: color, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackBookingImage(Map<String, dynamic> b, double size) {
    final name = (b['trainer'] ?? b['trainerName'] ?? 'Trainer').toString();
    return InitialsAvatar(
      name: name,
      size: size,
      fontSize: size * 0.38,
      borderRadius: size <= 46 ? 12 : 14,
    );
  }
}
