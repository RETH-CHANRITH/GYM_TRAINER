import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../config/glass_ui.dart';
import '../../../services/post_interaction_service.dart';

class PostCommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  final String trainerName;

  const PostCommentsSheet({
    super.key,
    required this.postId,
    required this.trainerName,
  });

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}
class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  Color get ink => Theme.of(context).brightness == Brightness.dark ? kInk : const Color(0xFFF9F9FC);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get coral => Theme.of(context).brightness == Brightness.dark ? kCoral : const Color(0xFFEF4444);
  Color get lilac => Theme.of(context).brightness == Brightness.dark ? kLilac : const Color(0xFF7C3AED);
  Color get muted => Theme.of(context).brightness == Brightness.dark ? kMuted : Colors.black45;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String? _trainerId;
  String? _postTitle;
  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _replyingToAuthorId;

  @override
  void initState() {
    super.initState();
    _loadPostOwner();
  }

  Future<void> _loadPostOwner() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trainerPosts')
          .doc(widget.postId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _trainerId = doc.data()?['trainerId']?.toString();
          _postTitle = doc.data()?['title']?.toString();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final interactionService = ref.read(postInteractionServiceProvider);
      if (_replyingToCommentId != null) {
        await interactionService.addCommentReply(
          widget.postId, 
          _replyingToCommentId!, 
          text,
          commentAuthorId: _replyingToAuthorId,
        );
        setState(() {
          _replyingToCommentId = null;
          _replyingToUserName = null;
          _replyingToAuthorId = null;
        });
      } else {
        await interactionService.addComment(
          widget.postId, 
          text,
          trainerId: _trainerId,
          postTitle: _postTitle,
        );
      }
      _commentController.clear();
      // Scroll to top to see the new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteCommentReply(String commentId, String replyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        title: Text('Delete Reply', style: TextStyle(color: text)),
        content: Text(
          'Are you sure you want to delete this reply?',
          style: TextStyle(color: text.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: coral)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final interactionService = ref.read(postInteractionServiceProvider);
        await interactionService.deleteCommentReply(widget.postId, commentId, replyId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete reply: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId, bool isLiked, String commentAuthorId, String commentText) async {
    try {
      final interactionService = ref.read(postInteractionServiceProvider);
      await interactionService.toggleCommentLike(
        widget.postId, 
        commentId,
        isLiked: isLiked,
        commentAuthorId: commentAuthorId,
        commentText: commentText,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like comment: $e')),
        );
      }
    }
  }
  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        title: Text('Delete Comment', style: TextStyle(color: text)),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: text.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: coral)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final interactionService = ref.read(postInteractionServiceProvider);
        await interactionService.deleteComment(widget.postId, commentId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete comment: $e')),
          );
        }
      }
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(' ');
    if (parts.length > 1) {
      final p1 = parts[0];
      final p2 = parts[1];
      if (p1.isNotEmpty && p2.isNotEmpty) {
        return (p1[0] + p2[0]).toUpperCase();
      }
    }
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'U';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    }

    if (dt == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              key: const Key('comment_glow_orb'),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kSky.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.25),
              ),
            ),
          ),
          Column(
            children: [
              // Top drag indicator
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: text.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.dmSans(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'on ${widget.trainerName}\'s post',
                      style: GoogleFonts.dmSans(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: stroke, height: 1),

              // Comments list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trainerPosts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading comments',
                          style: GoogleFonts.dmSans(color: coral),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: neon),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.chat_bubble_2,
                              color: muted.withValues(alpha: 0.4),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No comments yet',
                              style: GoogleFonts.dmSans(
                                color: muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Be the first to share your thoughts!',
                              style: GoogleFonts.dmSans(
                                  color: muted.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final d = docs[index];
                        final data = d.data() as Map<String, dynamic>? ?? {};
                        final commentId = d.id;
                        final authorName = (data['userName'] ?? 'User').toString();
                        final authorPhoto = (data['userPhotoUrl'] ?? '').toString();
                        final commentText = (data['text'] ?? '').toString();
                        final authorId = (data['userId'] ?? '').toString();
                        final initials = _getInitials(authorName);
                        final dateStr = _formatDate(data['createdAt']);

                        final isAuthor = authorId == currentUid;
                        final isTrainerOwner = _trainerId != null && _trainerId == currentUid;
                        final likedByList = List<String>.from(data['likedBy'] ?? <dynamic>[]);
                        final isCommentLiked = currentUid != null && likedByList.contains(currentUid);
                        final commentLikesCount = data['likesCount'] ?? 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isAuthor ? neon.withValues(alpha: 0.4) : stroke,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.5),
                                    child: authorPhoto.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: authorPhoto,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => _buildInitialsBg(initials),
                                          )
                                        : _buildInitialsBg(initials),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            authorName,
                                            style: GoogleFonts.dmSans(
                                              color: isAuthor ? neon : text,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            dateStr,
                                            style: GoogleFonts.dmSans(
                                              color: muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        commentText,
                                        style: GoogleFonts.dmSans(
                                          color: text.withValues(alpha: 0.85),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isAuthor || isTrainerOwner)
                                  IconButton(
                                    icon: Icon(CupertinoIcons.trash, size: 16, color: coral),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteComment(commentId),
                                    tooltip: 'Delete comment',
                                  ),
                              ],
                            ),
                            // Action Row (Like, Reply buttons)
                            Padding(
                              padding: const EdgeInsets.only(left: 50, top: 4),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _toggleCommentLike(commentId, isCommentLiked, authorId, commentText),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCommentLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                          size: 13,
                                          color: isCommentLiked ? coral : muted,
                                        ),
                                        if (commentLikesCount > 0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            commentLikesCount.toString(),
                                            style: GoogleFonts.dmSans(
                                              color: isCommentLiked ? coral : muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _replyingToCommentId = commentId;
                                        _replyingToUserName = authorName;
                                        _replyingToAuthorId = authorId;
                                      });
                                    },
                                    child: Text(
                                      'Reply',
                                      style: GoogleFonts.dmSans(
                                        color: muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Nested Replies StreamBuilder
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('trainerPosts')
                                  .doc(widget.postId)
                                  .collection('comments')
                                  .doc(commentId)
                                  .collection('replies')
                                  .orderBy('createdAt', descending: false)
                                  .snapshots(),
                              builder: (context, repliesSnapshot) {
                                if (!repliesSnapshot.hasData || repliesSnapshot.data!.docs.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final repliesDocs = repliesSnapshot.data!.docs;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 40, top: 8),
                                  child: Column(
                                    children: repliesDocs.map((rd) {
                                      final rdata = rd.data() as Map<String, dynamic>? ?? {};
                                      final replyId = rd.id;
                                      final rAuthorName = (rdata['userName'] ?? 'User').toString();
                                      final rAuthorPhoto = (rdata['userPhotoUrl'] ?? '').toString();
                                      final rText = (rdata['text'] ?? '').toString();
                                      final rAuthorId = (rdata['userId'] ?? '').toString();
                                      final rInitials = _getInitials(rAuthorName);
                                      final rDateStr = _formatDate(rdata['createdAt']);
                                      final isReplyAuthor = rAuthorId == currentUid;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Smaller Avatar
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isReplyAuthor ? neon.withValues(alpha: 0.4) : stroke,
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6.8),
                                                child: rAuthorPhoto.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: rAuthorPhoto,
                                                        fit: BoxFit.cover,
                                                        errorWidget: (_, __, ___) => _buildInitialsBg(rInitials),
                                                      )
                                                    : _buildInitialsBg(rInitials),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Reply Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        rAuthorName,
                                                        style: GoogleFonts.dmSans(
                                                          color: isReplyAuthor ? neon : text,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        rDateStr,
                                                        style: GoogleFonts.dmSans(
                                                          color: muted,
                                                          fontSize: 9,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    rText,
                                                    style: GoogleFonts.dmSans(
                                                      color: text.withValues(alpha: 0.8),
                                                      fontSize: 12,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isReplyAuthor || isTrainerOwner)
                                              IconButton(
                                                icon: Icon(CupertinoIcons.trash, size: 14, color: coral),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _deleteCommentReply(commentId, replyId),
                                                tooltip: 'Delete reply',
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Divider(color: stroke, height: 1),
              
              if (_replyingToCommentId != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        'Replying to ',
                        style: GoogleFonts.dmSans(color: muted, fontSize: 12),
                      ),
                      Text(
                        '@$_replyingToUserName',
                        style: GoogleFonts.dmSans(
                          color: lilac,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyingToCommentId = null;
                            _replyingToUserName = null;
                            _replyingToAuthorId = null;
                          });
                        },
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: muted,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Bottom Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: text.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: text.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _commentController,
                          style: GoogleFonts.dmSans(color: text, fontSize: 14),
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: _replyingToCommentId != null
                                ? 'Reply to @$_replyingToUserName...'
                                : 'Add a comment...',
                            hintStyle: TextStyle(color: muted, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _submitComment,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [neon, kSky],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: _isSending
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  color: ink,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                CupertinoIcons.arrow_up,
                                color: ink,
                                size: 18,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsBg(String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [const Color(0xFF2E2E3A), const Color(0xFF1C1C26)]
              : [const Color(0xFFE5E7EB), const Color(0xFFD1D5DB)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(
          color: text.withValues(alpha: 0.7),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
