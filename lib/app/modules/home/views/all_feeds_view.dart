import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../config/glass_ui.dart';
import '../controllers/home_controller.dart';
import 'post_comments_sheet.dart';

final allTrainerPostsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('trainerPosts')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) {
        final posts = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        posts.sort((a, b) {
          final aTime = _toEpochMs(a['createdAt'] ?? a['createdAtClient']);
          final bTime = _toEpochMs(b['createdAt'] ?? b['createdAtClient']);
          return bTime.compareTo(aTime);
        });
        return posts;
      });
});

int _toEpochMs(dynamic raw) {
  if (raw is Timestamp) return raw.millisecondsSinceEpoch;
  if (raw is DateTime) return raw.millisecondsSinceEpoch;
  if (raw is int) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}

class AllFeedsView extends ConsumerWidget {
  const AllFeedsView({super.key});

  Color _ink(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color _surface(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFE5E7EB);
  Color _card(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color _raised(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color _stroke(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color _neon(BuildContext context) => Theme.of(context).colorScheme.primary;
  Color _coral(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF5C5C) : const Color(0xFFFF4F4F);
  Color _sky(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5CE8FF) : const Color(0xFF06B6D4);
  Color _lilac(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  Color _muted(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black54;
  Color _text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(allTrainerPostsProvider);
    final homeState = ref.watch(homeNotifierProvider);
    final controller = ref.read(homeNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: _ink(context),
      appBar: AppBar(
        backgroundColor: _surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: _text(context)),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Trainer Feed',
          style: GoogleFonts.dmSans(
            color: _text(context),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          postsAsync.when(
            loading: () => Center(
              child: CupertinoActivityIndicator(color: _neon(context)),
            ),
            error: (err, stack) => Center(
              child: Text(
                'Failed to load feeds',
                style: GoogleFonts.dmSans(color: _muted(context)),
              ),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text,
                        color: _muted(context),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No feed posts available yet',
                        style: GoogleFonts.dmSans(color: _muted(context), fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  return _buildFeedPostCard(
                    context,
                    ref,
                    homeState,
                    controller,
                    posts[index],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPostCard(
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _stroke(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _neon(context).withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: PremiumAvatar(
                    name: name,
                    customPhotoUrl: trainerImageUrl,
                    size: 40,
                    borderRadius: 10.5,
                    isTrainer: true,
                  ),
                ),
                const SizedBox(width: 10),
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
                          color: _text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: _muted(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _sky(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _sky(context).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.dmSans(
                      color: _sky(context),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (postImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: postImageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildPlaceholderPostBg(context),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 140,
                  child: _buildPlaceholderPostBg(context),
                ),
              ),
            const SizedBox(height: 14),

            if (title.isNotEmpty) ...[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _text(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],

            Text(
              caption.isNotEmpty ? caption : 'Tap to read this post from $name.',
              style: GoogleFonts.dmSans(
                color: _text(context).withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

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
                              color: isLiked ? _coral(context) : _muted(context),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              likes.toString(),
                              style: GoogleFonts.dmSans(
                                color: isLiked ? _coral(context) : _muted(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
                              trainerName: name,
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.chat_bubble, color: _sky(context), size: 16),
                            const SizedBox(width: 6),
                            StreamBuilder<QuerySnapshot>(
                              stream: postId.isNotEmpty
                                  ? FirebaseFirestore.instance
                                      .collection('trainerPosts')
                                      .doc(postId)
                                      .collection('comments')
                                      .snapshots()
                                  : const Stream.empty(),
                              builder: (context, snap) {
                                int total = comments;
                                if (snap.hasData) {
                                  final docs = snap.data!.docs;
                                  total = docs.fold(0, (sum, doc) {
                                    final data = doc.data() as Map<String, dynamic>? ?? {};
                                    final replyCount = (data['repliesCount'] as num?)?.toInt() ?? 0;
                                    return sum + 1 + replyCount;
                                  });
                                }
                                return Text(
                                  total.toString(),
                                  style: GoogleFonts.dmSans(
                                    color: _muted(context),
                                    fontSize: 11,
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
                    color: _neon(context),
                    fontSize: 11,
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

  Widget _buildPlaceholderPostBg(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _sky(context).withValues(alpha: 0.05),
            _lilac(context).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.doc_text_fill,
        color: _muted(context).withValues(alpha: 0.24),
        size: 36,
      ),
    );
  }

  String _normalizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}
