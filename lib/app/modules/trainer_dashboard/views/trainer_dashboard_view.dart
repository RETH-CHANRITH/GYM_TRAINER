import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../../../config/glass_ui.dart';
import '../controllers/trainer_dashboard_controller.dart';
import '../../../providers/rx_compat.dart';
import '../../home/views/post_comments_sheet.dart';
import '../../notifications/controllers/notifications_controller.dart';
import '../../../services/post_interaction_service.dart';
import '../../messaging/views/messaging_screen.dart';

class TrainerDashboardView extends ConsumerStatefulWidget {
  final String? autoOpenPostId;
  final String? autoOpenTrainerName;
  final String? initialTab;

  const TrainerDashboardView({
    super.key,
    this.autoOpenPostId,
    this.autoOpenTrainerName,
    this.initialTab,
  });

  @override
  ConsumerState<TrainerDashboardView> createState() => _TrainerDashboardViewState();
}

class _TrainerDashboardViewState extends ConsumerState<TrainerDashboardView> {
  TrainerDashboardController get controller => ref.watch(trainerDashboardProvider);
  Color get kNeon => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _applyTab();
    }
    if (widget.autoOpenPostId != null && widget.autoOpenPostId!.isNotEmpty) {
      _openComments();
    }
  }

  void _applyTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.initialTab?.toLowerCase()) {
        case 'bookings':
          controller.currentTabIndex.value = 1;
          break;
        case 'availability':
          controller.currentTabIndex.value = 2;
          break;
        case 'payouts':
        case 'earnings':
          controller.currentTabIndex.value = 3;
          break;
        case 'messages':
          controller.currentTabIndex.value = 4;
          break;
        case 'posts':
          controller.currentTabIndex.value = 5;
          break;
        case 'studio':
        default:
          controller.currentTabIndex.value = 0;
          break;
      }
    });
  }

  @override
  void didUpdateWidget(covariant TrainerDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      _applyTab();
    }
    if (widget.autoOpenPostId != null &&
        widget.autoOpenPostId!.isNotEmpty &&
        widget.autoOpenPostId != oldWidget.autoOpenPostId) {
      _openComments();
    }
  }

  void _openComments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Switch to Posts tab (index 5)
      controller.currentTabIndex.value = 5;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PostCommentsSheet(
          postId: widget.autoOpenPostId!,
          trainerName: widget.autoOpenTrainerName ?? controller.displayName.value,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsNotifierProvider);
    final unreadCount = notifState.unreadCount;

    final iconList = [
      CupertinoIcons.square_grid_2x2_fill,
      CupertinoIcons.checkmark_seal_fill,
      CupertinoIcons.calendar_today,
      CupertinoIcons.money_dollar_circle_fill,
      CupertinoIcons.chat_bubble_fill,
      CupertinoIcons.photo_on_rectangle,
    ];
    final labelList = [
      'Studio',
      'Bookings',
      'Availability',
      'Payouts',
      'Messages',
      'Posts',
    ];
    final pages = [
      _OverviewTab(controller: controller),
      _BookingsTab(controller: controller),
      _AvailabilityTab(controller: controller),
      _EarningsTab(controller: controller),
      const MessagingScreen(),
      _PostsTab(controller: controller),
    ];

    return Scaffold(
      backgroundColor: kInk,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Obx(
          () => Text(
            'Trainer ${labelList[controller.currentTabIndex.value]}',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(CupertinoIcons.bell, color: Colors.white),
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(
                      color: kCoral,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          Obx(() {
            if (controller.isLoading.value) {
              return Center(
                child: CircularProgressIndicator(color: kNeon),
              );
            }

            return IndexedStack(
              index: controller.currentTabIndex.value,
              children: pages,
            );
          }),
        ],
      ),
      bottomNavigationBar: Obx(
        () => SafeArea(
          top: false,
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF111118),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: iconList
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final icon = entry.value;
                    final isActive = controller.currentTabIndex.value == index;
                    return Expanded(
                      child: InkWell(
                        onTap: () => controller.changeTab(index),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isActive ? kNeon : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: isActive ? kInk : kMuted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                labelList[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: isActive ? kNeon : kMuted,
                                  fontWeight:
                                      isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
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
    ref.watch(trainerDashboardProvider);
    return builder();
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller});

  final TrainerDashboardController controller;

  void _showReviewsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ratings & Reviews',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ReviewsTab(controller: controller),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        InkWell(
          onTap: () => _openEditProfileSheet(context),
          borderRadius: BorderRadius.circular(20),
          child: LiquidTile(
            radius: 20,
            accent: kNeon,
            child: Row(
              children: [
                Obx(() {
                  final photoUrl = controller.profilePhotoUrl.value;
                  return Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kNeon.withValues(alpha: 0.5),
                          ),
                          color: kNeon.withValues(alpha: 0.18),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14.5),
                          child:
                              photoUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 168,
                                    memCacheHeight: 168,
                                    fadeInDuration: const Duration(
                                      milliseconds: 120,
                                    ),
                                    errorWidget:
                                        (_, __, ___) => Icon(
                                          Icons.fitness_center_rounded,
                                          color: kNeon,
                                        ),
                                  )
                                  : Icon(
                                    Icons.fitness_center_rounded,
                                    color: kNeon,
                                  ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: controller.updateProfilePhoto,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: kNeon,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: kInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(
                        () => Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Welcome, ${controller.displayName.value}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            if (controller.totalReviews.value > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${controller.avgRating.value.toStringAsFixed(1)})',
                                style: GoogleFonts.dmSans(
                                  color: kNeon,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        'Tap to open trainer profile and edit your information.',
                        style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _SmallActionButton(
                  label: 'Open Profile',
                  color: kNeon,
                  onTap: () => _openEditProfileSheet(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MiniKpi(
                title: 'Pending',
                valueRx: controller.pendingBookingsCount,
                color: kNeon,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniKpi(
                title: 'Today',
                valueRx: controller.todaySessionsCount,
                color: kSky,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Obx(
                () => _PlainKpi(
                  title: 'Monthly Income',
                  value:
                      '\$${controller.monthlyIncome.value.toStringAsFixed(0)}',
                  color: kLilac,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .where('participantIds', arrayContains: FirebaseAuth.instance.currentUser?.uid ?? '')
                    .snapshots(),
                builder: (context, snapshot) {
                  int totalUnread = 0;
                  if (snapshot.hasData && snapshot.data != null) {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    for (final doc in snapshot.data!.docs) {
                      final data = doc.data();
                      final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
                      totalUnread += (unreadCounts[uid] as num?)?.toInt() ?? 0;
                    }
                  }
                  return GestureDetector(
                    onTap: () => controller.currentTabIndex.value = 4,
                    child: _PlainKpi(
                      title: 'Unread Chats',
                      value: totalUnread.toString(),
                      color: kCoral,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Obx(
                () => _PlainKpi(
                  title: 'Active Days',
                  value: controller.activeAvailabilityDays.toString(),
                  color: kSky,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(
                () => _PlainKpi(
                  title: 'Live Posts',
                  value: controller.activePostsCount.toString(),
                  color: kNeon,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Obx(
                () => InkWell(
                  onTap: () => _showReviewsBottomSheet(context),
                  borderRadius: BorderRadius.circular(16),
                  child: _PlainKpi(
                    title: 'Rating',
                    value: controller.totalReviews.value > 0
                        ? controller.avgRating.value.toStringAsFixed(1)
                        : '0.0',
                    color: kNeon,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(
                () => InkWell(
                  onTap: () => _showReviewsBottomSheet(context),
                  borderRadius: BorderRadius.circular(16),
                  child: _PlainKpi(
                    title: 'Total Reviews',
                    value: controller.totalReviews.value.toString(),
                    color: kSky,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LiquidTile(
          radius: 18,
          accent: kLilac,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trainer Control Center',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Update profile, set working hours, publish content, and keep upcoming sessions under control.',
                style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SmallActionButton(
                      label: 'Availability',
                      color: kSky,
                      onTap: () => controller.changeTab(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallActionButton(
                      label: 'Create Post',
                      color: kNeon,
                      onTap: () => controller.changeTab(5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallActionButton(
                      label: 'Promotions',
                      color: kLilac,
                      onTap: () => _openTrainerPromotionsSheet(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openEditProfileSheet(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _TrainerProfileScreen(controller: controller)));
  }

  void _openTrainerPromotionsSheet(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    final discountController = TextEditingController(text: '20');
    final codeController = TextEditingController(text: 'FIT20');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF111118),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Manage Promotions',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.clear, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create active discount promo codes for your clients to apply during booking checkouts.',
                    style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: discountController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Discount (%)',
                            labelStyle: const TextStyle(color: kMuted, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF17171F),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF2A2A36)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: kNeon),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Promo Code',
                            labelStyle: const TextStyle(color: kMuted, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF17171F),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF2A2A36)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: kNeon),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final discountStr = discountController.text.trim();
                          final discount = int.tryParse(discountStr) ?? 0;
                          if (discount > 0 && discount <= 100) {
                            final random = Random();
                            const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                            final suffix = List.generate(3, (index) => chars[random.nextInt(chars.length)]).join();
                            
                            final trainerPrefix = controller.displayName.value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                            final prefix = trainerPrefix.isNotEmpty
                                ? (trainerPrefix.length > 5 ? trainerPrefix.substring(0, 5) : trainerPrefix)
                                : 'FIT';

                            setModalState(() {
                              codeController.text = '$prefix$discount$suffix';
                            });
                          } else {
                            showSnackbar('Invalid Discount', 'Please enter a valid discount number (1-100) first.');
                          }
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.sparkles, color: kNeon, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Auto-Generate Code',
                                style: GoogleFonts.dmSans(
                                  color: kNeon,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: kNeon,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final code = codeController.text.trim().toUpperCase();
                        final discountStr = discountController.text.trim();
                        final discount = int.tryParse(discountStr);
                        if (discount == null || discount <= 0 || discount > 100) {
                          showSnackbar('Invalid Discount', 'Please enter a valid discount percentage (1-100).');
                          return;
                        }
                        if (code.isEmpty) {
                          showSnackbar('Invalid Code', 'Please enter or generate a promo code.');
                          return;
                        }
                        await controller.addPromoCode(code, discount);
                        setModalState(() {
                          discountController.text = '20';
                          codeController.text = 'FIT20';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add Promotion Code',
                        style: GoogleFonts.dmSans(
                          color: kInk,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your Promo Codes',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Obx(() {
                      final list = controller.promotions;
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            'No promotions created yet.',
                            style: GoogleFonts.dmSans(color: kMuted, fontSize: 13),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final code = (item['code'] ?? '').toString();
                          final discount = (item['discount'] ?? 0).toString();
                          final id = (item['id'] ?? '').toString();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF17171F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2A2A36)),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await Clipboard.setData(ClipboardData(text: code));
                                    showSnackbar('Copied', 'Promo code "$code" copied to clipboard.');
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.tag_solid, color: kLilac, size: 16),
                                      const SizedBox(width: 10),
                                      Text(
                                        code,
                                        style: GoogleFonts.dmSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                          decorationStyle: TextDecorationStyle.dotted,
                                          decorationColor: kLilac,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(CupertinoIcons.doc_on_doc, color: kMuted, size: 12),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$discount% Off',
                                  style: GoogleFonts.dmSans(
                                    color: kNeon,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () => controller.deletePromoCode(id),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: const Icon(CupertinoIcons.trash, color: kCoral, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({required this.controller});

  final TrainerDashboardController controller;

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  Color get kNeon => Theme.of(context).colorScheme.primary;
  int _selectedSubTab = 0; // 0 = Pending, 1 = Confirmed, 2 = History

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final requests = widget.controller.bookingRequests;
      final upcoming = widget.controller.confirmedUpcomingBookings;
      final history = widget.controller.pastBookingsHistory;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _buildSubTabs(),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final list = _selectedSubTab == 0
                    ? requests
                    : _selectedSubTab == 1
                        ? upcoming
                        : history;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedSubTab == 0
                          ? 'No pending client requests.'
                          : _selectedSubTab == 1
                              ? 'No confirmed sessions yet.'
                              : 'No past session history.',
                      style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildBookingCard(list[index]),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSubTabs() {
    final tabs = ['Pending', 'Confirmed', 'History'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration( 
        color: const Color(0xFF17171F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _selectedSubTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSubTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? kNeon : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: active ? kInk : kMuted,
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

  Widget _buildBookingCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString();
    final fallbackClientName = (item['clientName'] ?? item['userName'] ?? item['client'] ?? 'Client').toString();
    final fallbackClientPhoto = (item['clientPhotoUrl'] ?? item['userPhotoUrl'] ?? '').toString();
    final userId = (item['userId'] ?? '').toString();

    if (userId.isEmpty) {
      final resolvedPhoto = _getPhotoUrl(fallbackClientPhoto, fallbackClientName, userId, item, null);
      return _buildBookingCardTile(item, fallbackClientName, resolvedPhoto, status, userId);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        String name = fallbackClientName;
        String rawPhoto = fallbackClientPhoto;
        Map<String, dynamic> userData = {};

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() ?? {};
          userData = data;
          name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? fallbackClientName).toString();
          rawPhoto = (data['photoUrl'] ?? data['avatarUrl'] ?? data['profileImage'] ?? fallbackClientPhoto).toString();
        }

        final resolvedPhoto = _getPhotoUrl(rawPhoto, name, userId, item, userData);
        return _buildBookingCardTile(item, name, resolvedPhoto, status, userId);
      },
    );
  }

  String _getPhotoUrl(String rawPhoto, String name, String userId, Map<String, dynamic> item, Map<String, dynamic>? userData) {
    final photo = rawPhoto.trim();
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return photo;
    }

    // Deterministic fallback seed based on user name/id hash
    final seed = (userId.isNotEmpty ? userId : name).hashCode.abs() % 100;
    
    // Determine gender dynamically from database profile or name heuristic
    final genderVal = (userData?['gender'] ?? '').toString().toLowerCase();
    String gender;
    if (genderVal.contains('female') || genderVal.contains('women')) {
      gender = 'women';
    } else if (genderVal.contains('male') || genderVal.contains('men')) {
      gender = 'men';
    } else {
      final nameLower = name.toLowerCase();
      if (nameLower.contains('kaiya') ||
          nameLower.contains('kaya') ||
          nameLower.contains('kiaya') ||
          nameLower.contains('lisa') ||
          nameLower.contains('sara') ||
          nameLower.contains('anna') ||
          nameLower.contains('maria') ||
          nameLower.contains('emma') ||
          nameLower.contains('sofia') ||
          nameLower.contains('julia') ||
          nameLower.contains('lucy') ||
          nameLower.contains('charlotte')) {
        gender = 'women';
      } else {
        gender = seed % 2 == 0 ? 'men' : 'women';
      }
    }
    
    // Check if rawPhoto is a number (mock portrait index)
    if (photo.isNotEmpty) {
      final parsed = int.tryParse(photo);
      if (parsed != null) {
        return 'https://randomuser.me/api/portraits/$gender/$parsed.jpg';
      }
    }

    // Check portrait index in user data or booking item
    final portraitVal = (userData?['portrait'] ?? item['portrait']);
    if (portraitVal != null) {
      final parsed = int.tryParse(portraitVal.toString());
      if (parsed != null) {
        return 'https://randomuser.me/api/portraits/$gender/$parsed.jpg';
      }
    }
    
    return 'https://randomuser.me/api/portraits/$gender/$seed.jpg';
  }

  Widget _buildBookingCardTile(Map<String, dynamic> item, String clientName, String clientPhoto, String status, String userId) {
    final paid = item['paid'] == true;
    final amountPaid = (item['amountPaid'] as num?)?.toInt() ?? 0;
    var paymentStatus = item['paymentStatus'] as String? ?? (paid ? 'fully_paid' : (amountPaid > 0 ? 'partially_paid' : 'unpaid'));
    if (paymentStatus == 'completed') paymentStatus = 'fully_paid';

    final Color paymentColor;
    final String paymentText;
    if (paymentStatus == 'fully_paid') {
      paymentColor = kNeon;
      paymentText = 'Fully Paid';
    } else if (paymentStatus == 'partially_paid') {
      paymentColor = const Color(0xFFFFBB33); // Gold
      paymentText = '50% Paid (\$$amountPaid)';
    } else {
      paymentColor = kCoral; // Unpaid in red
      paymentText = 'Unpaid';
    }

    return LiquidTile(
      radius: 16,
      accent: kSky,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.5),
              child: clientPhoto.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: clientPhoto,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                        CupertinoIcons.person_fill,
                        color: kMuted,
                        size: 22,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.person_fill,
                      color: kMuted,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        clientName,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (userId.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          context.push('/message-screen', extra: {
                            'name': clientName,
                            'otherId': userId,
                            'photoUrl': clientPhoto,
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kNeon.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kNeon.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.chat_bubble_fill, color: kNeon, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Message',
                                style: GoogleFonts.dmSans(
                                  color: kNeon,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['sessionType'] ?? item['specialty'] ?? item['type'] ?? 'Session'} • ${item['date'] ?? ''} ${item['time'] ?? ''}',
                  style: GoogleFonts.dmSans(color: kMuted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusChip(status: status),
                    const SizedBox(width: 8),
                    _PaymentStatusChip(text: paymentText, color: paymentColor),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending' || status == 'requested') ...[
                      _SmallActionButton(
                        label: 'Accept',
                        color: kNeon,
                        onTap: () => widget.controller.acceptBooking(item),
                      ),
                      const SizedBox(width: 8),
                      _SmallActionButton(
                        label: 'Reject',
                        color: kCoral,
                        onTap: () => widget.controller.rejectBooking(item),
                      ),
                    ] else if (status == 'confirmed' || status == 'accepted') ...[
                      _SmallActionButton(
                        label: 'Complete',
                        color: kNeon,
                        onTap: () => widget.controller.completeBooking(item),
                      ),
                      const SizedBox(width: 8),
                      _SmallActionButton(
                        label: 'Cancel',
                        color: kCoral,
                        onTap: () => widget.controller.cancelBooking(item),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Text(subtitle, style: GoogleFonts.dmSans(color: kMuted, fontSize: 11)),
      ],
    );
  }
}

class _AvailabilityTab extends StatelessWidget {
  const _AvailabilityTab({required this.controller});

  final TrainerDashboardController controller;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    return Obx(() {
      final _ = controller.availability.length;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          LiquidTile(
            radius: 16,
            accent: kNeon,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Set days and working times',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${controller.activeAvailabilityDays} active',
                  style: GoogleFonts.dmSans(
                    color: kNeon,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: _days.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              // Make tiles taller to avoid bottom overflow.
              // (childAspectRatio = width / height)
              childAspectRatio: 0.82,
            ),
            itemBuilder: (_, index) {
              final day = _days[index];
              final value =
                  controller.availability[day] ??
                  {
                    'enabled': false,
                    'date': '',
                    'start': '09:00',
                    'end': '18:00',
                  };
              final enabled = value['enabled'] == true;
              final date = (value['date'] ?? '').toString();
              final start = (value['start'] ?? '09:00').toString();
              final end = (value['end'] ?? '18:00').toString();

              return LiquidTile(
                radius: 16,
                accent: enabled ? kNeon : kLilac,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          day,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: enabled,
                          activeThumbColor: kNeon,
                          onChanged:
                              (v) => controller.updateDayAvailability(
                                day: day,
                                enabled: v,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      enabled ? 'Available' : 'Off day',
                      style: GoogleFonts.dmSans(
                        color: enabled ? kNeon : kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _dateButton(
                      value:
                          date.isNotEmpty
                              ? _formatDateDisplay(date)
                              : 'Set day/month',
                      enabled: enabled,
                      onTap:
                          enabled
                              ? () => _pickDate(
                                context: context,
                                day: day,
                                current: value,
                                enabled: enabled,
                              )
                              : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _timeButton(
                            label: 'Start',
                            value: start,
                            enabled: enabled,
                            onTap:
                                enabled
                                    ? () => _pickSingleTime(
                                      context: context,
                                      day: day,
                                      current: value,
                                      enabled: enabled,
                                      editStart: true,
                                    )
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _timeButton(
                            label: 'End',
                            value: end,
                            enabled: enabled,
                            onTap:
                                enabled
                                    ? () => _pickSingleTime(
                                      context: context,
                                      day: day,
                                      current: value,
                                      enabled: enabled,
                                      editStart: false,
                                    )
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    });
  }

  Future<void> _pickSingleTime({
    required BuildContext context,
    required String day,
    required Map<String, dynamic> current,
    required bool enabled,
    required bool editStart,
  }) async {
    final startValue = current['start']?.toString() ?? '09:00';
    final endValue = current['end']?.toString() ?? '18:00';
    final dateValue = current['date']?.toString() ?? '';
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(editStart ? startValue : endValue),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return;

    final newStart = editStart ? _formatTime(picked) : startValue;
    final newEnd = editStart ? endValue : _formatTime(picked);

    await controller.updateDayAvailability(
      day: day,
      enabled: enabled,
      date: dateValue,
      start: newStart,
      end: newEnd,
    );
  }

  Future<void> _pickDate({
    required BuildContext context,
    required String day,
    required Map<String, dynamic> current,
    required bool enabled,
  }) async {
    final now = DateTime.now();
    final currentDate = _parseDate(current['date']?.toString() ?? '') ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (selected == null) return;

    final startValue = current['start']?.toString() ?? '09:00';
    final endValue = current['end']?.toString() ?? '18:00';
    await controller.updateDayAvailability(
      day: day,
      enabled: enabled,
      date: _formatDateIso(selected),
      start: startValue,
      end: endValue,
    );
  }

  Widget _dateButton({
    required String value,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color:
              enabled
                  ? kLilac.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                enabled
                    ? kLilac.withValues(alpha: 0.38)
                    : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: kMuted, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: enabled ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeButton({
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color:
              enabled
                  ? kSky.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                enabled
                    ? kSky.withValues(alpha: 0.38)
                    : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: GoogleFonts.dmSans(
                color: enabled ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    final hour = int.tryParse(parts.firstOrNull ?? '') ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _formatDateDisplay(String raw) {
    final parsed = _parseDate(raw);
    if (parsed == null) return 'Set day/month';
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}

class _EarningsTab extends StatelessWidget {
  const _EarningsTab({required this.controller});

  final TrainerDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Income Summary Row ────────────────────────────────────────────
        Obx(() => Row(
          children: [
            Expanded(
              child: _PlainKpi(
                title: 'This Month',
                value: '\$${controller.monthlyIncome.value.toStringAsFixed(2)}',
                color: kSky,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PlainKpi(
                title: 'Total Earned',
                value: '\$${controller.totalIncome.value.toStringAsFixed(2)}',
                color: kLilac,
              ),
            ),
          ],
        )),
        const SizedBox(height: 10),
        // ── Available Balance Card ─────────────────────────────────────────
        Obx(() {
          final balance = controller.availableBalance;
          return LiquidTile(
            radius: 16,
            accent: kLilac,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${balance.toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        color: kLilac,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      'Total earned minus requested payouts',
                      style: GoogleFonts.dmSans(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (balance > 0)
                  _SmallActionButton(
                    label: 'Request All',
                    color: kLilac,
                    onTap: () {
                      controller.payoutAmountController.text =
                          balance.toStringAsFixed(2);
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        LiquidTile(
          radius: 16,
          accent: kNeon,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request Payout',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Obx(() => Text(
                'Enter amount to withdraw (max \$${controller.availableBalance.toStringAsFixed(2)})',
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              )),
              const SizedBox(height: 8),
              TextField(
                controller: controller.payoutAmountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: glassFieldDecoration(
                  hint: 'Amount (USD)',
                  icon: Icons.attach_money_rounded,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _SmallActionButton(
                  label: 'Submit Request',
                  color: kNeon,
                  onTap: controller.requestPayout,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Transaction History',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final history = controller.earningsHistory;
          if (history.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'No transactions yet',
                  style: GoogleFonts.dmSans(color: Colors.white70),
                ),
              ),
            );
          }
          return Column(
            children: history.map((item) {
              final type = item['type'] as String;
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final amount = item['amount'] as double;
              final date = item['dateTime'] as DateTime;
              final status = item['status'] as String;

              Color accent;
              IconData icon;
              Color textCol;
              String amountText;

              if (type == 'payment') {
                accent = kNeon;
                icon = Icons.arrow_upward_rounded;
                textCol = kNeon;
                amountText = '+\$${amount.toStringAsFixed(2)}';
              } else if (type == 'refund') {
                accent = kCoral;
                icon = Icons.undo_rounded;
                textCol = kCoral;
                amountText = '-\$${(-amount).toStringAsFixed(2)}';
              } else {
                accent = kLilac;
                icon = Icons.account_balance_wallet_rounded;
                textCol = Colors.white;
                amountText = '-\$${(-amount).toStringAsFixed(2)}';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LiquidTile(
                  radius: 16,
                  accent: accent,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: GoogleFonts.dmSans(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            amountText,
                            style: GoogleFonts.dmSans(
                              color: textCol,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (type == 'payout')
                            _StatusChip(status: status)
                          else
                            Text(
                              _formatHistoryDate(date),
                              style: GoogleFonts.dmSans(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  String _formatHistoryDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Yesterday';
    }
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.controller});

  final TrainerDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    return Obx(() {
      final _ = controller.reviews.length;
      final list = controller.reviews.toList(growable: false);
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PlainKpi(
            title: 'Average Rating',
            value: controller.avgRating.value.toStringAsFixed(1),
            color: kCoral,
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'No reviews yet',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            ...list.take(20).map((item) {
              final rating = (item['rating'] ?? 0).toString();
              final comment =
                  (item['comment'] ?? 'No written feedback').toString();
              final reviewerName = _pickString(item, const [
                'reviewerName',
                'userName',
                'clientName',
                'authorName',
                'name',
              ], fallback: 'User');
              final reviewerPhoto = _pickString(item, const [
                'reviewerPhotoUrl',
                'userPhotoUrl',
                'clientPhotoUrl',
                'authorPhotoUrl',
                'photoUrl',
                'avatarUrl',
              ]);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LiquidTile(
                  radius: 14,
                  accent: kSky,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Rate: $rating',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.star_rounded,
                            color: kNeon,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Comment:',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment,
                        style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _openReviewerProfile(context, item),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: kSky.withValues(alpha: 0.16),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child:
                                      reviewerPhoto.isNotEmpty
                                          ? CachedNetworkImage(
                                            imageUrl: reviewerPhoto,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 108,
                                            memCacheHeight: 108,
                                            errorWidget:
                                                (_, __, ___) => const Icon(
                                                  Icons.person_rounded,
                                                  color: kSky,
                                                  size: 20,
                                                ),
                                          )
                                          : const Icon(
                                            Icons.person_rounded,
                                            color: kSky,
                                            size: 20,
                                          ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reviewerName,
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Tap to view user profile',
                                      style: GoogleFonts.dmSans(
                                        color: kMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: kMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      );
    });
  }

  String _pickString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = (source[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  Future<void> _openReviewerProfile(BuildContext context, Map<String, dynamic> review) async {
    final data = await controller.loadReviewerProfile(review);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => _UserProfileInfoScreen(data: data)));
  }
}

class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.controller});

  final TrainerDashboardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kNeon = Theme.of(context).colorScheme.primary;
    return Obx(() {
      final list = controller.recentPosts;
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.isEmpty ? 2 : list.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return LiquidTile(
              radius: 18,
              accent: kNeon,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trainer Posts',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share workouts, tips, progress, and gym announcements.',
                          style: GoogleFonts.dmSans(
                            color: kMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SmallActionButton(
                    label: 'Create Post',
                    color: kNeon,
                    onTap: () => _openCreatePostSheet(context),
                  ),
                ],
              ),
            );
          }

          if (list.isEmpty) {
            return const _EmptyPanel(
              message: 'No posts yet. Create your first trainer post.',
            );
          }

          final post = list[index - 1];
          return _buildPostCard(context, ref, post);
        },
      );
    });
  }

  Widget _buildPostCard(BuildContext context, WidgetRef ref, Map<String, dynamic> post) {
    final title = (post['title'] ?? '').toString();
    final caption = (post['caption'] ?? '').toString();
    final category = (post['category'] ?? 'Workout').toString();
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final likes = (post['likesCount'] ?? 0).toString();
    final comments = (post['commentsCount'] ?? 0).toString();
    final isActive = post['isActive'] != false;
    final tags =
        (post['tags'] is List)
            ? (post['tags'] as List).map((e) => e.toString()).toList()
            : <String>[];

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final likedBy = List<String>.from(post['likedBy'] ?? <dynamic>[]);
    final isLiked = currentUid != null && likedBy.contains(currentUid);

    return LiquidTile(
      radius: 16,
      accent: isActive ? kSky : kCoral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(status: category),
              const SizedBox(width: 6),
              _StatusChip(status: isActive ? 'Live' : 'Archived'),
              const Spacer(),
              Text(
                _formatPostDate(post['createdAt'] ?? post['createdAtClient']),
                style: GoogleFonts.dmSans(color: kMuted, fontSize: 11),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              style: GoogleFonts.dmSans(
                color: const Color(0xFFE6E8ED),
                fontSize: 13,
              ),
            ),
          ],
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 960,
                    memCacheHeight: 540,
                    fadeInDuration: const Duration(milliseconds: 120),
                    errorWidget:
                        (_, __, ___) => Container(
                          color: Colors.black26,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white70,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final postId = (post['id'] ?? post['postId'] ?? '').toString();
                  if (postId.isNotEmpty) {
                    ref.read(postInteractionServiceProvider).toggleLike(postId);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        color: isLiked ? kCoral : kMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        likes,
                        style: GoogleFonts.dmSans(
                          color: isLiked ? kCoral : kMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final postId = (post['id'] ?? post['postId'] ?? '').toString();
                  if (postId.isNotEmpty) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => PostCommentsSheet(
                        postId: postId,
                        trainerName: controller.displayName.value,
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.chat_bubble, color: kSky, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        comments,
                        style: GoogleFonts.dmSans(
                          color: kMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  tags.take(8).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kLilac.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: kLilac.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: GoogleFonts.dmSans(
                          color: kLilac,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: _SmallActionButton(
                    label: isActive ? 'Archive' : 'Activate',
                    color: isActive ? kSky : kNeon,
                    onTap:
                        controller.isActionLoading.value
                            ? null
                            : () => controller.togglePostVisibility(post),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallActionButton(
                    label: 'Delete',
                    color: kCoral,
                    onTap:
                        controller.isActionLoading.value
                            ? null
                            : () => controller.deletePost(post),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCreatePostSheet(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _CreateTrainerPostScreen(controller: controller)));
  }

  String _formatPostDate(dynamic raw) {
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw != null && raw.runtimeType.toString() == 'Timestamp') {
      dt = (raw as dynamic).toDate() as DateTime?;
    }

    if (dt == null) return 'Now';

    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}

class _CreateTrainerPostScreen extends StatefulWidget {
  const _CreateTrainerPostScreen({required this.controller});

  final TrainerDashboardController controller;

  @override
  State<_CreateTrainerPostScreen> createState() =>
      _CreateTrainerPostScreenState();
}

class _CreateTrainerPostScreenState extends State<_CreateTrainerPostScreen> {
  Color get kNeon => Theme.of(context).colorScheme.primary;
  late final TextEditingController _titleController;
  late final TextEditingController _captionController;
  late final TextEditingController _tagsController;
  late DateTime _selectedDate;
  late String _selectedCategory;
  final Set<String> _selectedTags = <String>{};

  String? _titleError;
  String? _detailsError;
  String? _tagsError;

  static const int _maxTitleLength = 80;
  static const int _maxDetailsLength = 600;
  static const int _maxTagCount = 12;

  static const List<String> _suggestedTags = [
    'fat loss',
    'muscle gain',
    'mobility',
    'beginner',
    'advanced',
    'hiit',
    'strength',
    'yoga',
    'nutrition',
    'motivation',
  ];

  TrainerDashboardController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: controller.postTitleController.text,
    );
    _captionController = TextEditingController(
      text: controller.postCaptionController.text,
    );
    _tagsController = TextEditingController(
      text: controller.postTagsController.text,
    );
    _selectedCategory = controller.selectedPostCategory.value;
    _selectedDate = DateTime.now();
    _selectedTags.addAll(_parseCsv(controller.postTagsController.text));

    _titleController.addListener(_validateLive);
    _captionController.addListener(_validateLive);
    _tagsController.addListener(() {
      _syncSelectedFromInput();
      _validateLive();
    });
    _validateLive();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: kInk,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Trainer Post',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 4, 16, 18 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiquidTile(
                    radius: 16,
                    accent: kNeon,
                    child: Text(
                      'Professional post setup: pick date, upload image, add title and detailed content.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    maxLength: _maxTitleLength,
                    style: const TextStyle(color: Colors.white),
                    decoration: glassFieldDecoration(
                      hint: 'Post title',
                      icon: Icons.title_rounded,
                    ),
                  ),
                  if (_titleError != null) _errorText(_titleError!),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _captionController,
                    maxLength: _maxDetailsLength,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: glassFieldDecoration(
                      hint: 'Details / content',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  if (_detailsError != null) _errorText(_detailsError!),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _tagsController,
                    style: const TextStyle(color: Colors.white),
                    decoration: glassFieldDecoration(
                      hint: 'Custom tags (comma separated)',
                      icon: Icons.tag_rounded,
                    ),
                  ),
                  if (_tagsError != null) _errorText(_tagsError!),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Tag Choices',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_composeTagSet().length} selected',
                        style: GoogleFonts.dmSans(
                          color: kMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _suggestedTags.map((tag) {
                          final selected = _selectedTags.contains(tag);
                          return FilterChip(
                            selected: selected,
                            onSelected: (_) {
                              _toggleSuggestedTag(tag);
                            },
                            label: Text(
                              '#$tag',
                              style: GoogleFonts.dmSans(
                                color: selected ? kInk : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            selectedColor: kNeon,
                            backgroundColor: const Color(0xFF1B1D27),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color:
                                    selected
                                        ? kNeon
                                        : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            showCheckmark: false,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    dropdownColor: const Color(0xFF191923),
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    decoration: glassFieldDecoration(
                      hint: 'Post category',
                      icon: Icons.category_rounded,
                    ),
                    items:
                        TrainerDashboardController.postCategories
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedCategory = v;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Post Date',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _datePartCard(
                          'Day',
                          _selectedDate.day.toString().padLeft(2, '0'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _datePartCard(
                          'Month',
                          _selectedDate.month.toString().padLeft(2, '0'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _datePartCard(
                          'Year',
                          _selectedDate.year.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SmallActionButton(
                    label: 'Pick Date',
                    color: kLilac,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Image Box',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Recommended: 1200 x 675',
                        style: GoogleFonts.dmSans(color: kMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Container(
                      width: double.infinity,
                      height: 190,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D29),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kSky.withValues(alpha: 0.35)),
                      ),
                      child:
                          controller.draftPostImageUrl.value.isNotEmpty
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: controller.draftPostImageUrl.value,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 1200,
                                  memCacheHeight: 675,
                                  fadeInDuration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  errorWidget:
                                      (_, __, ___) => const Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          color: Colors.white70,
                                        ),
                                      ),
                                ),
                              )
                              : Center(
                                child: Text(
                                  'No image selected yet.',
                                  style: GoogleFonts.dmSans(
                                    color: kMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: _SmallActionButton(
                            label:
                                controller.isUploadingPostImage.value
                                    ? 'Uploading...'
                                    : 'Insert Image',
                            color: kSky,
                            onTap:
                                controller.isUploadingPostImage.value
                                    ? null
                                    : () async {
                                      controller.postTitleController.text =
                                          _titleController.text;
                                      controller.postCaptionController.text =
                                          _captionController.text;
                                      controller.postTagsController.text =
                                          _composeTagsString();
                                      await controller.pickAndUploadPostImage();
                                    },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SmallActionButton(
                            label:
                                controller.isCreatingPost.value
                                    ? 'Publishing...'
                                    : 'Publish Post',
                            color: kNeon,
                            onTap:
                                controller.isCreatingPost.value
                                    ? null
                                    : _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePartCard(String label, String value) {
    return LiquidTile(
      radius: 12,
      accent: kLilac,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorText(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4),
      child: Text(
        message,
        style: GoogleFonts.dmSans(
          color: kCoral,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDate = selected;
    });
  }

  Future<void> _submit() async {
    if (!_validateBeforeSubmit()) {
      showSnackbar('Fix form', 'Please resolve highlighted fields first.');
      return;
    }

    final ok = await controller.createPostDraft(
      title: _titleController.text,
      caption: _captionController.text,
      tags: _composeTagsString(),
      category: _selectedCategory,
      selectedDate: _selectedDate,
    );
    if (!ok || !mounted) return;
    context.pop();
  }

  void _validateLive() {
    final title = _titleController.text.trim();
    final details = _captionController.text.trim();
    final tags = _composeTagSet();

    _titleError =
        title.isEmpty
            ? 'Title is required.'
            : (title.length > _maxTitleLength
                ? 'Title must be <= $_maxTitleLength characters.'
                : null);

    _detailsError =
        details.isEmpty
            ? 'Details are required.'
            : (details.length > _maxDetailsLength
                ? 'Details must be <= $_maxDetailsLength characters.'
                : null);

    _tagsError =
        tags.length > _maxTagCount
            ? 'Use up to $_maxTagCount tags only.'
            : null;

    if (mounted) {
      setState(() {});
    }
  }

  bool _validateBeforeSubmit() {
    _validateLive();
    return _titleError == null && _detailsError == null && _tagsError == null;
  }

  String _composeTagsString() {
    return _composeTagSet().join(', ');
  }

  Set<String> _composeTagSet() {
    return <String>{..._selectedTags, ..._parseCsv(_tagsController.text)};
  }

  void _toggleSuggestedTag(String tag) {
    final current = _composeTagSet();
    if (current.contains(tag)) {
      current.remove(tag);
    } else {
      current.add(tag);
    }

    _tagsController.text = current.join(', ');
    _tagsController.selection = TextSelection.fromPosition(
      TextPosition(offset: _tagsController.text.length),
    );
    _syncSelectedFromInput();
    _validateLive();
  }

  void _syncSelectedFromInput() {
    final fromInput = _parseCsv(_tagsController.text).toSet();
    _selectedTags
      ..clear()
      ..addAll(_suggestedTags.where(fromInput.contains));
    if (mounted) {
      setState(() {});
    }
  }

  List<String> _parseCsv(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class _TrainerProfileScreen extends StatefulWidget {
  const _TrainerProfileScreen({required this.controller});

  final TrainerDashboardController controller;

  @override
  State<_TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<_TrainerProfileScreen> {
  Color get kNeon => Theme.of(context).colorScheme.primary;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _bioController;
  late final TextEditingController _specializationController;
  late final TextEditingController _languagesController;
  late final TextEditingController _locationsController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _experienceController;
  final List<String> _languageOptions = const ['English', 'Khmer'];
  final Set<String> _selectedLanguages = <String>{};
  bool _isEditing = false;

  TrainerDashboardController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: controller.displayNameController.text,
    );
    _priceController = TextEditingController(
      text: controller.sessionPriceController.text,
    );
    _bioController = TextEditingController(text: controller.bioController.text);
    _specializationController = TextEditingController(
      text: controller.specializationController.text,
    );
    _languagesController = TextEditingController(
      text: controller.languagesController.text,
    );
    _selectedLanguages.addAll(
      _languagesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .where(_languageOptions.contains),
    );
    _locationsController = TextEditingController(
      text: controller.sessionLocationController.text,
    );
    _ageController = TextEditingController(
      text: controller.ageController.text,
    );
    _heightController = TextEditingController(
      text: controller.heightController.text,
    );
    _experienceController = TextEditingController(
      text: controller.experienceYearsController.text,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _bioController.dispose();
    _specializationController.dispose();
    _languagesController.dispose();
    _locationsController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    final email =
        (controller.profile['email'] ??
                controller.profile['trainerEmail'] ??
                controller.profile['contactEmail'] ??
                '')
            .toString();

    return Scaffold(
      backgroundColor: kInk,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _topBackButton(),
        ),
        title: Text(
          'Trainer Profile',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: isCompact ? 18 : 20,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: _bottomAction(
                  label: _isEditing ? 'Editing' : 'Edit',
                  color: kSky,
                  neonStyle: false,
                  onTap:
                      _isEditing
                          ? null
                          : () => setState(() => _isEditing = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bottomAction(
                  label: 'Save',
                  color: kNeon,
                  neonStyle: true,
                  onTap: !_isEditing ? null : _saveProfile,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _summaryHeroCard(email),
              const SizedBox(height: 14),
              _infoCard(
                icon: Icons.person_rounded,
                color: kSky,
                title: 'Full Name',
                controller: _nameController,
                hint: 'Trainer name',
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.cake_rounded,
                color: kNeon,
                title: 'Age',
                controller: _ageController,
                hint: 'Age (e.g. 29)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.height_rounded,
                color: kSky,
                title: 'Height (cm)',
                controller: _heightController,
                hint: 'Height in cm (e.g. 170)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.work_history_rounded,
                color: kLilac,
                title: 'Years of Experience',
                controller: _experienceController,
                hint: 'Experience in years (e.g. 5)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.attach_money_rounded,
                color: kCoral,
                title: 'Session Price',
                controller: _priceController,
                hint: 'Session price (USD)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.description_rounded,
                color: kSky,
                title: 'Bio',
                controller: _bioController,
                hint: 'Short trainer bio',
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.fitness_center_rounded,
                color: kNeon,
                title: 'Specializations',
                controller: _specializationController,
                hint: 'Specializations (comma separated)',
              ),
              const SizedBox(height: 10),
              _languageInfoCard(),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.location_on_outlined,
                color: kCoral,
                title: 'Session Locations',
                controller: _locationsController,
                hint: 'Session locations (gym, online, home)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBackButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.pop(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Icon(CupertinoIcons.back, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _summaryHeroCard(String email) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    final avatarSize = isCompact ? 84.0 : 96.0;
    final nameSize = isCompact ? 26.0 : 32.0;
    return LiquidTile(
      radius: 24,
      accent: kLilac,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Obx(() {
                final photoUrl = controller.profilePhotoUrl.value;
                return Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [kNeon, kSky]),
                    borderRadius: BorderRadius.circular(48),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45),
                    child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child:
                          photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: (avatarSize * 3).round(),
                                memCacheHeight: (avatarSize * 3).round(),
                                errorWidget:
                                    (_, __, ___) => Container(
                                      color: const Color(0xFF1E1E28),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: kMuted,
                                        size: 30,
                                      ),
                                    ),
                              )
                              : Container(
                                color: const Color(0xFF1E1E28),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: kMuted,
                                  size: 30,
                                ),
                              ),
                    ),
                  ),
                );
              }),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [kNeon, kSky]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF17171F),
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isEditing ? controller.updateProfilePhoto : null,
                    child: Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: _isEditing ? kInk : kMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(
            () => Text(
              controller.displayName.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: nameSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email.trim().isEmpty ? 'No email linked' : email.trim(),
            style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            _isEditing
                ? 'Update your information, then press Continue'
                : 'Tap Edit to update your information',
            style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String title,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    return LiquidTile(
      radius: 20,
      accent: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                  child:
                      _isEditing
                          ? TextField(
                            key: const ValueKey('edit'),
                            controller: controller,
                            keyboardType: keyboardType,
                            maxLines: maxLines,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: isCompact ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: glassFieldDecoration(
                              hint: hint,
                              icon: icon,
                            ),
                          )
                          : Text(
                            key: const ValueKey('view'),
                            controller.text.trim().isEmpty
                                ? '-'
                                : controller.text.trim(),
                            maxLines: maxLines,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: isCompact ? 15 : 16,
                            ),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageInfoCard() {
    final displayLanguages =
        _selectedLanguages.isNotEmpty
            ? _selectedLanguages.join(', ')
            : (_languagesController.text.trim().isEmpty
                ? '-'
                : _languagesController.text.trim());

    return LiquidTile(
      radius: 20,
      accent: kLilac,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kLilac.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.language_rounded, color: kLilac, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Languages',
                  style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                if (_isEditing)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _languageOptions
                        .map(
                          (lang) => FilterChip(
                            label: Text(
                              lang,
                              style: GoogleFonts.dmSans(
                                color:
                                    _selectedLanguages.contains(lang)
                                        ? kInk
                                        : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selected: _selectedLanguages.contains(lang),
                            onSelected: (_) => _toggleLanguage(lang),
                            selectedColor: kNeon,
                            checkmarkColor: kInk,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.06,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  )
                else
                  Text(
                    displayLanguages,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomAction({
    required String label,
    required Color color,
    required bool neonStyle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient:
                neonStyle
                    ? LinearGradient(colors: [kNeon, const Color(0xFFD6F95C)])
                    : LinearGradient(
                      colors: [
                        kSky.withValues(alpha: 0.25),
                        kSky.withValues(alpha: 0.10),
                      ],
                    ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  neonStyle
                      ? kNeon.withValues(alpha: 0.85)
                      : kSky.withValues(alpha: 0.45),
            ),
            boxShadow:
                neonStyle
                    ? [
                      BoxShadow(
                        color: kNeon.withValues(alpha: 0.38),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                    : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: neonStyle ? kInk : kSky,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    _languagesController.text = _selectedLanguages.join(', ');
    await controller.saveProfileDraft(
      name: _nameController.text,
      sessionPrice: _priceController.text,
      bio: _bioController.text,
      specializations: _specializationController.text,
      languages: _languagesController.text,
      locations: _locationsController.text,
      age: _ageController.text,
      height: _heightController.text,
      experienceYears: _experienceController.text,
    );
    if (mounted) {
      setState(() => _isEditing = false);
    }
  }

  void _toggleLanguage(String lang) {
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        _selectedLanguages.remove(lang);
      } else {
        _selectedLanguages.add(lang);
      }
      _languagesController.text = _selectedLanguages.join(', ');
    });
  }
}

class _UserProfileInfoScreen extends StatelessWidget {
  const _UserProfileInfoScreen({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    final name = _pickString([
      data['reviewerName'],
      data['name'],
      data['fullName'],
      data['displayName'],
    ], fallback: 'User');
    final photoUrl = _pickString([
      data['reviewerPhotoUrl'],
      data['photoUrl'],
      data['avatarUrl'],
      data['profileImage'],
    ]);
    final rating = (data['rating'] ?? '-').toString();
    final comment = _pickString([
      data['comment'],
      data['feedback'],
    ], fallback: 'No comment');
    final email = _pickString([data['email']]);
    final gender = _pickString([data['gender']]);
    final fitnessGoal = _pickString([data['fitnessGoal'], data['goal']]);
    final level = _pickString([data['fitnessLevel'], data['activityLevel']]);

    return Scaffold(
      backgroundColor: kInk,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'User Profile',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              LiquidTile(
                radius: 18,
                accent: kSky,
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kSky.withValues(alpha: 0.5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14.5),
                        child:
                            photoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 180,
                                  memCacheHeight: 180,
                                  errorWidget:
                                      (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        color: kSky,
                                      ),
                                )
                                : const Icon(Icons.person_rounded, color: kSky),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _PlainKpi(title: 'Rate', value: rating, color: kNeon),
              const SizedBox(height: 10),
              LiquidTile(
                radius: 14,
                accent: kLilac,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comment',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment,
                      style: GoogleFonts.dmSans(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (email.isNotEmpty)
                _PlainKpi(title: 'Email', value: email, color: kSky),
              if (email.isNotEmpty) const SizedBox(height: 10),
              if (gender.isNotEmpty)
                _PlainKpi(title: 'Gender', value: gender, color: kCoral),
              if (gender.isNotEmpty) const SizedBox(height: 10),
              if (fitnessGoal.isNotEmpty)
                _PlainKpi(title: 'Goal', value: fitnessGoal, color: kLilac),
              if (fitnessGoal.isNotEmpty) const SizedBox(height: 10),
              if (level.isNotEmpty)
                _PlainKpi(title: 'Fitness Level', value: level, color: kNeon),
            ],
          ),
        ],
      ),
    );
  }

  String _pickString(List<dynamic> values, {String fallback = ''}) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return LiquidTile(
      radius: 16,
      accent: kLilac,
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.title,
    required this.valueRx,
    required this.color,
  });

  final String title;
  final RxInt valueRx;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _PlainKpi(
        title: title,
        value: valueRx.value.toString(),
        color: color,
      ),
    );
  }
}

class _PlainKpi extends StatelessWidget {
  const _PlainKpi({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LiquidTile(
      radius: 16,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.dmSans(color: kMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final kNeon = Theme.of(context).colorScheme.primary;
    final normalized = status.toLowerCase();

    final Color color;
    if (normalized == 'paid' || normalized == 'confirmed' || normalized == 'completed') {
      color = kNeon; // green
    } else if (normalized == 'approved') {
      color = const Color(0xFFFFBB33); // amber/gold
    } else if (normalized == 'requested' || normalized == 'pending') {
      color = kSky; // sky blue
    } else if (normalized == 'cancelled' || normalized == 'rejected') {
      color = kCoral; // red
    } else {
      color = kMuted; // grey for unknown
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1).toLowerCase(),
        style: GoogleFonts.dmSans(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.creditcard_fill, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.dmSans(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
