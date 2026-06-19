import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/post_interaction_service.dart';

class TrainerDetailsState {
  final String trainerName;
  final String specialty;
  final double rating;
  final int reviewCount;
  final int pricePerHour;
  final int sessions;
  final int portrait;
  final String imageUrl;
  final bool isAvailable;
  final String trainerId;
  final String bio;
  final List<String> specializations;
  final List<String> languages;
  final List<String> sessionLocations;
  final Map<String, Map<String, dynamic>> availability;
  final List<Map<String, dynamic>> recentPosts;
  final int age;
  final double height;
  final int experienceYears;

  TrainerDetailsState({
    required this.trainerName,
    required this.specialty,
    required this.rating,
    required this.reviewCount,
    required this.pricePerHour,
    required this.sessions,
    required this.portrait,
    required this.imageUrl,
    required this.isAvailable,
    required this.trainerId,
    required this.bio,
    required this.specializations,
    required this.languages,
    required this.sessionLocations,
    required this.availability,
    required this.recentPosts,
    required this.age,
    required this.height,
    required this.experienceYears,
  });

  TrainerDetailsState copyWith({
    String? trainerName,
    String? specialty,
    double? rating,
    int? reviewCount,
    int? pricePerHour,
    int? sessions,
    int? portrait,
    String? imageUrl,
    bool? isAvailable,
    String? trainerId,
    String? bio,
    List<String>? specializations,
    List<String>? languages,
    List<String>? sessionLocations,
    Map<String, Map<String, dynamic>>? availability,
    List<Map<String, dynamic>>? recentPosts,
    int? age,
    double? height,
    int? experienceYears,
  }) {
    return TrainerDetailsState(
      trainerName: trainerName ?? this.trainerName,
      specialty: specialty ?? this.specialty,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      sessions: sessions ?? this.sessions,
      portrait: portrait ?? this.portrait,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      trainerId: trainerId ?? this.trainerId,
      bio: bio ?? this.bio,
      specializations: specializations ?? this.specializations,
      languages: languages ?? this.languages,
      sessionLocations: sessionLocations ?? this.sessionLocations,
      availability: availability ?? this.availability,
      recentPosts: recentPosts ?? this.recentPosts,
      age: age ?? this.age,
      height: height ?? this.height,
      experienceYears: experienceYears ?? this.experienceYears,
    );
  }
}

class TrainerDetailsNotifier extends StateNotifier<TrainerDetailsState> {
  final Ref ref;
  final Map<String, dynamic>? initialArgs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<StreamSubscription<dynamic>> _subs = [];

  TrainerDetailsNotifier(this.ref, this.initialArgs)
      : super(TrainerDetailsState(
          trainerName: 'Trainer',
          specialty: '',
          rating: 0.0,
          reviewCount: 0,
          pricePerHour: 0,
          sessions: 0,
          portrait: 10,
          imageUrl: '',
          isAvailable: false,
          trainerId: '',
          bio: '',
          specializations: [],
          languages: [],
          sessionLocations: [],
          availability: {},
          recentPosts: [],
          age: 29,
          height: 1.82,
          experienceYears: 5,
        )) {
    _init();
  }

  void _init() {
    if (initialArgs != null) {
      final name = initialArgs!['name'] as String? ?? 'Trainer';
      final spec = initialArgs!['specialty'] as String? ?? '';
      final ratingVal = (initialArgs!['rating'] as num?)?.toDouble() ?? 0.0;
      final reviewsVal = (initialArgs!['sessions'] as int?) ?? (initialArgs!['reviews'] as int?) ?? 0;
      final priceVal = (initialArgs!['pricePerHour'] as int?) ?? (initialArgs!['price'] as int?) ?? 0;
      final sessVal = (initialArgs!['sessions'] as int?) ?? 0;
      final portVal = (initialArgs!['portrait'] as int?) ?? 32;
      final imgVal = initialArgs!['image'] as String? ?? '';
      final availVal = initialArgs!['isAvailable'] as bool? ?? false;
      final uidVal = (initialArgs!['trainerId'] ?? initialArgs!['id'] ?? '').toString();
      final bioVal = (initialArgs!['bio'] ?? '').toString();
      final ageVal = (initialArgs!['age'] as num?)?.toInt() ?? 29;
      final heightVal = (initialArgs!['height'] as num?)?.toDouble() ?? 1.82;
      final expVal = (initialArgs!['experienceYears'] as num?)?.toInt() ?? 5;

      List<String> specsList = [];
      final rawSpecs = initialArgs!['specializations'];
      if (rawSpecs is List) {
        specsList = rawSpecs.map((e) => e.toString()).toList();
      }
      List<String> langList = [];
      final rawLanguages = initialArgs!['languages'];
      if (rawLanguages is List) {
        langList = rawLanguages.map((e) => e.toString()).toList();
      }
      List<String> locsList = [];
      final rawLocations = initialArgs!['sessionLocations'];
      if (rawLocations is List) {
        locsList = rawLocations.map((e) => e.toString()).toList();
      }

      Map<String, Map<String, dynamic>> availMap = {};
      final rawAvailability = initialArgs!['availability'];
      if (rawAvailability is Map) {
        availMap = rawAvailability.map((k, v) {
          final value = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
          return MapEntry(k.toString(), value);
        });
      }

      state = TrainerDetailsState(
        trainerName: name,
        specialty: spec,
        rating: ratingVal,
        reviewCount: reviewsVal,
        pricePerHour: priceVal,
        sessions: sessVal,
        portrait: portVal,
        imageUrl: imgVal,
        isAvailable: availVal,
        trainerId: uidVal,
        bio: bioVal,
        specializations: specsList,
        languages: langList,
        sessionLocations: locsList,
        availability: availMap,
        recentPosts: [],
        age: ageVal,
        height: heightVal,
        experienceYears: expVal,
      );
    }

    _listenRealtimeDetails();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listenRealtimeDetails() {
    final uid = state.trainerId.trim();
    final name = state.trainerName.trim();

    // Check if UID is empty, contains underscore (a slug like 'anh_rith_kach'), or is too short to be a valid Firebase UID
    final bool isSlug = uid.isEmpty || uid.contains('_') || uid.length < 20;

    if (isSlug) {
      final searchName = (name.isNotEmpty && name.toLowerCase() != 'trainer')
          ? name
          : uid.replaceAll('_', ' ');

      if (searchName.isNotEmpty && searchName.toLowerCase() != 'trainer') {
        final normSearch = searchName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        _firestore.collection('users')
            .where('role', isEqualTo: 'trainer')
            .get()
            .then((snap) {
          DocumentSnapshot? match;
          for (final doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            final dbName = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString().trim();
            final normDb = dbName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            if (normDb == normSearch) {
              match = doc;
              break;
            }
          }
          if (match != null) {
            state = state.copyWith(trainerId: match.id);
            for (final sub in _subs) {
              sub.cancel();
            }
            _subs.clear();
            _listenRealtimeDetails(); // Restart listening with the correct trainerId
          } else {
            _setupNameFallback(searchName);
          }
        }).catchError((e) {
          // ignore: avoid_print
          print('[TrainerDetails] Error resolving slug UID for $searchName: $e');
          _setupNameFallback(searchName);
        });
      }
      return;
    }

    // ── Listen to trainer profile doc ──────────────────────────────────
    _subs.add(
      _firestore.collection('trainerProfiles').doc(uid).snapshots().listen(
        (doc) {
          if (!doc.exists) return;
          _applyProfileData(doc.data() ?? const <String, dynamic>{});
        },
        onError: (_) {},
      ),
    );

    // ── Listen to user doc (name / photo / rating) ─────────────────────
    _subs.add(
      _firestore.collection('users').doc(uid).snapshots().listen(
        (doc) {
          if (!doc.exists) return;
          final data = doc.data() ?? const <String, dynamic>{};
          final nameVal =
              (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '')
                  .toString()
                  .trim();
          final photo = (data['photoUrl'] ?? '').toString().trim();
          final ratingValue = data['rating'];
          final reviewsValue = data['reviewsCount'];
          final ageValue = data['age'] is num ? (data['age'] as num).toInt() : null;
          final heightValue = data['height'] is num ? (data['height'] as num).toDouble() : null;

          state = state.copyWith(
            trainerName: nameVal.isNotEmpty ? nameVal : state.trainerName,
            imageUrl: photo.isNotEmpty ? photo : state.imageUrl,
            rating: ratingValue is num ? ratingValue.toDouble() : state.rating,
            reviewCount:
                reviewsValue is num ? reviewsValue.toInt() : state.reviewCount,
            age: ageValue ?? state.age,
            height: heightValue ?? state.height,
          );
        },
        onError: (_) {},
      ),
    );

    // ── Listen to reviews collection to compute dynamic average rating ──
    _subs.add(
      _firestore
          .collection('reviews')
          .where('trainerId', isEqualTo: uid)
          .snapshots()
          .listen(
            (snap) {
              final vals = snap.docs
                  .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
                  .where((v) => v > 0)
                  .toList();
              final avg = vals.isEmpty
                  ? 0.0
                  : vals.reduce((a, b) => a + b) / vals.length;
              if (avg > 0 && mounted) {
                state = state.copyWith(
                  rating: avg,
                  reviewCount: snap.docs.length,
                );
              }
            },
            onError: (_) {},
          ),
    );

    // ── Listen to THIS trainer's posts ONLY (by trainerId) ─────────────
    _subs.add(
      _firestore
          .collection('trainerPosts')
          .where('trainerId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen(
            (snap) {
              final mapped = snap.docs
                  .map((d) => {'id': d.id, ...d.data()})
                  .toList(growable: false)
                ..sort((a, b) => _toEpochMs(
                    b['createdAt'] ?? b['createdAtClient'],
                  ).compareTo(_toEpochMs(a['createdAt'] ?? a['createdAtClient'])));
              state = state.copyWith(recentPosts: mapped.take(6).toList());
            },
            onError: (e) {
              // ignore: avoid_print
              print('[TrainerDetails] trainerPosts query error for uid=$uid: $e');
            },
          ),
    );
  }

  void _setupNameFallback(String name) {
    _subs.add(
      _firestore
          .collection('trainerPosts')
          .where('trainerName', isEqualTo: name)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen(
            (snap) {
              final mapped = snap.docs
                  .map((d) => {'id': d.id, ...d.data()})
                  .toList(growable: false)
                ..sort((a, b) => _toEpochMs(
                    b['createdAt'] ?? b['createdAtClient'],
                  ).compareTo(_toEpochMs(a['createdAt'] ?? a['createdAtClient'])));
              state = state.copyWith(recentPosts: mapped.take(6).toList());
            },
            onError: (e) {
              // ignore: avoid_print
              print('[TrainerDetails] trainerPosts name-fallback error: $e');
            },
          ),
    );
  }

  void _applyProfileData(Map<String, dynamic> data) {
    final rawBio = (data['bio'] ?? '').toString().trim();
    final rawPrice = data['sessionPrice'];
    final photo = (data['photoUrl'] ?? '').toString().trim();
    final rawSpecs = data['specializations'];
    final rawLanguages = data['languages'];
    final rawLocations = data['sessionLocations'];
    final rawAvailability = data['availability'];
    final rawExperience = data['experienceYears'];

    List<String> specsList = state.specializations;
    String specialtyVal = state.specialty;
    if (rawSpecs is List) {
      specsList = rawSpecs.map((e) => e.toString()).toList();
      if (specsList.isNotEmpty) {
        specialtyVal = specsList.first;
      }
    }

    List<String> langList = state.languages;
    if (rawLanguages is List) {
      langList = rawLanguages.map((e) => e.toString()).toList();
    }

    List<String> locsList = state.sessionLocations;
    if (rawLocations is List) {
      locsList = rawLocations.map((e) => e.toString()).toList();
    }

    Map<String, Map<String, dynamic>> availMap = state.availability;
    bool availBool = state.isAvailable;
    if (rawAvailability is Map) {
      availMap = rawAvailability.map((key, value) {
        final dayValue =
            value is Map
                ? Map<String, dynamic>.from(value)
                : <String, dynamic>{};
        return MapEntry(key.toString(), dayValue);
      });
      availBool = availMap.values.any((day) => day['enabled'] == true);
    }

    final expYears = rawExperience is num ? rawExperience.toInt() : null;

    state = state.copyWith(
      bio: rawBio.isNotEmpty ? rawBio : state.bio,
      pricePerHour: (rawPrice is num && rawPrice > 0) ? rawPrice.toInt() : state.pricePerHour,
      imageUrl: photo.isNotEmpty ? photo : state.imageUrl,
      specializations: specsList,
      specialty: specialtyVal,
      languages: langList,
      sessionLocations: locsList,
      availability: availMap,
      isAvailable: availBool,
      experienceYears: expYears ?? state.experienceYears,
    );
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

    final updatedPosts = state.recentPosts.map((post) {
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

    state = state.copyWith(recentPosts: updatedPosts);

    try {
      await ref.read(postInteractionServiceProvider).toggleLike(postId);
    } catch (_) {}
  }
}

final trainerDetailsProvider = StateNotifierProvider.family<TrainerDetailsNotifier, TrainerDetailsState, Map<String, dynamic>?>((ref, args) {
  return TrainerDetailsNotifier(ref, args);
});
