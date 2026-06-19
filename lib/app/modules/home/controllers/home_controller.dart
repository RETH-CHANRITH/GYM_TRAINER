import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/post_interaction_service.dart';
import '../../../providers/rx_compat.dart';

class HomeState {
  final int currentIndex;
  final int selectedCategoryIndex;
  final String searchQuery;
  final int streak;
  final int sessionsCount;
  final int goalsCount;
  final String userPhotoUrl;
  final String userName;
  final String userInitial;
  final String promoLabel;
  final String promoTitle;
  final String promoDiscount;
  final bool promoActive;
  final String promoButtonText;
  final List<Map<String, dynamic>> featuredTrainers;
  final List<Map<String, dynamic>> latestTrainerPosts;
  final List<Map<String, dynamic>> trainerCatalog;
  final int unreadMessagesCount;
  final int unreadNotificationsCount;

  HomeState({
    required this.currentIndex,
    required this.selectedCategoryIndex,
    required this.searchQuery,
    required this.streak,
    required this.sessionsCount,
    required this.goalsCount,
    required this.userPhotoUrl,
    required this.userName,
    required this.userInitial,
    required this.promoLabel,
    required this.promoTitle,
    required this.promoDiscount,
    required this.promoActive,
    required this.promoButtonText,
    required this.featuredTrainers,
    required this.latestTrainerPosts,
    required this.trainerCatalog,
    required this.unreadMessagesCount,
    required this.unreadNotificationsCount,
  });

  HomeState copyWith({
    int? currentIndex,
    int? selectedCategoryIndex,
    String? searchQuery,
    int? streak,
    int? sessionsCount,
    int? goalsCount,
    String? userPhotoUrl,
    String? userName,
    String? userInitial,
    String? promoLabel,
    String? promoTitle,
    String? promoDiscount,
    bool? promoActive,
    String? promoButtonText,
    List<Map<String, dynamic>>? featuredTrainers,
    List<Map<String, dynamic>>? latestTrainerPosts,
    List<Map<String, dynamic>>? trainerCatalog,
    int? unreadMessagesCount,
    int? unreadNotificationsCount,
  }) {
    return HomeState(
      currentIndex: currentIndex ?? this.currentIndex,
      selectedCategoryIndex: selectedCategoryIndex ?? this.selectedCategoryIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      streak: streak ?? this.streak,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      goalsCount: goalsCount ?? this.goalsCount,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      userName: userName ?? this.userName,
      userInitial: userInitial ?? this.userInitial,
      promoLabel: promoLabel ?? this.promoLabel,
      promoTitle: promoTitle ?? this.promoTitle,
      promoDiscount: promoDiscount ?? this.promoDiscount,
      promoActive: promoActive ?? this.promoActive,
      promoButtonText: promoButtonText ?? this.promoButtonText,
      featuredTrainers: featuredTrainers ?? this.featuredTrainers,
      latestTrainerPosts: latestTrainerPosts ?? this.latestTrainerPosts,
      trainerCatalog: trainerCatalog ?? this.trainerCatalog,
      unreadMessagesCount: unreadMessagesCount ?? this.unreadMessagesCount,
      unreadNotificationsCount: unreadNotificationsCount ?? this.unreadNotificationsCount,
    );
  }
}

class HomeNotifier extends AutoDisposeNotifier<HomeState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _userSub;
  StreamSubscription<DocumentSnapshot>? _statsSubscription;
  StreamSubscription<QuerySnapshot>? _unreadNotifSub;
  StreamSubscription<QuerySnapshot>? _unreadMsgSub;
  StreamSubscription<DocumentSnapshot>? _promoSub;
  final List<StreamSubscription<dynamic>> _subs = [];

  int _userActiveDiscount = 0;
  Map<String, dynamic> _activeCampaignData = const {};

  static const _categoryLabels = [
    'All',
    'Strength',
    'Yoga',
    'Cardio',
    'Boxing',
    'Swim',
  ];

  final Map<String, Map<String, dynamic>> _trainerUsersByUid = {};
  final Map<String, Map<String, dynamic>> _trainerProfilesByUid = {};
  final Map<String, List<double>> _trainerRatings = {};

  @override
  HomeState build() {
    ref.onDispose(() {
      _userSub?.cancel();
      _statsSubscription?.cancel();
      _unreadNotifSub?.cancel();
      _unreadMsgSub?.cancel();
      _promoSub?.cancel();
      for (final sub in _subs) {
        sub.cancel();
      }
    });

    _listenToUser();
    _listenTrainersRealtime();
    _listenTrainerPostsRealtime();
    _listenPromoRealtime();

    return HomeState(
      currentIndex: 0,
      selectedCategoryIndex: 0,
      searchQuery: '',
      streak: 0,
      sessionsCount: 0,
      goalsCount: 0,
      userPhotoUrl: '',
      userName: 'User',
      userInitial: 'U',
      promoLabel: 'FIRST BOOKING',
      promoTitle: '50% Off\nFirst Session',
      promoDiscount: '50\n%',
      promoActive: true,
      promoButtonText: 'Claim Now →',
      featuredTrainers: [],
      latestTrainerPosts: [],
      trainerCatalog: const <Map<String, dynamic>>[],
      unreadMessagesCount: 0,
      unreadNotificationsCount: 0,
    );
  }

  void _listenToUser() {
    _userSub = FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        final photoUrl = user.photoURL ?? '';
        final name = user.displayName ?? user.email ?? 'User';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
        state = state.copyWith(
          userPhotoUrl: photoUrl,
          userName: name,
          userInitial: initial,
        );
        _startUserSubscriptions(user.uid);
      } else {
        state = state.copyWith(
          userPhotoUrl: '',
          userName: 'User',
          userInitial: 'U',
          streak: 0,
          sessionsCount: 0,
          goalsCount: 0,
          unreadMessagesCount: 0,
          unreadNotificationsCount: 0,
        );
        _cancelUserSubscriptions();
      }
    });
  }

  void _startUserSubscriptions(String uid) {
    _cancelUserSubscriptions();

    _statsSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) return;
          final data = doc.data() ?? const <String, dynamic>{};

          // Seed activeDiscount to 50 if new client user
          final role = (data['role'] ?? 'user').toString();
          int activeDiscount = 0;
          if (role == 'user' || role == 'client') {
            if (data.containsKey('activeDiscount')) {
              activeDiscount = (data['activeDiscount'] as num?)?.toInt() ?? 0;
            } else {
              activeDiscount = 50;
              _firestore.collection('users').doc(uid).set({
                'activeDiscount': 50,
              }, SetOptions(merge: true));
            }
          } else {
            activeDiscount = (data['activeDiscount'] as num?)?.toInt() ?? 0;
          }

          _userActiveDiscount = activeDiscount;

          state = state.copyWith(
            streak: (data['streak'] as num?)?.toInt() ?? 0,
            sessionsCount: (data['totalSessions'] as num?)?.toInt() ?? 0,
            goalsCount: (data['goalsCount'] as num?)?.toInt() ?? 0,
          );
          _updatePromoBanner();
        });

    _unreadNotifSub = _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
          state = state.copyWith(
            unreadNotificationsCount: snap.docs.length,
          );
        }, onError: (_) {});

    _unreadMsgSub = _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .listen((snap) {
          int totalUnread = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            final unreadCounts = data['unreadCounts'];
            if (unreadCounts is Map) {
              final count = unreadCounts[uid];
              if (count is num) {
                totalUnread += count.toInt();
              }
            }
          }
          state = state.copyWith(
            unreadMessagesCount: totalUnread,
          );
        }, onError: (_) {});
  }

  void _cancelUserSubscriptions() {
    _statsSubscription?.cancel();
    _statsSubscription = null;
    _unreadNotifSub?.cancel();
    _unreadNotifSub = null;
    _unreadMsgSub?.cancel();
    _unreadMsgSub = null;
  }

  void _listenTrainersRealtime() {
    _subs.add(
      _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .limit(250)
          .snapshots()
          .listen((snap) {
            _trainerUsersByUid.clear();
            _trainerUsersByUid.addEntries(snap.docs.map((d) => MapEntry(d.id, d.data())));
            _rebuildTrainerCatalog();
          }, onError: (_) {}),
    );

    _subs.add(
      _firestore.collection('trainerProfiles').limit(250).snapshots().listen((
        snap,
      ) {
        _trainerProfilesByUid.clear();
        _trainerProfilesByUid.addEntries(snap.docs.map((d) => MapEntry(d.id, d.data())));
        _rebuildTrainerCatalog();
      }, onError: (_) {}),
    );

    _subs.add(
      _firestore.collection('reviews').snapshots().listen((snap) {
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
      }, onError: (_) {}),
    );
  }

  void _listenTrainerPostsRealtime() {
    _subs.add(
      _firestore
          .collection('trainerPosts')
          .where('isActive', isEqualTo: true)
          .limit(60)
          .snapshots()
          .listen((snap) {
            final mapped = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList(growable: false)..sort(
              (a, b) => _toEpochMs(
                b['createdAt'] ?? b['createdAtClient'],
              ).compareTo(_toEpochMs(a['createdAt'] ?? a['createdAtClient'])),
            );
            state = state.copyWith(
              latestTrainerPosts: mapped.take(12).toList(),
            );
          }, onError: (_) {}),
    );
  }

  void _updatePromoBanner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Guest user — always show 50% first booking discount
      state = state.copyWith(
        promoLabel: 'FIRST BOOKING',
        promoTitle: '50% Off\nFirst Session',
        promoDiscount: '50\n%',
        promoActive: true,
        promoButtonText: 'Claim Now →',
      );
      return;
    }

    if (_userActiveDiscount > 0) {
      String displayTitle = '$_userActiveDiscount% Off\nFirst Session';
      if (_userActiveDiscount != 50) {
        final campaignDiscountStr = (_activeCampaignData['discount'] ?? '')
            .toString()
            .replaceAll('\n', '')
            .replaceAll('%', '')
            .trim();
        final campaignDiscount = int.tryParse(campaignDiscountStr) ?? 0;
        if (campaignDiscount == _userActiveDiscount && _activeCampaignData['title'] != null) {
          displayTitle = _activeCampaignData['title'].toString();
        } else {
          displayTitle = '$_userActiveDiscount% Off\nNext Session';
        }
      }

      if (_userActiveDiscount != 50 && displayTitle.contains('First Session')) {
        displayTitle = displayTitle.replaceAll('First Session', 'Next Session');
      }

      state = state.copyWith(
        promoLabel: _userActiveDiscount == 50 ? 'FIRST BOOKING' : 'SPECIAL PROMO',
        promoTitle: displayTitle,
        promoDiscount: '$_userActiveDiscount\n%',
        promoActive: true,
        promoButtonText: 'Claimed & Active',
      );
    } else {
      final isActive = _activeCampaignData['isActive'] == true;
      final label = (_activeCampaignData['label'] ?? 'LIMITED TIME').toString();
      final title = (_activeCampaignData['title'] ?? '20% Off\nNext Session').toString();
      final discount = (_activeCampaignData['discount'] ?? '20\n%').toString();

      String displayTitle = title;
      if (displayTitle.contains('First Session')) {
        displayTitle = displayTitle.replaceAll('First Session', 'Next Session');
      }

      if (isActive) {
        state = state.copyWith(
          promoLabel: label,
          promoTitle: displayTitle,
          promoDiscount: discount,
          promoActive: true,
          promoButtonText: 'Claim Now →',
        );
      } else {
        state = state.copyWith(
          promoLabel: 'NO ACTIVE PROMO',
          promoTitle: '0% Off\nNext Session',
          promoDiscount: '0\n%',
          promoActive: true,
          promoButtonText: 'No Promo Available',
        );
      }
    }
  }

  void _listenPromoRealtime() {
    _promoSub = _firestore
        .collection('promotions')
        .doc('activeCampaign')
        .snapshots()
        .listen((doc) {
          if (!doc.exists) {
            _activeCampaignData = const {
              'label': 'NO ACTIVE PROMO',
              'title': '0% Off\nNext Session',
              'discount': '0\n%',
              'isActive': false,
            };
            _updatePromoBanner();
            return;
          }
          _activeCampaignData = doc.data() ?? const <String, dynamic>{};
          _updatePromoBanner();
        }, onError: (_) {});
  }

  void _rebuildTrainerCatalog() {
    final catalog = <Map<String, dynamic>>[];

    for (final entry in _trainerUsersByUid.entries) {
      final uid = entry.key;
      final user = entry.value;
      final profile = _trainerProfilesByUid[uid] ?? const <String, dynamic>{};

      final rawName =
          (user['name'] ?? user['fullName'] ?? user['displayName'] ?? '')
              .toString()
              .trim();
      if (rawName.isEmpty) continue;

      final specializations =
          (profile['specializations'] is List)
              ? (profile['specializations'] as List)
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : <String>[];
      final sessionLocations =
          (profile['sessionLocations'] is List)
              ? (profile['sessionLocations'] as List)
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : <String>[];

      final fallbackCategory = _inferCategory(specializations);
      final priceFromProfile = _toInt(profile['sessionPrice']);
      
      final ratingsList = _trainerRatings[uid] ?? [];
      final computedAvg = ratingsList.isEmpty
          ? 0.0
          : ratingsList.reduce((a, b) => a + b) / ratingsList.length;

      final reviewCount = ratingsList.isNotEmpty ? ratingsList.length : _toInt(user['reviewsCount']);
      final rating = computedAvg > 0 ? computedAvg : _toDouble(user['rating']);

      catalog.add({
        'id': uid,
        'trainerId': uid,
        'name': rawName,
        'specialty':
            specializations.isNotEmpty
                ? specializations.first
                : 'Personal Training',
        'specializations': specializations,
        'languages': profile['languages'] ?? const <String>[],
        'sessionLocations': sessionLocations,
        'bio': (profile['bio'] ?? '').toString(),
        'category': fallbackCategory,
        'rating': rating > 0 ? rating : 4.7,
        'reviews': reviewCount,
        'pricePerHour': priceFromProfile > 0 ? priceFromProfile : 40,
        'isAvailable': _isProfileAvailable(profile, user['isActive']),
        'availability': profile['availability'] ?? const <String, dynamic>{},
        'image': (profile['photoUrl'] ?? user['photoUrl'] ?? '').toString(),
      });
    }

    final candidates = catalog.toList()..sort((a, b) {
      final aScore = ((a['rating'] as num?) ?? 0).toDouble();
      final bScore = ((b['rating'] as num?) ?? 0).toDouble();
      return bScore.compareTo(aScore);
    });

    state = state.copyWith(
      trainerCatalog: catalog,
      featuredTrainers: candidates.take(3).toList(),
    );
  }

  String _normalizeName(String raw) {
    return raw.trim().toLowerCase();
  }

  String _inferCategory(List<String> specializations) {
    final joined = specializations.join(' ').toLowerCase();
    if (joined.contains('yoga') || joined.contains('pilates')) return 'Yoga';
    if (joined.contains('box') ||
        joined.contains('mma') ||
        joined.contains('muay')) {
      return 'Boxing';
    }
    if (joined.contains('swim') || joined.contains('aqua')) return 'Swim';
    if (joined.contains('cardio') ||
        joined.contains('hiit') ||
        joined.contains('run')) {
      return 'Cardio';
    }
    return 'Strength';
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

  List<Map<String, dynamic>> get filteredTrainers {
    final query = state.searchQuery.trim().toLowerCase();
    final category = _categoryLabels[state.selectedCategoryIndex];
    return state.trainerCatalog.where((t) {
      final matchCat = category == 'All' || (t['category'] as String) == category;
      final matchQuery =
          query.isEmpty ||
          (t['name'] as String).toLowerCase().contains(query) ||
          (t['specialty'] as String).toLowerCase().contains(query);
      return matchCat && matchQuery;
    }).toList();
  }

  void changeTab(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void selectCategory(int index) {
    state = state.copyWith(selectedCategoryIndex: index);
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void navigateToStreakDetails(BuildContext context) {
    context.push('/streak-details');
  }

  void navigateToSessionsDetails(BuildContext context) {
    context.push('/my-bookings');
  }

  void navigateToGoalsDetails(BuildContext context) {
    context.push('/goals-details');
  }

  void navigateToTrainerDetails(BuildContext context, Map<String, dynamic> trainer) {
    context.push('/trainer-details', extra: trainer);
  }

  void navigateToTrainerFromPost(BuildContext context, Map<String, dynamic> post) {
    final trainerId = (post['trainerId'] ?? '').toString().trim();
    final trainerName =
        (post['trainerName'] ?? post['authorName'] ?? '').toString().trim();

    Map<String, dynamic>? trainer;
    if (trainerId.isNotEmpty) {
      trainer = state.trainerCatalog.firstWhereOrNull(
        (item) => (item['trainerId'] ?? item['id']).toString() == trainerId,
      );
    }

    trainer ??= state.trainerCatalog.firstWhereOrNull(
      (item) =>
          _normalizeName(item['name']?.toString() ?? '') ==
          _normalizeName(trainerName),
    );

    if (trainer != null) {
      navigateToTrainerDetails(context, trainer);
      return;
    }

    if (trainerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trainer unavailable: Could not open this trainer profile.'),
        ),
      );
      return;
    }

    navigateToTrainerDetails(context, {
      'id': trainerId,
      'trainerId': trainerId,
      'name': trainerName,
      'specialty': (post['category'] ?? 'Personal Training').toString(),
      'image': (post['trainerPhotoUrl'] ?? post['imageUrl'] ?? '').toString(),
      'isAvailable': true,
    });
  }

  void navigateToBookingDetails(BuildContext context, String bookingId) {
    context.push('/booking/$bookingId');
  }

  void navigateToMessages() {
    state = state.copyWith(currentIndex: 2);
  }

  void navigateToNotifications(BuildContext context) {
    context.push('/notifications');
  }

  void navigateToSearch(BuildContext context) {
    context.push('/search');
  }

  void navigateToBook(BuildContext context) => context.push('/search');

  void navigateToHistory(BuildContext context) =>
      context.push('/my-bookings', extra: {'tab': 1});

  void navigateToPayment(BuildContext context) => context.push('/wallet');

  Future<void> claimPromo(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showSnackbar('Sign In', 'Please log in to claim this promotion.');
      context.push('/login');
      return;
    }

    if (_userActiveDiscount > 0) {
      context.push('/search');
      return;
    }

    final isActive = _activeCampaignData['isActive'] == true;
    if (!isActive) {
      showSnackbar('No Promo', 'There is no active promotion to claim.');
      return;
    }

    final discountStr = (_activeCampaignData['discount'] ?? '20\n%')
        .toString()
        .replaceAll('\n', '')
        .replaceAll('%', '')
        .trim();
    final discount = int.tryParse(discountStr) ?? 20;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'activeDiscount': discount,
      }, SetOptions(merge: true));

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF17171F),
          title: Text(
            'Promotion Claimed!',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Enjoy $discount% off on your next trainer booking! Discount is applied automatically at checkout.',
            style: GoogleFonts.dmSans(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/search');
              },
              child: Text(
                'Book Trainer Now',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFC8FF33),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      showSnackbar('Claim Error', 'Failed to claim promotion. Please try again.');
    }
  }

  Future<void> togglePostLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final updatedPosts = state.latestTrainerPosts.map((post) {
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

    state = state.copyWith(latestTrainerPosts: updatedPosts);

    try {
      await ref.read(postInteractionServiceProvider).toggleLike(postId);
    } catch (_) {}
  }
}

final homeNotifierProvider = AutoDisposeNotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
