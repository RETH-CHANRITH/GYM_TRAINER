import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class TrainerRatingsState {
  final List<Map<String, dynamic>> reviews;
  final double avgRating;
  final int totalReviews;
  final bool isSubmitting;
  final String? myReviewId;
  final double myRating;
  final String myComment;

  const TrainerRatingsState({
    this.reviews = const [],
    this.avgRating = 0.0,
    this.totalReviews = 0,
    this.isSubmitting = false,
    this.myReviewId,
    this.myRating = 0,
    this.myComment = '',
  });

  TrainerRatingsState copyWith({
    List<Map<String, dynamic>>? reviews,
    double? avgRating,
    int? totalReviews,
    bool? isSubmitting,
    String? myReviewId,
    double? myRating,
    String? myComment,
  }) =>
      TrainerRatingsState(
        reviews: reviews ?? this.reviews,
        avgRating: avgRating ?? this.avgRating,
        totalReviews: totalReviews ?? this.totalReviews,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        myReviewId: myReviewId ?? this.myReviewId,
        myRating: myRating ?? this.myRating,
        myComment: myComment ?? this.myComment,
      );

  /// How many reviews for each star (5..1)
  Map<int, int> get distribution {
    final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final v = (r['rating'] as num?)?.round().clamp(1, 5) ?? 0;
      if (v >= 1) dist[v] = (dist[v] ?? 0) + 1;
    }
    return dist;
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TrainerRatingsNotifier extends StateNotifier<TrainerRatingsState> {
  final String trainerId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _sub;

  TrainerRatingsNotifier(this.trainerId) : super(const TrainerRatingsState()) {
    if (trainerId.isNotEmpty) _listen();
  }

  void _listen() {
    _sub = _db
        .collection('reviews')
        .where('trainerId', isEqualTo: trainerId)
        .snapshots()
        .listen((snap) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final reviews = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Sort in memory by createdAt descending to avoid composite index requirements
      reviews.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      // Compute avg
      final values = reviews
          .map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0)
          .where((v) => v > 0)
          .toList();
      final avg = values.isEmpty
          ? 0.0
          : values.reduce((a, b) => a + b) / values.length;

      // Find own review
      Map<String, dynamic>? mine;
      if (uid != null) {
        try {
          mine = reviews.firstWhere((r) => r['userId'] == uid);
        } catch (_) {
          mine = null;
        }
      }

      state = state.copyWith(
        reviews: reviews,
        avgRating: avg,
        totalReviews: reviews.length,
        myReviewId: mine?['id'] as String?,
        myRating: mine != null
            ? (mine['rating'] as num?)?.toDouble() ?? 0
            : state.myRating,
        myComment: mine != null
            ? (mine['comment'] ?? '').toString()
            : state.myComment,
      );
    }, onError: (_) {});
  }

  /// Submit or update the current user's rating.
  Future<String?> submitRating({
    required double rating,
    required String comment,
    required String userName,
    required String userPhoto,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'Not signed in';
    if (rating == 0) return 'Please select a star rating';
    if (trainerId.isEmpty) return 'Invalid trainer';

    state = state.copyWith(isSubmitting: true);

    try {
      final payload = {
        'trainerId': trainerId,
        'userId': uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'rating': rating,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final existingId = state.myReviewId;
      if (existingId != null && existingId.isNotEmpty) {
        // Update existing
        await _db.collection('reviews').doc(existingId).update(payload);
      } else {
        // Create new
        final ref = await _db.collection('reviews').add(payload);
        state = state.copyWith(myReviewId: ref.id);
      }

      // Send notification to trainer
      if (trainerId != uid) {
        await _db
            .collection('notifications')
            .doc(trainerId)
            .collection('items')
            .add({
          'title': existingId != null && existingId.isNotEmpty ? 'Review Updated' : 'New Review',
          'body': '$userName rated you ${rating.toStringAsFixed(1)} stars',
          'type': 'review',
          'color': 'gold',
          'icon': 'review',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': uid,
          'senderName': userName,
          'senderPhotoUrl': userPhoto,
        });
      }

      // Persist avg back to trainer's user doc (optional — trainer dashboard also computes it)
      _updateTrainerAvgRating();

      state = state.copyWith(isSubmitting: false);
      return null; // success
    } catch (e) {
      state = state.copyWith(isSubmitting: false);
      return e.toString();
    }
  }

  /// Delete the current user's review.
  Future<void> deleteReview() async {
    final id = state.myReviewId;
    if (id == null) return;
    try {
      await _db.collection('reviews').doc(id).delete();
      state = state.copyWith(
        myReviewId: null,
        myRating: 0,
        myComment: '',
      );
      _updateTrainerAvgRating();
    } catch (_) {}
  }

  void _updateTrainerAvgRating() async {
    if (trainerId.isEmpty) return;
    try {
      // Re-read from Firestore and compute fresh avg
      final snap = await _db
          .collection('reviews')
          .where('trainerId', isEqualTo: trainerId)
          .get();
      final vals = snap.docs
          .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
          .where((v) => v > 0)
          .toList();
      final avg =
          vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
      await _db.collection('users').doc(trainerId).update({
        'rating': avg,
        'reviewsCount': snap.docs.length,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final trainerRatingsProvider = StateNotifierProvider.family<
    TrainerRatingsNotifier, TrainerRatingsState, String>((ref, trainerId) {
  return TrainerRatingsNotifier(trainerId);
});
