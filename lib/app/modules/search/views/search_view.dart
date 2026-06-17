import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/search_controller.dart' as sc;
import '../../../services/favourites_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/views/post_comments_sheet.dart';

const Color coral = Color(0xFFFF5C5C);
const Color sky = Color(0xFF5CE8FF);
const Color lilac = Color(0xFFA78BFA);

class SearchView extends ConsumerWidget {
  const SearchView({super.key});

  Color _ink(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color _card(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color _raised(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color _stroke(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color _text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
  Color _muted(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color _neon(BuildContext context) => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(sc.searchNotifierProvider);
    final controller = ref.read(sc.searchNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: _ink(context),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, searchState),
                const SizedBox(height: 16),
                _buildSearchBar(context, controller),
                const SizedBox(height: 16),
                _buildSpecialtyChips(context, searchState, controller),
                const SizedBox(height: 16),
                Expanded(child: _buildResults(context, ref, searchState, controller)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, sc.SearchState searchState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke(context)),
              ),
              child: Icon(
                CupertinoIcons.back,
                color: _text(context),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Trainers',
                  style: TextStyle(
                    color: _text(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                Text(
                  '${searchState.filtered.length} trainers • ${searchState.filteredPosts.length} posts',
                  style: TextStyle(color: _muted(context), fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke(context)),
              ),
              child: Icon(
                CupertinoIcons.slider_horizontal_3,
                color: _text(context),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, sc.SearchNotifier controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        onChanged: controller.setQuery,
        style: TextStyle(color: _text(context)),
        decoration: InputDecoration(
          hintText: 'Search by name or specialty…',
          hintStyle: TextStyle(color: _muted(context)),
          prefixIcon: Icon(CupertinoIcons.search, color: _muted(context), size: 20),
          filled: true,
          fillColor: _card(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _stroke(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _stroke(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _neon(context), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyChips(BuildContext context, sc.SearchState searchState, sc.SearchNotifier controller) {
    final activeSpec = searchState.selectedSpecialty;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: controller.specialties.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final spec = controller.specialties[i];
          final active = activeSpec == spec;
          return GestureDetector(
            onTap: () => controller.setSpecialty(spec),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: active ? _neon(context) : _card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? _neon(context) : _stroke(context),
                  width: active ? 2 : 1,
                ),
              ),
              child: Text(
                spec,
                style: TextStyle(
                  color: active ? _ink(context) : _muted(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    WidgetRef ref,
    sc.SearchState searchState,
    sc.SearchNotifier controller,
  ) {
    final trainers = searchState.filtered;
    final posts = searchState.filteredPosts;

    if (searchState.isLoading && trainers.isEmpty && posts.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _neon(context)));
    }

    if (trainers.isEmpty && posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.search, color: _muted(context), size: 52),
            const SizedBox(height: 14),
            Text(
              'No trainers or posts match your search',
              style: TextStyle(color: _muted(context), fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: trainers.length + posts.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _buildSectionTitle(context, 'Trainers', trainers.length);
        }

        final trainerEnd = 1 + trainers.length;
        if (i < trainerEnd) {
          return _buildTrainerCard(context, ref, trainers[i - 1]);
        }

        if (i == trainerEnd) {
          return _buildSectionTitle(context, 'Trainer Posts', posts.length);
        }

        return _buildPostCard(context, ref, controller, posts[i - trainerEnd - 1]);
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: _text(context),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text('($count)', style: TextStyle(color: _muted(context), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTrainerCard(BuildContext context, WidgetRef ref, Map<String, dynamic> t) {
    final isAvailable = t['isAvailable'] == true;
    final trainerImage = (t['image'] ?? '').toString();
    final favourites = ref.watch(favouritesServiceProvider);
    final favNotifier = ref.read(favouritesServiceProvider.notifier);
    final trainerName = (t['name'] ?? 'Trainer').toString();
    final isFav = favourites.any((f) => f['name'] == trainerName);

    return GestureDetector(
      onTap: () => context.push('/trainer-details', extra: t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _card(context),
              _card(context).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _stroke(context).withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with Available indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAvailable ? _neon(context).withValues(alpha: 0.35) : _stroke(context),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PremiumAvatar(
                      name: trainerName,
                      customPhotoUrl: trainerImage,
                      size: 68,
                      borderRadius: 16,
                      isTrainer: true,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isAvailable ? _neon(context) : _muted(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: _card(context), width: 3),
                      boxShadow: isAvailable
                          ? [
                              BoxShadow(
                                color: _neon(context).withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Trainer Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trainerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (t['specialty'] ?? 'Personal Training').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Rating & Sessions in nice subtle pill badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _neon(context).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _neon(context).withValues(alpha: 0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.star_fill,
                              color: _neon(context),
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${t['rating'] ?? 0}',
                              style: TextStyle(
                                color: _neon(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _raised(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _stroke(context), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.sportscourt_fill,
                              color: sky,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${t['sessions'] ?? 0} sessions',
                              style: TextStyle(
                                color: _text(context).withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Price & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textBaseline: TextBaseline.alphabetic,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Text(
                      '\$${t['price'] ?? t['pricePerHour'] ?? 0}',
                      style: TextStyle(
                        color: _text(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '/h',
                      style: TextStyle(
                        color: _muted(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Book & Favorite Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => favNotifier.toggle(t),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isFav ? coral.withValues(alpha: 0.12) : _raised(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFav ? coral.withValues(alpha: 0.5) : _stroke(context),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                          color: isFav ? coral : _muted(context),
                          size: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _neon(context),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _neon(context).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Book',
                        style: TextStyle(
                          color: _ink(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
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



  Widget _buildPostCard(BuildContext context, WidgetRef ref, sc.SearchNotifier controller, Map<String, dynamic> post) {
    final trainerName = (post['trainerName'] ?? post['authorName'] ?? 'Trainer').toString();
    final trainerId = (post['trainerId'] ?? post['authorId'] ?? '').toString();

    // Dynamically look up trainer profile image
    final searchState = ref.watch(sc.searchNotifierProvider);
    Map<String, dynamic>? trainer;
    for (final t in searchState.allTrainers) {
      if ((t['trainerId'] ?? t['id']).toString() == trainerId ||
          (t['name'] ?? '').toString().toLowerCase() == trainerName.toLowerCase()) {
        trainer = t;
        break;
      }
    }
    final trainerImage = trainer?['image'] ?? post['trainerPhotoUrl'] ?? '';
    final trainerSpecialty = trainer?['specialty'] ?? 'Fitness Coach';

    final title = (post['title'] ?? '').toString().trim();
    final caption = (post['caption'] ?? '').toString().trim();
    final category = (post['category'] ?? 'Workout').toString();
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final likes = post['likesCount'] ?? 0;
    final comments = post['commentsCount'] ?? 0;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final likedBy = List<String>.from(post['likedBy'] ?? <dynamic>[]);
    final isLiked = currentUid != null && likedBy.contains(currentUid);
    final postId = (post['id'] ?? post['postId'] ?? '').toString();
    final tags = (post['tags'] is List)
        ? (post['tags'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return GestureDetector(
      onTap: () => controller.openTrainerFromPost(context, post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _stroke(context).withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Author/Header Header Row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _neon(context).withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.5),
                    child: PremiumAvatar(
                      name: trainerName,
                      customPhotoUrl: trainerImage.toString(),
                      size: 40,
                      borderRadius: 10.5,
                      isTrainer: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        trainerName,
                        style: TextStyle(
                          color: _text(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trainerSpecialty,
                        style: TextStyle(
                          color: _muted(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: sky.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sky.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: sky,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (title.isNotEmpty)
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _text(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            if (title.isNotEmpty) const SizedBox(height: 6),
            Text(
              caption.isNotEmpty ? caption : 'Trainer update',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text(context).withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                     imageUrl: imageUrl,
                     fit: BoxFit.cover,
                     placeholder: (_, __) => Container(
                       color: _raised(context),
                       child: Center(
                         child: CupertinoActivityIndicator(color: _neon(context)),
                       ),
                     ),
                     errorWidget: (_, __, ___) => Container(
                       color: _raised(context),
                       child: Icon(
                         CupertinoIcons.photo,
                         color: _text(context).withOpacity(0.55),
                       ),
                     ),
                  ),
                ),
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .take(4)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: lilac.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: lilac.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            color: lilac,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            // Premium Action Row
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
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                          color: isLiked ? coral : _muted(context),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$likes',
                          style: TextStyle(
                            color: isLiked ? coral : _text(context).withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: isLiked ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
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
                          trainerName: trainerName,
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.chat_bubble,
                          color: sky,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$comments',
                          style: TextStyle(
                            color: _text(context).withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Profile',
                      style: TextStyle(
                        color: _neon(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.chevron_right, color: _neon(context), size: 12),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
