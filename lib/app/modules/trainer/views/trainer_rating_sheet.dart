import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/trainer_rating_controller.dart';

/// Beautiful animated rating bottom sheet.
/// Opens when the user taps the "Review" button on TrainerDetailsView.
class TrainerRatingSheet extends ConsumerStatefulWidget {
  final String trainerId;
  final String trainerName;

  const TrainerRatingSheet({
    super.key,
    required this.trainerId,
    required this.trainerName,
  });

  @override
  ConsumerState<TrainerRatingSheet> createState() => _TrainerRatingSheetState();
}

class _TrainerRatingSheetState extends ConsumerState<TrainerRatingSheet>
    with SingleTickerProviderStateMixin {
  Color get ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get coral => const Color(0xFFFF5C5C);
  Color get muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  late AnimationController _anim;
  late Animation<double> _scale;

  double _hoveredStar = 0;
  double _selectedStar = 0;
  final _commentCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();

    // Pre-fill if user already reviewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(trainerRatingsProvider(widget.trainerId));
      if (s.myRating > 0) {
        setState(() {
          _selectedStar = s.myRating;
          _commentCtrl.text = s.myComment;
        });
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_selectedStar == 0) {
      setState(() => _error = 'Please tap a star to rate');
      return;
    }

    // Fetch user display info
    final user = FirebaseAuth.instance.currentUser;
    String userName = user?.displayName ?? 'User';
    String userPhoto = user?.photoURL ?? '';
    if (userName.isEmpty || userName == 'User') {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get();
        final d = doc.data() ?? {};
        userName = (d['name'] ?? d['fullName'] ?? d['displayName'] ?? 'User')
            .toString()
            .trim();
        userPhoto = (d['photoUrl'] ?? '').toString().trim();
      } catch (_) {}
    }

    final error = await ref
        .read(trainerRatingsProvider(widget.trainerId).notifier)
        .submitRating(
          rating: _selectedStar,
          comment: _commentCtrl.text,
          userName: userName,
          userPhoto: userPhoto,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: neon,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Rating submitted successfully!',
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _deleteReview() async {
    await ref
        .read(trainerRatingsProvider(widget.trainerId).notifier)
        .deleteReview();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Review deleted'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: raised,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trainerRatingsProvider(widget.trainerId));
    final isSubmitting = state.isSubmitting;
    final hasExisting = state.myReviewId != null;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Animated star icon
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: neon.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: neon.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  CupertinoIcons.star_fill,
                  color: neon,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              hasExisting ? 'Update Your Review' : 'Rate Your Trainer',
              style: TextStyle(
                color: text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.trainerName,
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 28),

            // ── Star selector ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starVal = i + 1.0;
                final active = (_hoveredStar > 0 ? _hoveredStar : _selectedStar) >= starVal;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStar = starVal),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredStar = starVal),
                    onExit: (_) => setState(() => _hoveredStar = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: AnimatedScale(
                        scale: _selectedStar == starVal ? 1.25 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.elasticOut,
                        child: Icon(
                          active
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star,
                          color: active ? neon : stroke,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // Star label
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                _selectedStar == 0
                    ? 'Tap a star'
                    : _selectedStar == 1
                        ? 'Poor 😞'
                        : _selectedStar == 2
                            ? 'Fair 😐'
                            : _selectedStar == 3
                                ? 'Good 🙂'
                                : _selectedStar == 4
                                    ? 'Great 😊'
                                    : 'Excellent! 🤩',
                key: ValueKey(_selectedStar),
                style: TextStyle(
                  color: _selectedStar == 0 ? muted : neon,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Comment box ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: raised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: stroke),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _commentCtrl,
                maxLines: 4,
                minLines: 2,
                maxLength: 280,
                style: TextStyle(color: text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)…',
                  hintStyle: TextStyle(color: muted, fontSize: 14),
                  border: InputBorder.none,
                  counterStyle: TextStyle(color: muted, fontSize: 11),
                ),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(CupertinoIcons.exclamationmark_circle, color: coral, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: coral, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // ── Submit button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: isSubmitting ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _selectedStar > 0 ? neon : raised,
                    borderRadius: BorderRadius.circular(16),
                    border: _selectedStar > 0
                        ? null
                        : Border.all(color: stroke),
                  ),
                  child: Center(
                    child: isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ink,
                            ),
                          )
                        : Text(
                            hasExisting ? 'Update Review' : 'Submit Rating',
                            style: TextStyle(
                              color: _selectedStar > 0 ? ink : muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // Delete option if user already has a review
            if (hasExisting) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _deleteReview,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: coral.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: coral.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.trash, color: coral, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        'Delete My Review',
                        style: TextStyle(
                          color: coral,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Mini ratings summary widget (used inline on TrainerDetailsView) ──────────

class TrainerRatingsSummary extends ConsumerWidget {
  final String trainerId;
  final String trainerName;

  const TrainerRatingsSummary({
    super.key,
    required this.trainerId,
    required this.trainerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trainerRatingsProvider(trainerId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black45;
    final raised = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final neon = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ratings & Reviews',
              style: TextStyle(
                color: text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => TrainerRatingSheet(
                  trainerId: trainerId,
                  trainerName: trainerName,
                ),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: neon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: neon.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.star_fill,
                        color: neon, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      state.myReviewId != null ? 'Edit Review' : 'Write Review',
                      style: TextStyle(
                        color: neon,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Avg score + distribution ─────────────────────────────────────────
        if (state.totalReviews == 0) ...[
          _emptyState(context, trainerId, trainerName),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big score
              Column(
                children: [
                  Text(
                    state.avgRating.toStringAsFixed(1),
                    style: TextStyle(
                      color: text,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StarRow(rating: state.avgRating, size: 14),
                  const SizedBox(height: 4),
                  Text(
                    '${state.totalReviews} review${state.totalReviews == 1 ? '' : 's'}',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Distribution bars
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    final count = state.distribution[star] ?? 0;
                    final pct = state.totalReviews == 0
                        ? 0.0
                        : count / state.totalReviews;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Text(
                            '$star',
                            style: TextStyle(
                                color: muted, fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          Icon(CupertinoIcons.star_fill,
                              color: neon, size: 10),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOut,
                                height: 6,
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: raised,
                                  valueColor:
                                      AlwaysStoppedAnimation(neon),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$count',
                              style: TextStyle(
                                  color: muted, fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Review cards ──────────────────────────────────────────────────
          ...state.reviews.take(5).map((r) => _ReviewCard(review: r)),
        ],
      ],
    );
  }

  Widget _emptyState(
      BuildContext ctx, String trainerId, String trainerName) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black45;
    final raised = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final neon = Theme.of(ctx).colorScheme.primary;
    final ink = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TrainerRatingSheet(
          trainerId: trainerId,
          trainerName: trainerName,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: neon.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.star, color: neon, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'No reviews yet',
              style: TextStyle(
                color: text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to rate this trainer',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: neon,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Write a Review',
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Individual review card ───────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raisedC = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
    final strokeC = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final textC = isDark ? Colors.white : Colors.black87;
    final mutedC = isDark ? const Color(0xFF6B6B7E) : Colors.black45;

    final name = (review['userName'] ?? 'User').toString();
    final photo = (review['userPhoto'] ?? '').toString();
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = (review['comment'] ?? '').toString().trim();
    final ts = review['createdAt'];
    String date = '';
    if (ts is Timestamp) {
      final d = ts.toDate();
      date = '${d.day}/${d.month}/${d.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: raisedC,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: strokeC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: strokeC,
                backgroundImage:
                    photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white, // avatar initials always on dark bg
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: textC,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: TextStyle(color: mutedC, fontSize: 11),
                      ),
                  ],
                ),
              ),
              _StarRow(rating: rating, size: 12),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: TextStyle(
                color: textC.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Star row helper ──────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;

  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neonC = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final full = i + 1 <= rating;
        final half = !full && (i + 0.5) <= rating;
        return Icon(
          full
              ? CupertinoIcons.star_fill
              : half
                  ? CupertinoIcons.star_lefthalf_fill
                  : CupertinoIcons.star,
          color: neonC,
          size: size,
        );
      }),
    );
  }
}
