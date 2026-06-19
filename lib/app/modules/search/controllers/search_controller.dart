import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/post_interaction_service.dart';

class SearchState {
  final String query;
  final String selectedSpecialty;
  final double minRating;
  final double maxPrice;
  final bool isLoading;
  final List<Map<String, dynamic>> allTrainers;
  final List<Map<String, dynamic>> allPosts;
  final List<Map<String, dynamic>> filtered;
  final List<Map<String, dynamic>> filteredPosts;

  SearchState({
    required this.query,
    required this.selectedSpecialty,
    required this.minRating,
    required this.maxPrice,
    required this.isLoading,
    required this.allTrainers,
    required this.allPosts,
    required this.filtered,
    required this.filteredPosts,
  });

  SearchState copyWith({
    String? query,
    String? selectedSpecialty,
    double? minRating,
    double? maxPrice,
    bool? isLoading,
    List<Map<String, dynamic>>? allTrainers,
    List<Map<String, dynamic>>? allPosts,
    List<Map<String, dynamic>>? filtered,
    List<Map<String, dynamic>>? filteredPosts,
  }) {
    return SearchState(
      query: query ?? this.query,
      selectedSpecialty: selectedSpecialty ?? this.selectedSpecialty,
      minRating: minRating ?? this.minRating,
      maxPrice: maxPrice ?? this.maxPrice,
      isLoading: isLoading ?? this.isLoading,
      allTrainers: allTrainers ?? this.allTrainers,
      allPosts: allPosts ?? this.allPosts,
      filtered: filtered ?? this.filtered,
      filteredPosts: filteredPosts ?? this.filteredPosts,
    );
  }
}

class SearchNotifier extends AutoDisposeNotifier<SearchState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, Map<String, dynamic>> _trainerUsersByUid = {};
  final Map<String, Map<String, dynamic>> _trainerProfilesByUid = {};
  final Map<String, List<double>> _trainerRatings = {};

  final List<String> specialties = const [
    'All',
    'Strength',
    'Yoga',
    'Cardio',
    'Boxing',
    'Pilates',
    'Powerlifting',
  ];

  @override
  SearchState build() {
    ref.onDispose(() {
      for (final sub in _subs) {
        sub.cancel();
      }
    });

    _listenTrainersRealtime();
    _listenPostsRealtime();

    return SearchState(
      query: '',
      selectedSpecialty: 'All',
      minRating: 0.0,
      maxPrice: 1000.0,
      isLoading: true,
      allTrainers: [],
      allPosts: [],
      filtered: [],
      filteredPosts: [],
    );
  }

  void _listenTrainersRealtime() {
    _subs.add(
      _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .limit(250)
          .snapshots()
          .listen(
            (snap) {
              _trainerUsersByUid.clear();
              _trainerUsersByUid.addEntries(snap.docs.map((d) => MapEntry(d.id, d.data())));
              _rebuildTrainerCatalog();
            },
            onError: (_) {
              state = state.copyWith(isLoading: false);
            },
          ),
    );

    _subs.add(
      _firestore
          .collection('trainerProfiles')
          .limit(250)
          .snapshots()
          .listen(
            (snap) {
              _trainerProfilesByUid.clear();
              _trainerProfilesByUid.addEntries(snap.docs.map((d) => MapEntry(d.id, d.data())));
              _rebuildTrainerCatalog();
            },
            onError: (_) {
              state = state.copyWith(isLoading: false);
            },
          ),
    );

    _subs.add(
      _firestore.collection('reviews').snapshots().listen(
        (snap) {
          _trainerRatings.clear();
          for (final doc in snap.docs) {
            final data = doc.data();
            final tId = (data['trainerId'] ?? '').toString().trim();
            final rVal = (data['rating'] as num?)?.toDouble() ?? 0.0;
            if (tId.isNotEmpty && rVal > 0) {
              _trainerRatings.putIfAbsent(tId, () => []).add(rVal);
            }
          }
          _rebuildTrainerCatalog();
        },
        onError: (_) {
          state = state.copyWith(isLoading: false);
        },
      ),
    );
  }

  void _listenPostsRealtime() {
    _subs.add(
      _firestore
          .collection('trainerPosts')
          .where('isActive', isEqualTo: true)
          .limit(160)
          .snapshots()
          .listen(
            (snap) {
              final mapped = snap.docs
                  .map((d) => {'id': d.id, ...d.data()})
                  .toList(growable: false);
              mapped.sort(
                (a, b) => _toEpochMs(
                  b['createdAt'] ?? b['createdAtClient'],
                ).compareTo(_toEpochMs(a['createdAt'] ?? a['createdAtClient'])),
              );
              state = state.copyWith(allPosts: mapped, isLoading: false);
              _recompute();
            },
            onError: (_) {
              state = state.copyWith(isLoading: false);
            },
          ),
    );
  }

  void _rebuildTrainerCatalog() {
    final merged = <Map<String, dynamic>>[];

    for (final entry in _trainerUsersByUid.entries) {
      final uid = entry.key;
      final user = entry.value;
      final profile = _trainerProfilesByUid[uid] ?? const <String, dynamic>{};

      final name =
          (user['name'] ?? user['fullName'] ?? user['displayName'] ?? '')
              .toString()
              .trim();
      if (name.isEmpty) continue;

      final specs =
          (profile['specializations'] is List)
              ? (profile['specializations'] as List)
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : <String>[];

      final sessionPrice = _toInt(profile['sessionPrice']);

      final ratingsList = _trainerRatings[uid] ?? [];
      final computedAvg = ratingsList.isEmpty
          ? 0.0
          : ratingsList.reduce((a, b) => a + b) / ratingsList.length;

      final reviewCount = ratingsList.isNotEmpty ? ratingsList.length : _toInt(user['reviewsCount']);
      final rating = computedAvg > 0 ? computedAvg : _toDouble(user['rating']);

      merged.add({
        'id': uid,
        'trainerId': uid,
        'name': name,
        'specialty': specs.isNotEmpty ? specs.first : 'Personal Training',
        'specializations': specs,
        'rating': rating > 0 ? rating : 4.7,
        'reviews': reviewCount,
        'sessions': _toInt(user['sessionsCount']),
        'price': sessionPrice > 0 ? sessionPrice : 40,
        'pricePerHour': sessionPrice > 0 ? sessionPrice : 40,
        'isAvailable': _isProfileAvailable(profile, user['isActive']),
        'bio': (profile['bio'] ?? '').toString(),
        'image': (profile['photoUrl'] ?? user['photoUrl'] ?? '').toString(),
      });
    }

    state = state.copyWith(allTrainers: merged, isLoading: false);
    _recompute();
  }

  void _recompute() {
    final rawQuery = state.query.trim().toLowerCase();
    final spec = state.selectedSpecialty.toLowerCase();

    final filteredTrainers = state.allTrainers.where((t) {
      final name = (t['name'] ?? '').toString().toLowerCase();
      final specialty = (t['specialty'] ?? '').toString().toLowerCase();
      final extraSpecs =
          (t['specializations'] is List)
              ? (t['specializations'] as List)
                  .map((e) => e.toString().toLowerCase())
                  .join(' ')
              : '';
      final searchBlob = '$name $specialty $extraSpecs';

      final matchQuery = rawQuery.isEmpty || searchBlob.contains(rawQuery);
      final matchSpecialty =
          spec == 'all' ||
          specialty.contains(spec) ||
          extraSpecs.contains(spec);
      final matchRating = _toDouble(t['rating']) >= state.minRating;
      final matchPrice =
          _toDouble(t['pricePerHour'] ?? t['price']) <= state.maxPrice;
      return matchQuery && matchSpecialty && matchRating && matchPrice;
    }).toList();

    final filteredPostsList = state.allPosts.where((post) {
      final trainer = findTrainerForPost(post);
      final trainerSpec =
          (trainer?['specialty'] ?? post['category'] ?? '').toString();
      final trainerRating = _toDouble(trainer?['rating']);
      final trainerPrice = _toDouble(
        trainer?['pricePerHour'] ?? trainer?['price'],
      );

      final tags =
          (post['tags'] is List)
              ? (post['tags'] as List).map((e) => e.toString()).join(' ')
              : '';
      final postBlob =
          [
            (post['title'] ?? '').toString(),
            (post['caption'] ?? '').toString(),
            (post['category'] ?? '').toString(),
            tags,
            (post['trainerName'] ?? '').toString(),
            trainerSpec,
          ].join(' ').toLowerCase();

      final matchQuery = rawQuery.isEmpty || postBlob.contains(rawQuery);
      final matchSpecialty =
          spec == 'all' || trainerSpec.toLowerCase().contains(spec);
      final matchRating =
          trainer == null || trainerRating >= state.minRating;
      final matchPrice = trainer == null || trainerPrice <= state.maxPrice;

      return matchQuery && matchSpecialty && matchRating && matchPrice;
    }).toList();

    state = state.copyWith(filtered: filteredTrainers, filteredPosts: filteredPostsList);
  }

  Map<String, dynamic>? findTrainerForPost(Map<String, dynamic> post) {
    final trainerId = (post['trainerId'] ?? '').toString().trim();
    final trainerName = (post['trainerName'] ?? '').toString().trim();

    if (trainerId.isNotEmpty) {
      final byId = state.allTrainers.firstWhereOrNull(
        (t) => (t['trainerId'] ?? t['id']).toString() == trainerId,
      );
      if (byId != null) return byId;
    }

    if (trainerName.isNotEmpty) {
      return state.allTrainers.firstWhereOrNull(
        (t) =>
            (t['name'] ?? '').toString().trim().toLowerCase() ==
            trainerName.toLowerCase(),
      );
    }

    return null;
  }

  void openTrainerFromPost(BuildContext context, Map<String, dynamic> post) {
    final trainer = findTrainerForPost(post);
    if (trainer != null) {
      context.push('/trainer-details', extra: trainer);
      return;
    }

    final trainerId = (post['trainerId'] ?? '').toString().trim();
    final trainerName = (post['trainerName'] ?? 'Trainer').toString().trim();

    context.push(
      '/trainer-details',
      extra: {
        'id': trainerId,
        'trainerId': trainerId,
        'name': trainerName,
        'specialty': (post['category'] ?? 'Personal Training').toString(),
        'image': (post['trainerPhotoUrl'] ?? post['imageUrl'] ?? '').toString(),
        'isAvailable': true,
      },
    );
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
    _recompute();
  }

  void setSpecialty(String s) {
    state = state.copyWith(selectedSpecialty: s);
    _recompute();
  }

  void setMinRating(double rating) {
    state = state.copyWith(minRating: rating);
    _recompute();
  }

  void setMaxPrice(double price) {
    state = state.copyWith(maxPrice: price);
    _recompute();
  }

  bool _isProfileAvailable(Map<String, dynamic> profile, dynamic fallback) {
    final raw = profile['availability'];
    if (raw is Map) {
      for (final day in raw.values) {
        if (day is Map && day['enabled'] == true) {
          return true;
        }
      }
    }
    return fallback == true;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

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

  Future<void> togglePostLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final updatedPosts = state.allPosts.map((post) {
      if ((post['id'] ?? post['postId'] ?? '').toString() == postId) {
        final likedBy = List<String>.from(post['likedBy'] ?? <dynamic>[]);
        final currentCount = post['likesCount'] ?? 0;
        final isLiked = likedBy.contains(uid);

        final newLikedBy = List<String>.from(likedBy);
        int newCount = currentCount;

        if (isLiked) {
          newLikedBy.remove(uid);
          newCount = (newCount - 1).clamp(0, 999999);
        } else {
          newLikedBy.add(uid);
          newCount = newCount + 1;
        }

        return {
          ...post,
          'likedBy': newLikedBy,
          'likesCount': newCount,
        };
      }
      return post;
    }).toList();

    state = state.copyWith(allPosts: updatedPosts);
    _recompute();

    try {
      await ref.read(postInteractionServiceProvider).toggleLike(postId);
    } catch (_) {}
  }
}

final searchNotifierProvider = AutoDisposeNotifierProvider<SearchNotifier, SearchState>(() {
  return SearchNotifier();
});

extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
