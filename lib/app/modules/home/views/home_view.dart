import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gym_trainer/app/modules/favorite/views/favorite_view.dart';
import 'package:gym_trainer/app/modules/profile/views/profile_screen.dart';
import 'package:gym_trainer/app/modules/messaging/views/messaging_screen.dart';
import '../../../services/favourites_service.dart';
import '../../../services/bookings_service.dart';
import '../controllers/home_controller.dart';
import '../../../../config/glass_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_comments_sheet.dart';

class HomeView extends ConsumerStatefulWidget {
  final String? autoOpenPostId;
  final String? autoOpenTrainerName;

  const HomeView({
    super.key,
    this.autoOpenPostId,
    this.autoOpenTrainerName,
  });

  static const Color ink = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF111118);
  static const Color card = Color(0xFF17171F);
  static const Color raised = Color(0xFF1E1E28);
  static const Color stroke = Color(0xFF2A2A36);
  static const Color neon = Color(0xFFCBFF47);
  static const Color coral = Color(0xFFFF5C5C);
  static const Color sky = Color(0xFF5CE8FF);
  static const Color lilac = Color(0xFFA78BFA);
  static const Color muted = Color(0xFF6B6B7E);
  static const Color transparent = Color(0x00000000);

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenPostId != null && widget.autoOpenPostId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PostCommentsSheet(
            postId: widget.autoOpenPostId!,
            trainerName: widget.autoOpenTrainerName ?? 'Trainer',
          ),
        );
      });
    }
  }

  // Color aliases — shadow ambiguous imports from sub-views
  Color get ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get surface => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFFFFFFF);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
  static const Color coral = HomeView.coral;
  static const Color sky = HomeView.sky;
  static const Color lilac = HomeView.lilac;

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeNotifierProvider);
    final controller = ref.read(homeNotifierProvider.notifier);

    final iconList = [
      CupertinoIcons.bolt,
      CupertinoIcons.heart_fill,
      CupertinoIcons.chat_bubble_fill,
      CupertinoIcons.person_fill,
    ];
    final labelList = ['Home', 'Favorite', 'Messages', 'Profile'];

    final pages = [
      _buildHomeTab(context, ref, homeState, controller),
      const FavouriteView(),
      const MessagingScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          IndexedStack(index: homeState.currentIndex, children: pages),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        backgroundColor: surface,
        itemCount: iconList.length,
        tabBuilder: (int index, bool isActive) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isActive ? neon : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconList[index],
                    size: 22,
                    color: isActive ? ink : muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labelList[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? neon : muted,
                  ),
                ),
              ],
            ),
          );
        },
        activeIndex: homeState.currentIndex,
        gapLocation: GapLocation.none,
        notchSmoothness: NotchSmoothness.softEdge,
        leftCornerRadius: 28,
        rightCornerRadius: 28,
        height: 82,
        splashColor: neon.withValues(alpha: 0.12),
        onTap: controller.changeTab,
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    WidgetRef ref,
    HomeState homeState,
    HomeNotifier controller,
  ) {
    const cats = ['All', 'Strength', 'Yoga', 'Cardio', 'Boxing', 'Swim'];
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(context, homeState, controller),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 28),
              _buildGreeting(homeState),
              const SizedBox(height: 24),
              _buildSearchBar(context, controller),
              const SizedBox(height: 32),
              _buildQuickActions(context, ref),
              const SizedBox(height: 32),
              _buildCategoryTabs(homeState, controller),
              const SizedBox(height: 32),
              _buildUpcomingSessionsSection(context, ref),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLabel(
                    '${cats[homeState.selectedCategoryIndex]} Trainers',
                    onSeeAll: () => controller.navigateToSearch(context),
                  ),
                  const SizedBox(height: 16),
                  _buildTrainersList(context, ref, controller),
                  const SizedBox(height: 24),
                  _buildTrainerFeedSection(context, ref, homeState, controller),
                  const SizedBox(height: 24),
                  _buildStatsRow(context, homeState, controller),
                  const SizedBox(height: 24),
                  _buildSpecialOfferCard(context, homeState, controller),
                  const SizedBox(height: 100),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverHeader(
    BuildContext context,
    HomeState homeState,
    HomeNotifier controller,
  ) {
    return SliverAppBar(
      backgroundColor: ink,
      expandedHeight: 0,
      floating: false,
      pinned: true,
      toolbarHeight: 82,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildAvatar(homeState),
                const Spacer(),
                _buildIconBtn(
                  CupertinoIcons.bell,
                  homeState.unreadNotificationsCount,
                  () => controller.navigateToNotifications(context),
                ),
                const SizedBox(width: 10),
                _buildIconBtn(
                  CupertinoIcons.chat_bubble,
                  homeState.unreadMessagesCount,
                  controller.navigateToMessages,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(HomeState homeState) {
    final photoUrl = homeState.userPhotoUrl;
    final initial = homeState.userInitial;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neon, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: photoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                memCacheWidth: 156,
                memCacheHeight: 156,
                fadeInDuration: const Duration(milliseconds: 120),
                errorWidget: (_, __, ___) => _buildAvatarFallback(initial),
              )
            : _buildAvatarFallback(initial),
      ),
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      color: raised,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: neon,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: text.withValues(alpha: 0.7), size: 22),
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: coral,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(HomeState homeState) {
    final name = homeState.userName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Hey, $name ',
                style: TextStyle(
                  color: text.withValues(alpha: 0.9),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              WidgetSpan(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.waving_hand,
                    size: 26,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ready to crush it today?',
          style: TextStyle(color: muted, fontSize: 15, letterSpacing: 0.2),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, HomeNotifier controller) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(CupertinoIcons.search, color: muted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              style: TextStyle(color: text, fontSize: 15),
              cursorColor: neon,
              decoration: InputDecoration(
                hintText: 'Search trainers, workouts...',
                hintStyle: TextStyle(color: muted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: controller.updateSearchQuery,
              onSubmitted: (_) => controller.navigateToSearch(context),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => controller.navigateToSearch(context),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: neon,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: neon.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.slider_horizontal_3,
                color: ink,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    HomeState homeState,
    HomeNotifier controller,
  ) {
    return Row(
      children: [
        _buildStatChip(
          CupertinoIcons.flame,
          '${homeState.streak}',
          'Streak',
          coral,
          onTap: () => controller.navigateToStreakDetails(context),
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          CupertinoIcons.sportscourt,
          '${homeState.sessionsCount}',
          'Sessions',
          sky,
          onTap: () => controller.navigateToSessionsDetails(context),
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          CupertinoIcons.rosette,
          '${homeState.goalsCount}',
          'Goals',
          neon,
          onTap: () => controller.navigateToGoalsDetails(context),
        ),
      ],
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String value,
    String label,
    Color accent, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(HomeState homeState, HomeNotifier controller) {
    final categories = [
      {'icon': CupertinoIcons.sparkles, 'label': 'All'},
      {'icon': CupertinoIcons.sportscourt, 'label': 'Strength'},
      {'icon': CupertinoIcons.person_2, 'label': 'Yoga'},
      {'icon': CupertinoIcons.bolt, 'label': 'Cardio'},
      {'icon': CupertinoIcons.hand_raised, 'label': 'Boxing'},
      {'icon': CupertinoIcons.drop, 'label': 'Swim'},
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = homeState.selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () => controller.selectCategory(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? neon : card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? neon : stroke),
              ),
              child: Row(
                children: [
                  Icon(
                    categories[index]['icon'] as IconData,
                    color: isSelected ? ink : muted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    categories[index]['label'] as String,
                    style: TextStyle(
                      color: isSelected ? ink : text.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingSessionsSection(BuildContext context, WidgetRef ref) {
    final bookingsState = ref.watch(bookingsServiceProvider);
    final upcomingBookings = bookingsState.upcomingBookings;

    if (upcomingBookings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(
          'Upcoming Sessions',
          onSeeAll: () => context.push('/all-sessions'),
        ),
        const SizedBox(height: 16),
        ...upcomingBookings.take(2).map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RepaintBoundary(child: _buildSessionCard(context, booking)),
              ),
            ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> booking) {
    final status = (booking['status'] ?? 'pending') as String;
    final isConfirmed = status == 'confirmed';
    final title = (booking['specialty'] ?? booking['sessionType'] ?? '') as String;
    final trainerName = (booking['trainer'] ?? booking['trainerName'] ?? '') as String;
    
    final statusColor = isConfirmed ? neon : const Color(0xFFFFB347); // warm orange/gold for pending
    final statusText = isConfirmed ? 'Confirmed' : 'Pending Approval';
    final paid = booking['paid'] == true;
    final amountPaid = (booking['amountPaid'] as num?)?.toInt() ?? 0;
    final price = (booking['price'] as num?)?.toInt() ?? 0;
    var paymentStatus = booking['paymentStatus'] as String? ?? (paid ? 'fully_paid' : (amountPaid > 0 ? 'partially_paid' : 'unpaid'));
    if (paymentStatus == 'completed') paymentStatus = 'fully_paid';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String paymentLabelText;
    final Color paymentColor;
    if (paymentStatus == 'fully_paid') {
      paymentLabelText = '\$$price • Paid';
      paymentColor = neon;
    } else if (paymentStatus == 'partially_paid') {
      paymentLabelText = '50% Paid (\$$amountPaid)';
      paymentColor = isDark ? const Color(0xFFFFBB33) : const Color(0xFFD97706); // Gold/Amber
    } else {
      paymentLabelText = '\$$price • Tap to Pay';
      paymentColor = coral;
    }

    return GestureDetector(
      onTap: () => context.push('/my-bookings', extra: const {'tab': 0}),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isConfirmed
                ? [neon.withValues(alpha: 0.12), neon.withValues(alpha: 0.02)]
                : [card, card.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConfirmed ? neon.withValues(alpha: 0.35) : stroke,
            width: isConfirmed ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isConfirmed ? neon.withValues(alpha: 0.25) : stroke,
                  width: 1.5,
                ),
              ),
              child: PremiumAvatar(
                name: (booking['trainer'] ?? booking['trainerName'] ?? 'Trainer').toString(),
                customPhotoUrl: booking['trainerPhotoUrl']?.toString(),
                size: 52,
                borderRadius: 12,
                isTrainer: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'with $trainerName',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (price > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: paymentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: paymentColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            paymentLabelText,
                            style: TextStyle(
                              color: paymentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isConfirmed ? neon : raised,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isConfirmed
                        ? [
                            BoxShadow(
                              color: neon.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    booking['date'] ?? '',
                    style: TextStyle(
                      color: isConfirmed ? ink : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 11,
                      color: isConfirmed ? neon.withValues(alpha: 0.8) : muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      booking['time'] ?? '',
                      style: TextStyle(
                        color: isConfirmed ? Colors.white.withValues(alpha: 0.9) : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionIcon(bool isConfirmed) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isConfirmed ? neon.withValues(alpha: 0.15) : raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        CupertinoIcons.sportscourt,
        color: isConfirmed ? neon : muted,
        size: 24,
      ),
    );
  }

  Widget _buildLabel(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See all',
              style: TextStyle(
                color: neon,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrainersList(
    BuildContext context,
    WidgetRef ref,
    HomeNotifier controller,
  ) {
    final trainers = controller.filteredTrainers;
    if (trainers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.person_2, color: muted, size: 32),
            const SizedBox(height: 8),
            Text(
              'No trainers found',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trainers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => RepaintBoundary(
          child: _buildTrainerCard(context, ref, controller, trainers[i]),
        ),
      ),
    );
  }

  Widget _buildTrainerCard(
    BuildContext context,
    WidgetRef ref,
    HomeNotifier controller,
    Map<String, dynamic> trainer,
  ) {
    final isAvailable = trainer['isAvailable'] == true;
    final favourites = ref.watch(favouritesServiceProvider);
    final favNotifier = ref.read(favouritesServiceProvider.notifier);
    final trainerName = trainer['name'] as String? ?? '';

    final isFav = favourites.any((f) => f['name'] == trainerName);

    return GestureDetector(
      onTap: () => controller.navigateToTrainerDetails(context, trainer),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Container(
                    height: 96,
                    width: double.infinity,
                    color: raised,
                    child: (trainer['image'] != null && (trainer['image'] as String).isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: trainer['image'] as String,
                            fit: BoxFit.cover,
                            memCacheWidth: 320,
                            memCacheHeight: 208,
                            fadeInDuration: const Duration(milliseconds: 120),
                            errorWidget: (_, __, ___) => _buildFallbackWidget(trainerName),
                          )
                        : _buildFallbackWidget(trainerName),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAvailable ? neon : raised,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isAvailable ? ink : muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAvailable ? 'Open' : 'Busy',
                          style: TextStyle(
                            color: isAvailable ? ink : muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => favNotifier.toggle(trainer),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isFav
                            ? coral.withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trainer['name'] ?? '',
                    style: TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trainer['specialty'] ?? '',
                    style: TextStyle(color: muted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.star_fill, color: neon, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            '${trainer['rating']}',
                            style: TextStyle(
                              color: text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${trainer['pricePerHour']}/h',
                        style: TextStyle(
                          color: text.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: neon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: neon.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'View Profile →',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: neon,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackWidget(String name) {
    final initials = name.trim().isEmpty
        ? 'T'
        : name.trim().split(RegExp(r'\s+')).take(2).map((s) => s[0]).join().toUpperCase();
    final hash = name.hashCode.abs();
    final gradients = [
      [const Color(0xFF896CFE), const Color(0xFF5CE8FF)], // Purple to Sky
      [const Color(0xFFFF5C5C), const Color(0xFFF59E0B)], // Coral to Orange
      [const Color(0xFF10B981), const Color(0xFF3B82F6)], // Emerald to Blue
      [const Color(0xFFEC4899), const Color(0xFF8B5CF6)], // Pink to Violet
    ];
    final selectedGradient = gradients[hash % gradients.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selectedGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.2),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
          ),
          child: Text(
            initials,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerFeedSection(
    BuildContext context,
    WidgetRef ref,
    HomeState homeState,
    HomeNotifier controller,
  ) {
    final posts = homeState.latestTrainerPosts;
    if (posts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(
          'Trainer Feed',
          onSeeAll: () => context.push('/all-feeds'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => RepaintBoundary(
              child: _buildPostCard(context, ref, homeState, controller, posts[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    WidgetRef ref,
    HomeState homeState,
    HomeNotifier controller,
    Map<String, dynamic> post,
  ) {
    final trainerName = (post['trainerName'] ?? post['authorName'] ?? 'Trainer').toString();
    final trainerId = (post['trainerId'] ?? post['authorId'] ?? '').toString();

    Map<String, dynamic>? trainerProfile;
    if (trainerId.isNotEmpty) {
      trainerProfile = homeState.trainerCatalog.firstWhereOrNull(
        (t) => (t['trainerId'] ?? t['id']).toString() == trainerId,
      );
    }

    trainerProfile ??= homeState.trainerCatalog.firstWhereOrNull(
      (t) => _normalizeName(t['name']?.toString() ?? '') == _normalizeName(trainerName),
    );

    final trainer = trainerProfile ?? post;
    final name = (trainer['name'] ?? trainerName).toString();
    final specialty = (trainer['specialty'] ?? 'Fitness').toString();
    final trainerImageUrl = (
      trainerProfile?['image'] ??
      trainerProfile?['imageUrl'] ??
      post['trainerPhotoUrl'] ??
      ''
    ).toString();

    final title = (post['title'] ?? '').toString();
    final caption = (post['caption'] ?? '').toString();
    final category = (post['category'] ?? 'Workout').toString();
    final postImageUrl = (post['imageUrl'] ?? '').toString();
    final likes = (post['likesCount'] ?? 0);
    final comments = (post['commentsCount'] ?? 0);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final likedBy = List<String>.from(post['likedBy'] ?? <dynamic>[]);
    final isLiked = currentUid != null && likedBy.contains(currentUid);
    final postId = (post['id'] ?? post['postId'] ?? '').toString();

    return GestureDetector(
      onTap: () => controller.navigateToTrainerFromPost(context, post),
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Trainer avatar + name + category badge)
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: neon.withOpacity(0.3), width: 1.5),
                  ),
                  child: PremiumAvatar(
                    name: name,
                    customPhotoUrl: trainerImageUrl,
                    size: 36,
                    borderRadius: 8.5,
                    isTrainer: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: text,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sky.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sky.withOpacity(0.2)),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.dmSans(
                      color: sky,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Post Image (if present)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: postImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: postImageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildPlaceholderPostBg(),
                      )
                    : _buildPlaceholderPostBg(),
              ),
            ),
            const SizedBox(height: 10),
            
            // Title
            if (title.isNotEmpty) ...[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
            ],
            
            // Caption
            Text(
              caption.isNotEmpty ? caption : 'Tap to read this post from $name.',
              maxLines: title.isNotEmpty ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: text.withValues(alpha: 0.7),
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            
            // Footer (likes/comments count + date/view details link)
            Row(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (postId.isNotEmpty) {
                          ref.read(homeNotifierProvider.notifier).togglePostLike(postId);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                              color: isLiked ? coral : muted,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              likes.toString(),
                              style: GoogleFonts.dmSans(
                                color: isLiked ? coral : muted,
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
                        if (postId.isNotEmpty) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => PostCommentsSheet(
                              postId: postId,
                              trainerName: name,
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.chat_bubble, color: sky, size: 14),
                            const SizedBox(width: 4),
                            // Real-time total count: comments + all replies
                            StreamBuilder<QuerySnapshot>(
                              stream: postId.isNotEmpty
                                  ? FirebaseFirestore.instance
                                      .collection('trainerPosts')
                                      .doc(postId)
                                      .collection('comments')
                                      .snapshots()
                                  : const Stream.empty(),
                              builder: (context, snap) {
                                int total = comments; // fallback until stream loads
                                if (snap.hasData) {
                                  final docs = snap.data!.docs;
                                  // Sum top-level comments + replies inside each
                                  total = docs.fold(0, (sum, doc) {
                                    final data = doc.data() as Map<String, dynamic>? ?? {};
                                    final replyCount = (data['repliesCount'] as num?)?.toInt() ?? 0;
                                    return sum + 1 + replyCount;
                                  });
                                }
                                return Text(
                                  total.toString(),
                                  style: GoogleFonts.dmSans(
                                    color: muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'View details →',
                  style: GoogleFonts.dmSans(
                    color: neon,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPostBg() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            sky.withOpacity(0.05),
            lilac.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.doc_text_fill,
        color: muted.withOpacity(0.24),
        size: 32,
      ),
    );
  }

  DateTime? _parseDate(dynamic dateVal) {
    if (dateVal == null) return null;
    if (dateVal is DateTime) return dateVal;
    if (dateVal is String) {
      try {
        return DateTime.parse(dateVal);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(dynamic timeVal) {
    if (timeVal is String) return timeVal;
    return '7:00 AM';
  }

  String _normalizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final actions = [
      {
        'icon': CupertinoIcons.calendar,
        'label': 'Book',
        'color': neon,
        'onTap': () => ref.read(homeNotifierProvider.notifier).navigateToBook(context),
      },
      {
        'icon': CupertinoIcons.time,
        'label': 'History',
        'color': sky,
        'onTap': () => ref.read(homeNotifierProvider.notifier).navigateToHistory(context),
      },
      {
        'icon': CupertinoIcons.creditcard,
        'label': 'Payment',
        'color': lilac,
        'onTap': () => ref.read(homeNotifierProvider.notifier).navigateToPayment(context),
      },
      {
        'icon': CupertinoIcons.headphones,
        'label': 'Support',
        'color': coral,
        'onTap': () => _showSupportSheet(context, ref),
      },
    ];

    return Row(
      children: actions.map((action) {
        final accent = action['color'] as Color;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: action == actions.last ? 0 : 10,
            ),
            child: GestureDetector(
              onTap: action['onTap'] as VoidCallback,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: stroke),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      style: TextStyle(
                        color: text.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecialOfferCard(
    BuildContext context,
    HomeState homeState,
    HomeNotifier controller,
  ) {
    if (!homeState.promoActive) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => controller.claimPromo(context),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: neon,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.flame_fill,
                          color: ink,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          homeState.promoLabel,
                          style: TextStyle(
                            color: ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    homeState.promoTitle,
                    style: TextStyle(
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      homeState.promoButtonText,
                      style: TextStyle(
                        color: neon,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Opacity(
              opacity: 0.2,
              child: Text(
                homeState.promoDiscount,
                style: TextStyle(
                  color: ink,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              const Text(
                'Contact Support',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Our team is available 24 / 7 to help you.',
                style: TextStyle(color: muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _supportTile(
                icon: CupertinoIcons.chat_bubble_text,
                label: 'Live Chat',
                sub: 'Avg. response < 2 min',
                accent: sky,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(homeNotifierProvider.notifier).navigateToMessages();
                },
              ),
              const SizedBox(height: 12),
              _supportTile(
                icon: CupertinoIcons.envelope,
                label: 'Email Us',
                sub: 'support@gymtrainer.app',
                accent: lilac,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Email Support: support@gymtrainer.app'),
                      backgroundColor: card,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _supportTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: muted, fontSize: 12)),
              ],
            ),
             const Spacer(),
             Icon(CupertinoIcons.chevron_right, color: muted, size: 16),
           ],
         ),
       ),
     );
   }

  Widget _buildFallbackHomeBookingAvatar(Map<String, dynamic> booking, bool isConfirmed) {
    final name = (booking['trainer'] ?? booking['trainerName'] ?? 'Trainer').toString();
    return InitialsAvatar(
      name: name,
      size: 52,
      fontSize: 18,
      borderRadius: 12,
    );
  }
}
