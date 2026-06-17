import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../config/glass_ui.dart';
import '../../../services/favourites_service.dart';
import '../controllers/home_controller.dart';

// ─── Realtime Bookings Provider ──────────────────────────────────────────────
final allBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('bookings')
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

// ─── Dynamic Slots Helpers ───────────────────────────────────────────────────
String _getDayOfWeekString(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[date.weekday - 1];
}

String _formatBookingDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  return '$weekday, $month ${date.day}, ${date.year}';
}

List<String> _generateSlots(String startStr, String endStr) {
  final startParts = startStr.split(':');
  final endParts = endStr.split(':');

  final startHour = int.tryParse(startParts.first) ?? 9;
  final startMinute = (startParts.length > 1 ? int.tryParse(startParts[1]) : null) ?? 0;

  final endHour = int.tryParse(endParts.first) ?? 18;
  final endMinute = (endParts.length > 1 ? int.tryParse(endParts[1]) : null) ?? 0;

  final List<String> slots = [];
  var currentHour = startHour;
  var currentMinute = startMinute;

  while (true) {
    if (currentHour > endHour || (currentHour == endHour && currentMinute >= endMinute)) {
      break;
    }

    final ampm = currentHour >= 12 ? 'PM' : 'AM';
    final displayHour = currentHour % 12 == 0 ? 12 : currentHour % 12;
    final hourStr = displayHour.toString().padLeft(2, '0');
    final minuteStr = currentMinute.toString().padLeft(2, '0');
    final timeSlotStr = '$hourStr:$minuteStr $ampm';

    slots.add(timeSlotStr);
    currentHour += 1;
  }

  return slots;
}

int _extractPortraitIndex(String imageUrl, String name) {
  final match = RegExp(r'portraits/men/(\d+)\.jpg').firstMatch(imageUrl);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '10') ?? 10;
  }
  final matchWomen = RegExp(r'portraits/women/(\d+)\.jpg').firstMatch(imageUrl);
  if (matchWomen != null) {
    return int.tryParse(matchWomen.group(1) ?? '10') ?? 10;
  }
  return name.hashCode.abs() % 100;
}

List<Map<String, dynamic>> _generateDynamicSessions({
  required List<Map<String, dynamic>> trainerCatalog,
  required List<Map<String, dynamic>> allBookings,
  required bool isOnlineTab,
}) {
  final now = DateTime.now();
  final List<Map<String, dynamic>> sessions = [];
  final Set<String> addedTrainerIds = {};

  // Filter out static mock trainers, keeping only real trainers loaded from Firestore
  final realTrainers = trainerCatalog.where((t) {
    final id = (t['trainerId'] ?? t['id'] ?? '').toString();
    const mockIds = {
      '1', 's2', 's3', '2', 'y2', 'y3', '3', 'c2', 'c3', 'b1', 'b2', 'b3', 'sw1', 'sw2'
    };
    return id.isNotEmpty && !mockIds.contains(id);
  }).toList();

  for (int i = 0; i < 7; i++) {
    final date = now.add(Duration(days: i));
    final dayOfWeek = _getDayOfWeekString(date);
    final formattedDate = _formatBookingDate(date);

    for (final trainer in realTrainers) {
      final trainerId = (trainer['trainerId'] ?? trainer['id'] ?? '').toString();
      if (addedTrainerIds.contains(trainerId)) continue;

      final availabilityMap = trainer['availability'];
      if (availabilityMap is! Map || availabilityMap.isEmpty) continue;

      final avail = availabilityMap[dayOfWeek];
      if (avail == null || avail['enabled'] != true) continue;

      final startStr = (avail['start'] ?? '09:00').toString();
      final endStr = (avail['end'] ?? '18:00').toString();

      final slots = _generateSlots(startStr, endStr);
      if (slots.isEmpty) continue;

      final trainerName = trainer['name']?.toString() ?? 'Trainer';

      final locations = (trainer['sessionLocations'] is List)
          ? List<String>.from(trainer['sessionLocations'])
          : <String>[];

      final supportsStudio = locations.isEmpty ||
          locations.any((l) => l.toLowerCase().contains('studio') || l.toLowerCase().contains('in-person'));
      final supportsOnline = locations.any((l) => l.toLowerCase().contains('online') || l.toLowerCase().contains('video'));

      // Check support for this tab
      if (isOnlineTab && !supportsOnline) continue;
      if (!isOnlineTab && !supportsStudio) continue;

      // Select the first slot of the day to represent the trainer's availability
      final slot = slots.first;

      final booking = allBookings.where((b) =>
          b['trainerId'] == trainerId &&
          b['date'] == formattedDate &&
          b['time'] == slot &&
          (b['status'] == 'pending' || b['status'] == 'confirmed')
      ).firstWhereOrNull((_) => true);

      String sessionType = '1-on-1';
      int maxSpots = 1;

      // Distribute types dynamically based on the date day to show diverse types under filter chips
      if (isOnlineTab) {
        if (date.day % 3 == 0) {
          sessionType = 'Video';
          maxSpots = 12;
        } else if (date.day % 3 == 1) {
          sessionType = '1-on-1';
          maxSpots = 1;
        } else {
          sessionType = '1-on-2';
          maxSpots = 2;
        }
      } else {
        if (date.day % 3 == 0) {
          sessionType = 'Group';
          maxSpots = 10;
        } else if (date.day % 3 == 1) {
          sessionType = '1-on-4';
          maxSpots = 4;
        } else {
          sessionType = '1-on-1';
          maxSpots = 1;
        }
      }

      final int bookedSpots = booking != null ? 1 : 0;
      final int spotsLeft = (maxSpots - bookedSpots).clamp(0, maxSpots);
      final bool isOpen = spotsLeft > 0 && trainer['isAvailable'] == true;

      sessions.add({
        'trainer': trainerName,
        'trainerId': trainerId,
        'id': trainerId,
        'specialty': trainer['specialty'] ?? 'Personal Trainer',
        'date': formattedDate,
        'time': slot,
        'type': sessionType,
        'status': isOpen ? 'open' : 'full',
        'price': isOnlineTab
            ? ((trainer['pricePerHour'] as num?)?.toInt() ?? 45) - 10
            : ((trainer['pricePerHour'] as num?)?.toInt() ?? 45),
        'spots': spotsLeft,
        'rating': (trainer['rating'] as num?)?.toDouble() ?? 4.9,
        'sessions': (trainer['reviews'] as num?)?.toInt() ?? 100,
        'isAvailable': trainer['isAvailable'] == true && isOpen,
        'image': trainer['image'] ?? '',
        'portrait': _extractPortraitIndex(trainer['image'] ?? '', trainerName),
        if (isOnlineTab) 'youtubeId': 'UItWltVZZmE',
        if (isOnlineTab) 'youtubeChannel': 'https://www.youtube.com/@SamRiveraFitness',
      });

      // Mark this trainer as added so they don't show up again
      addedTrainerIds.add(trainerId);
    }
  }
  return sessions;
}

class AllSessionsView extends ConsumerStatefulWidget {
  const AllSessionsView({super.key});

  @override
  ConsumerState<AllSessionsView> createState() => _AllSessionsViewState();
}

class _AllSessionsViewState extends ConsumerState<AllSessionsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get _surface => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFFFFFFF);
  Color get _card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get _raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get _stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get _neon => Theme.of(context).colorScheme.primary;
  Color get _coral => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF5C5C) : const Color(0xFFEF4444);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color get _text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  // Studio filter chips
  final List<String> _studioTypes = ['All', '1-on-1', '1-on-4', 'Group'];
  int _selectedStudioType = 0;

  // Online filter chips
  final List<String> _onlineTypes = [
    'All',
    'Video',
    '1-on-1',
    '1-on-2',
    '1-on-4',
  ];
  int _selectedOnlineType = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeNotifierProvider);
    final bookingsAsync = ref.watch(allBookingsProvider);

    final allBookings = bookingsAsync.value ?? const [];
    final trainerCatalog = homeState.trainerCatalog;

    final studioSessions = _generateDynamicSessions(
      trainerCatalog: trainerCatalog,
      allBookings: allBookings,
      isOnlineTab: false,
    );

    final onlineSessions = _generateDynamicSessions(
      trainerCatalog: trainerCatalog,
      allBookings: allBookings,
      isOnlineTab: true,
    );

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: _text),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'All Sessions',
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _stroke, width: 1.2),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _neon,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: _ink,
              unselectedLabelColor: _muted,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(height: 42, text: 'Studio'),
                Tab(height: 42, text: 'Online'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          TabBarView(
            controller: _tabController,
            children: [
              _buildStudioTab(studioSessions),
              _buildOnlineTab(onlineSessions),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Studio Tab ────────────────────────────────────────────────────────────
  Widget _buildStudioTab(List<Map<String, dynamic>> sessions) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildFilterChips(
            chips: _studioTypes,
            selected: _selectedStudioType,
            onSelect: (i) => setState(() => _selectedStudioType = i),
          ),
          Expanded(
            child: _buildSessionList(
              sessions,
              _studioTypes,
              _selectedStudioType,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Online Tab ────────────────────────────────────────────────────────────
  Widget _buildOnlineTab(List<Map<String, dynamic>> sessions) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildFilterChips(
            chips: _onlineTypes,
            selected: _selectedOnlineType,
            onSelect: (i) => setState(() => _selectedOnlineType = i),
          ),
          Expanded(
            child: _buildSessionList(
              sessions,
              _onlineTypes,
              _selectedOnlineType,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required List<String> chips,
    required int selected,
    required ValueChanged<int> onSelect,
  }) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        itemBuilder: (_, i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: active ? _neon : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? _neon : _stroke),
              ),
              child: Center(
                child: Text(
                  chips[i],
                  style: TextStyle(
                    color: active ? _ink : _muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionList(
    List<Map<String, dynamic>> sessions,
    List<String> types,
    int selectedIndex,
  ) {
    final filtered =
        selectedIndex == 0
            ? sessions
            : sessions.where((s) => s['type'] == types[selectedIndex]).toList();

    if (filtered.isEmpty) {
      return Container(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.calendar_badge_minus,
                color: _muted,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'No sessions available',
                style: TextStyle(color: _muted, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildAvailableCard(filtered[i]),
    );
  }

  Widget _buildAvailableCard(Map<String, dynamic> s) {
    final isOpen = s['status'] == 'open';
    final spots = s['spots'] as int;
    final statusColor = isOpen ? _neon : _coral;
    final portrait = s['portrait'] ?? 10;
    final imageUrl = (s['image'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        if (s['type'] == 'Video') {
          _showVideoDetail(s);
        } else {
          context.push(
            '/trainer-details',
            extra: {
              'name': s['trainer'],
              'specialty': s['specialty'],
              'rating': s['rating'] ?? 4.5,
              'sessions': s['sessions'] ?? 0,
              'portrait': portrait,
              'price': s['price'],
              'isAvailable': s['isAvailable'] ?? (s['status'] == 'open'),
              'id': s['trainerId'] ?? s['id'] ?? '',
              'trainerId': s['trainerId'] ?? s['id'] ?? '',
              'image': imageUrl,
            },
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Portrait
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _neon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _neon.withValues(alpha: 0.25)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PremiumAvatar(
                      name: (s['trainer'] ?? 'Trainer').toString(),
                      customPhotoUrl: imageUrl,
                      size: 46,
                      borderRadius: 12,
                      isTrainer: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + specialty
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['trainer'] as String,
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        s['specialty'] as String,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    isOpen ? 'Open' : 'Full',
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
            Container(height: 1, color: _stroke),
            const SizedBox(height: 12),
            // Info chips row
            Row(
              children: [
                _infoChip(CupertinoIcons.calendar, s['date'] as String),
                const SizedBox(width: 14),
                _infoChip(CupertinoIcons.clock, s['time'] as String),
                const SizedBox(width: 14),
                _infoChip(CupertinoIcons.person_2, s['type'] as String),
              ],
            ),
            const SizedBox(height: 14),
            // Price + spots row + Book button
            Row(
              children: [
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${s['price']}/session',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      isOpen
                          ? (spots == 1 ? '1 spot left' : '$spots spots left')
                          : 'No spots left',
                      style: TextStyle(
                        color: isOpen ? _neon : _coral,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Book button
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed:
                        isOpen
                            ? () => context.push(
                              '/book-session',
                              extra: {
                                'name': s['trainer'],
                                'specialty': s['specialty'],
                                'portrait': s['portrait'],
                                'price': s['price'],
                                'trainerId': s['trainerId'] ?? s['id'] ?? '',
                                'image': s['image'] ?? '',
                                'rating': s['rating'] ?? 4.9,
                              },
                            )
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOpen ? _neon : _raised,
                      disabledBackgroundColor: _raised,
                      foregroundColor: isOpen ? (Theme.of(context).brightness == Brightness.dark ? _ink : Colors.white) : _muted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      elevation: 0,
                    ),
                    child: Text(
                      isOpen ? 'Book Session' : 'Full',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isOpen ? (Theme.of(context).brightness == Brightness.dark ? _ink : Colors.white) : _muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoDetail(Map<String, dynamic> s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _VideoDetailPage(session: s)),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _muted, size: 13),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video Session Detail — full-screen page matching trainer_details_view style
// ─────────────────────────────────────────────────────────────────────────────
class _VideoDetailPage extends StatefulWidget {
  const _VideoDetailPage({required this.session});
  final Map<String, dynamic> session;

  @override
  State<_VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<_VideoDetailPage> {
  Map<String, dynamic> get session => widget.session;

  // design tokens (mirrors trainer_details_view)
  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get _card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get _raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get _stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get _neon => Theme.of(context).colorScheme.primary;
  Color get _coral => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF5C5C) : const Color(0xFFEF4444);
  Color get _sky => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5CE8FF) : const Color(0xFF06B6D4);
  Color get _lilac => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color get _text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  Future<void> _openYouTube(String url, String fallback) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse(fallback), mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final isOpen = s['status'] == 'open';
    final spots = s['spots'] as int;
    final portrait = s['portrait'] as int;
    final name = s['trainer'] as String;
    final spec = s['specialty'] as String;
    final rat = (s['rating'] ?? 4.5) as num;
    final sessions = (s['sessions'] ?? 0) as int;
    final price = s['price'] as int;
    final youtubeId = s['youtubeId'] as String? ?? '';
    final youtubeChannel =
        s['youtubeChannel'] as String? ??
        'https://www.youtube.com/watch?v=$youtubeId';
    final thumbUrl = 'https://img.youtube.com/vi/$youtubeId/maxresdefault.jpg';
    final ytVideoUrl = 'https://www.youtube.com/watch?v=$youtubeId';
    final description =
        '$name is a certified trainer with 10+ years of experience helping '
        'clients achieve their fitness goals. Passionate about '
        '${spec.toLowerCase()}, nutrition, and holistic health.';

    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero ──────────────────────────────────────────────────────
                  _buildHero(
                    context,
                    name,
                    spec,
                    rat,
                    sessions,
                    portrait,
                    isOpen,
                    (s['image'] ?? '').toString(),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // ── Stats ──────────────────────────────────────────────
                        _buildStatsRow(rat, sessions),
                        const SizedBox(height: 24),

                        // ── Session info chips ─────────────────────────────────
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _chip(CupertinoIcons.calendar, s['date'] as String),
                            _chip(CupertinoIcons.clock, s['time'] as String),
                            _chip(
                              CupertinoIcons.play_rectangle,
                              'Video Session',
                            ),
                            _chip(
                              CupertinoIcons.money_dollar_circle,
                              '\$$price / session',
                            ),
                            _chip(
                              CupertinoIcons.person_2,
                              isOpen ? 'Open · $spots spots' : 'Session Full',
                              accent: isOpen ? _neon : _coral,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── About ──────────────────────────────────────────────
                        _sectionTitle('About'),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(
                            color: _text.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── YouTube Video ──────────────────────────────────────
                        _sectionTitle('Trainer Video'),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _openYouTube(ytVideoUrl, ytVideoUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              children: [
                                Image.network(
                                  thumbUrl,
                                  height: 210,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        height: 210,
                                        color: _raised,
                                        child: const Center(
                                          child: Icon(
                                            CupertinoIcons.play_circle,
                                            color: Colors.white38,
                                            size: 60,
                                          ),
                                        ),
                                      ),
                                ),
                                // gradient
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.55),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // play button
                                Positioned.fill(
                                  child: Center(
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: _neon,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _neon.withValues(
                                              alpha: 0.55,
                                            ),
                                            blurRadius: 24,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.play_fill,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                // YouTube badge
                                Positioned(
                                  left: 14,
                                  bottom: 12,
                                  child: Row(
                                    children: [
                                      _YouTubeLogo(size: 20),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Trainer Video',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Watch on YouTube — professional button
                        GestureDetector(
                          onTap: () => _openYouTube(youtubeChannel, ytVideoUrl),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF0000,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _YouTubeLogo(size: 22),
                                const SizedBox(width: 10),
                                const Text(
                                  'Watch on YouTube',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Certifications ────────────────────────────────────
                        _buildCertifications(),
                        const SizedBox(height: 24),

                        // ── Reviews ───────────────────────────────────────────
                        _buildReviews(name),
                        const SizedBox(height: 24),

                        // ── Schedule ──────────────────────────────────────────
                        _buildSchedule(),
                        const SizedBox(height: 28),

                        // ── Book + Message buttons ─────────────────────────────
                        GestureDetector(
                          onTap: isOpen ? () => Navigator.pop(context) : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            decoration: BoxDecoration(
                              color: isOpen ? _neon : _stroke,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow:
                                  isOpen
                                      ? [
                                        BoxShadow(
                                          color: _neon.withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                      : [],
                            ),
                            child: Center(
                              child: Text(
                                isOpen ? 'Book a Session' : 'Session Full',
                                style: TextStyle(
                                  color: isOpen ? (Theme.of(context).brightness == Brightness.dark ? _ink : Colors.white) : _muted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Message button
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  final trainerId = (s['trainerId'] ?? s['id'] ?? '').toString();
                                  context.push('/message-screen', extra: {
                                    'name': name,
                                    'specialty': spec,
                                    'portrait': portrait,
                                    'otherId': trainerId,
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.chat_bubble,
                                        color: _text.withValues(alpha: 0.7),
                                        size: 17,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Message',
                                        style: TextStyle(
                                          color: _text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Review button
                            Expanded(
                              child: GestureDetector(
                                onTap: () {},
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.star,
                                        color: _text.withValues(alpha: 0.7),
                                        size: 17,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Review',
                                        style: TextStyle(
                                          color: _text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
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

  // ── Hero ───────────────────────────────────────────────────────────────────
  Widget _buildHero(
    BuildContext context,
    String name,
    String spec,
    num rat,
    int sessions,
    int portrait,
    bool isOpen,
    String imageUrl,
  ) {
    return Stack(
      children: [
        SizedBox(
          height: 320,
          width: double.infinity,
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.network(
                    'https://randomuser.me/api/portraits/men/$portrait.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _raised,
                      child: Center(
                        child: Icon(
                          CupertinoIcons.person_fill,
                          color: _muted,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                )
              : Image.network(
                  'https://randomuser.me/api/portraits/men/$portrait.jpg',
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        color: _raised,
                        child: Center(
                          child: Icon(
                            CupertinoIcons.person_fill,
                            color: _muted,
                            size: 80,
                          ),
                        ),
                      ),
                ),
        ),
        // gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, _ink.withValues(alpha: 0.5), _ink],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        // back button
        Positioned(
          top: 12,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke),
              ),
              child: const Icon(
                CupertinoIcons.back,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        // favourite button
        Positioned(
          top: 12,
          right: 16,
          child: Consumer(
            builder: (context, ref, _) {
              final favourites = ref.watch(favouritesServiceProvider);
              final favNotifier = ref.read(favouritesServiceProvider.notifier);
              final trainerMap = {
                'name': session['trainer'],
                'specialty': session['specialty'],
                'rating': session['rating'] ?? 4.5,
                'price': session['price'],
                'sessions': session['sessions'] ?? 0,
                'portrait': session['portrait'],
                'available': session['status'] == 'open',
                'isAvailable': session['status'] == 'open',
                'image': '',
              };
              final isFav = favourites.any((f) => f['name'] == session['trainer']);
              return GestureDetector(
                onTap: () {
                  favNotifier.toggle(trainerMap);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _ink.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isFav ? _coral : _stroke),
                  ),
                  child: Icon(
                    isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    color: isFav ? _coral : Colors.white,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ),
        // name block
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isOpen ? _neon : _raised,
                        borderRadius: BorderRadius.circular(7),
                        border: isOpen ? null : Border.all(color: _stroke),
                      ),
                      child: Text(
                        isOpen ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          color: isOpen ? _ink : _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: TextStyle(
                        color: _text,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec,
                      style: TextStyle(
                        color: _text.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // rating pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.star_fill,
                      color: _neon,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rat.toStringAsFixed(1),
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($sessions)',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow(num rating, int sessions) {
    return Row(
      children: [
        _statCard(CupertinoIcons.gift, '29 yrs', 'Age', _coral),
        const SizedBox(width: 12),
        _statCard(CupertinoIcons.resize_v, '1.82m', 'Height', _sky),
        const SizedBox(width: 12),
        _statCard(CupertinoIcons.person_3, '$sessions+', 'Sessions', _lilac),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── Certifications ─────────────────────────────────────────────────────────
  Widget _buildCertifications() {
    final certs = [
      {
        'icon': CupertinoIcons.checkmark_seal,
        'label': 'Certified Personal Trainer (CPT)',
        'color': _neon,
      },
      {
        'icon': CupertinoIcons.timer,
        'label': '10+ years experience',
        'color': _sky,
      },
      {
        'icon': CupertinoIcons.cart,
        'label': 'Nutrition Specialist',
        'color': _coral,
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Certifications'),
        const SizedBox(height: 12),
        ...certs.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (c['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      c['icon'] as IconData,
                      color: c['color'] as Color,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    c['label'] as String,
                    style: TextStyle(
                      color: _text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Schedule ───────────────────────────────────────────────────────────────
  Widget _buildSchedule() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const avail = [true, true, false, true, true, false, true];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Schedule'),
            Text('This week', style: TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(days.length, (i) {
            final ok = avail[i];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  days[i],
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ok ? _neon.withValues(alpha: 0.1) : _raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ok ? _neon.withValues(alpha: 0.4) : _stroke,
                    ),
                  ),
                  child: Icon(
                    ok ? CupertinoIcons.checkmark : CupertinoIcons.xmark,
                    color: ok ? _neon : _muted,
                    size: 16,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // ── Reviews ────────────────────────────────────────────────────────────────
  Widget _buildReviews(String trainerName) {
    final reviews = [
      {
        'name': 'Jessica L.',
        'portrait': 20,
        'rating': 5,
        'time': '2 days ago',
        'comment':
            'Amazing session! ${trainerName.split(' ')[0]} explains every move clearly and keeps the energy high. Highly recommend!',
      },
      {
        'name': 'Carlos M.',
        'portrait': 32,
        'rating': 4,
        'time': '1 week ago',
        'comment':
            'Great trainer, very motivating. The video quality is excellent and the workout was challenging but fun.',
      },
      {
        'name': 'Sophie K.',
        'portrait': 44,
        'rating': 5,
        'time': '2 weeks ago',
        'comment':
            'Best online session I\'ve had. Very professional and always on time. Will book again!',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Reviews'),
            Row(
              children: [
                Icon(CupertinoIcons.star_fill, color: _neon, size: 14),
                const SizedBox(width: 4),
                Text(
                  '4.8  ·  ${reviews.length * 34} reviews',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reviews.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(
                        'https://randomuser.me/api/portraits/women/${r['portrait']}.jpg',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['name'] as String,
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < (r['rating'] as int)
                                    ? CupertinoIcons.star_fill
                                    : CupertinoIcons.star,
                                color:
                                    i < (r['rating'] as int) ? _neon : _stroke,
                                size: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      r['time'] as String,
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  r['comment'] as String,
                  style: TextStyle(
                    color: _text.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      color: _text,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
  );

  Widget _chip(
    IconData icon,
    String label, {
    Color? accent,
  }) {
    final activeAccent = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activeAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Professional YouTube Logo Widget ─────────────────────────────────────────
class _YouTubeLogo extends StatelessWidget {
  const _YouTubeLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.42, size),
      painter: _YouTubeLogoPainter(),
    );
  }
}

class _YouTubeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bgPaint = Paint()..color = const Color(0xFFFF0000);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h * 0.22),
    );
    canvas.drawRRect(rrect, bgPaint);

    final triPaint = Paint()..color = Colors.white;
    final triPath =
        Path()
          ..moveTo(w * 0.38, h * 0.23)
          ..lineTo(w * 0.38, h * 0.77)
          ..lineTo(w * 0.74, h * 0.50)
          ..close();
    canvas.drawPath(triPath, triPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
