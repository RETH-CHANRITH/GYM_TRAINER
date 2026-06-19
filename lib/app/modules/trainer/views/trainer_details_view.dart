import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/trainer_details_controller.dart';
import '../controllers/trainer_rating_controller.dart';
import '../../../services/favourites_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/views/post_comments_sheet.dart';
import 'trainer_rating_sheet.dart';

const Color coral = Color(0xFFFF5C5C);
const Color sky = Color(0xFF5CE8FF);
const Color lilac = Color(0xFFA78BFA);

class TrainerDetailsView extends ConsumerWidget {
  final Map<String, dynamic>? arguments;
  const TrainerDetailsView({super.key, this.arguments});

  Color _ink(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color _card(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color _raised(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color _stroke(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color _text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
  Color _muted(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color _neon(BuildContext context) => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Map<String, dynamic>? args = arguments;
    if (args == null) {
      try {
        final extra = GoRouterState.of(context).extra;
        if (extra is Map<String, dynamic>) {
          args = extra;
        }
      } catch (_) {}
    }

    final state = ref.watch(trainerDetailsProvider(args));
    final controller = ref.read(trainerDetailsProvider(args).notifier);

    final name = state.trainerName;
    final spec = state.specialty;

    final ratingsState = ref.watch(trainerRatingsProvider(state.trainerId));
    final hasReviews = ratingsState.totalReviews > 0;
    final rat = hasReviews ? ratingsState.avgRating : state.rating;
    final reviews = ratingsState.totalReviews;
    final description = state.bio.trim().isNotEmpty
        ? state.bio.trim()
        : '$name is a certified trainer with 10+ years of experience '
            'helping clients achieve their fitness goals. Passionate about '
            '${spec.isNotEmpty ? spec.toLowerCase() : 'fitness'}, nutrition, and holistic health.';
    final int age = state.age;
    final double ht = state.height > 10.0 ? state.height / 100.0 : state.height;

    return Scaffold(
      backgroundColor: _ink(context),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(context, ref, state, name, spec, rat, reviews),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildStatsRow(context, age, ht, rat, reviews),
                        const SizedBox(height: 24),
                        _buildAbout(context, description),
                        const SizedBox(height: 20),
                        _buildCertifications(context, state),
                        const SizedBox(height: 20),
                        _buildScheduleSection(context, state),
                        const SizedBox(height: 20),
                        _buildRecentPostsSection(context, ref, controller, state),
                        const SizedBox(height: 24),
                        _buildRatingsSection(context, state),
                        const SizedBox(height: 24),
                        _buildActions(context, state),
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

  Widget _buildHero(
    BuildContext context,
    WidgetRef ref,
    TrainerDetailsState state,
    String name,
    String specialty,
    double rating,
    int reviewCount,
  ) {
    final hasCustomImage = state.imageUrl.isNotEmpty;

    final favourites = ref.watch(favouritesServiceProvider);
    final favNotifier = ref.read(favouritesServiceProvider.notifier);
    final trainerMap = {
      'name': state.trainerName,
      'specialty': state.specialty,
      'rating': state.rating,
      'price': state.pricePerHour,
      'sessions': state.sessions,
      'portrait': state.portrait,
      'available': state.isAvailable,
      'isAvailable': state.isAvailable,
      'image': state.imageUrl,
      'trainerId': state.trainerId,
      'id': state.trainerId,
    };
    final isFav = favourites.any((f) => f['name'] == state.trainerName);

    return Stack(
      children: [
        SizedBox(
          height: 320,
          width: double.infinity,
          child: hasCustomImage
              ? CachedNetworkImage(
                  imageUrl: state.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 1080,
                  memCacheHeight: 640,
                  fadeInDuration: const Duration(milliseconds: 140),
                  errorWidget: (_, __, ___) => _heroFallback(context, name),
                )
              : _heroFallback(context, name),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, _ink(context).withValues(alpha: 0.5), _ink(context)],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _ink(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke(context)),
              ),
              child: Icon(
                CupertinoIcons.back,
                color: _text(context),
                size: 16,
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 16,
          child: GestureDetector(
            onTap: () => favNotifier.toggle(trainerMap),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _ink(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isFav ? coral : _stroke(context)),
              ),
              child: Icon(
                isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                color: isFav ? coral : _text(context),
                size: 18,
              ),
            ),
          ),
        ),
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
                        color: state.isAvailable ? _neon(context) : _raised(context),
                        borderRadius: BorderRadius.circular(7),
                        border: state.isAvailable ? null : Border.all(color: _stroke(context)),
                      ),
                      child: Text(
                        state.isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          color: state.isAvailable ? _ink(context) : _muted(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: TextStyle(
                        color: _text(context),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialty,
                      style: TextStyle(
                        color: _text(context).withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.star_fill, color: _neon(context), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: _text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($reviewCount)',
                      style: TextStyle(color: _muted(context), fontSize: 12),
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

  Widget _heroFallback(BuildContext context, String name) {
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.2),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Text(
            initials,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 54,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, int age, double height, double rating, int reviews) {
    return Row(
      children: [
        _statChip(context, CupertinoIcons.gift, '$age yrs', 'Age', coral),
        const SizedBox(width: 12),
        _statChip(
          context,
          CupertinoIcons.resize_v,
          '${height.toStringAsFixed(2)}m',
          'Height',
          sky,
        ),
        const SizedBox(width: 12),
        _statChip(context, CupertinoIcons.person_3, '$reviews+', 'Clients', lilac),
      ],
    );
  }

  Widget _statChip(BuildContext context, IconData icon, String value, String label, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke(context)),
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
                color: _text(context),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: _muted(context), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildAbout(BuildContext context, String description) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: TextStyle(
            color: _text(context),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            color: _text(context).withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildCertifications(BuildContext context, TrainerDetailsState state) {
    final dynamicSpecializations = state.specializations;
    final dynamicLanguages = state.languages;

    final certs = [
      {
        'icon': CupertinoIcons.checkmark_seal,
        'label': dynamicSpecializations.isNotEmpty
            ? dynamicSpecializations.first
            : 'Certified Personal Trainer (CPT)',
        'color': _neon(context),
      },
      {
        'icon': CupertinoIcons.timer,
        'label': state.experienceYears > 0
            ? '${state.experienceYears} years experience'
            : 'Certified Coach',
        'color': sky,
      },
      {
        'icon': CupertinoIcons.globe,
        'label': dynamicLanguages.isNotEmpty
            ? 'Speaks: ${dynamicLanguages.take(2).join(', ')}'
            : 'Nutrition Specialist',
        'color': coral,
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Certifications',
          style: TextStyle(
            color: _text(context),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...certs.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke(context)),
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
                      color: _text(context),
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

  Widget _buildScheduleSection(BuildContext context, TrainerDetailsState state) {
    final dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dynamicMap = state.availability;

    final schedule = dayOrder.map((day) {
      final item = dynamicMap[day] ?? {'enabled': false, 'start': '09:00', 'end': '18:00'};
      return {
        'day': day,
        'enabled': item['enabled'] == true,
        'start': (item['start'] ?? '09:00').toString(),
        'end': (item['end'] ?? '18:00').toString(),
      };
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Schedule',
              style: TextStyle(
                color: _text(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text('This week', style: TextStyle(color: _muted(context), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: schedule.map((item) {
            final enabled = item['enabled'] == true;
            return Container(
              width: 94,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: enabled ? _neon(context).withValues(alpha: 0.08) : _card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: enabled ? _neon(context).withValues(alpha: 0.28) : _stroke(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['day'] as String,
                    style: TextStyle(
                      color: _text(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enabled ? 'Open' : 'Off',
                    style: TextStyle(
                      color: enabled ? _neon(context) : _muted(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${item['start']} - ${item['end']}',
                      style: TextStyle(color: _muted(context), fontSize: 10),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentPostsSection(
    BuildContext context,
    WidgetRef ref,
    TrainerDetailsNotifier controller,
    TrainerDetailsState state,
  ) {
    final posts = state.recentPosts;
    if (posts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Posts',
          style: TextStyle(
            color: _text(context),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...posts.take(3).map((post) {
          final title = (post['title'] ?? '').toString();
          final caption = (post['caption'] ?? '').toString();
          final imageUrl = (post['imageUrl'] ?? '').toString();
          final category = (post['category'] ?? 'Workout').toString();
          final likes = post['likesCount'] ?? 0;
          final comments = post['commentsCount'] ?? 0;
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final likedBy = List<String>.from(post['likedBy'] ?? <dynamic>[]);
          final isLiked = currentUid != null && likedBy.contains(currentUid);
          final postId = (post['id'] ?? post['postId'] ?? '').toString();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sky.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: sky,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: _text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text(context).withValues(alpha: 0.72),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 720,
                        memCacheHeight: 240,
                        fadeInDuration: const Duration(milliseconds: 120),
                        errorWidget: (_, __, ___) => Container(
                          height: 120,
                          color: _raised(context),
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.photo,
                            color: _text(context).withOpacity(0.55),
                            size: 24,
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
                          if (postId.isNotEmpty) {
                            controller.togglePostLike(postId);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                color: isLiked ? coral : _muted(context),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                likes.toString(),
                                style: TextStyle(
                                  color: isLiked ? coral : _muted(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
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
                                trainerName: state.trainerName,
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
                              Text(
                                comments.toString(),
                                style: TextStyle(
                                  color: _muted(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions(BuildContext context, TrainerDetailsState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: state.isAvailable
              ? () => context.push(
                    '/book-session',
                    extra: {
                      'name': state.trainerName,
                      'specialty': state.specialty,
                      'portrait': state.portrait,
                      'price': state.pricePerHour,
                      'trainerId': state.trainerId,
                      'image': state.imageUrl,
                      'rating': state.rating,
                    },
                  )
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: state.isAvailable ? _neon(context) : _raised(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                state.isAvailable ? 'Book a Session' : 'Unavailable',
                style: TextStyle(
                  color: state.isAvailable ? _ink(context) : _muted(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  context.push('/message-screen', extra: {
                    'name': state.trainerName,
                    'specialty': state.specialty,
                    'portrait': state.portrait,
                    'isAvailable': state.isAvailable,
                    'otherId': state.trainerId,
                    'photoUrl': state.imageUrl,
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _stroke(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.chat_bubble,
                        color: _text(context).withValues(alpha: 0.7),
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Message',
                        style: TextStyle(
                          color: _text(context),
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
            Expanded(
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TrainerRatingSheet(
                      trainerId: state.trainerId,
                      trainerName: state.trainerName,
                    ),
                  );
                },
                child: Consumer(
                  builder: (context, ref, _) {
                    final rState = state.trainerId.isNotEmpty
                        ? ref.watch(trainerRatingsProvider(state.trainerId))
                        : null;
                    final hasReview = rState?.myReviewId != null;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: hasReview
                            ? _neon(context).withValues(alpha: 0.1)
                            : _card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasReview
                              ? _neon(context).withValues(alpha: 0.4)
                              : _stroke(context),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasReview
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.star,
                            color: hasReview ? _neon(context) : _text(context).withValues(alpha: 0.7),
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasReview ? 'Edit Review' : 'Review',
                            style: TextStyle(
                              color: hasReview ? _neon(context) : _text(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingsSection(BuildContext context, TrainerDetailsState state) {
    if (state.trainerId.isEmpty) return const SizedBox.shrink();
    return TrainerRatingsSummary(
      trainerId: state.trainerId,
      trainerName: state.trainerName,
    );
  }
}
