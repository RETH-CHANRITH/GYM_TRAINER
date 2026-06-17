import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavouritesNotifier extends Notifier<List<Map<String, dynamic>>> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  List<Map<String, dynamic>> build() {
    ref.onDispose(() => _sub?.cancel());
    _listen();
    return const [];
  }

  void _listen() {
    final user = _auth.currentUser;
    if (user == null) {
      // Listen for sign-in
      _auth.authStateChanges().listen((u) {
        if (u != null) _subscribe(u.uid);
      });
      return;
    }
    _subscribe(user.uid);
  }

  void _subscribe(String uid) {
    _sub?.cancel();
    _sub = _firestore
        .collection('users')
        .doc(uid)
        .collection('favourites')
        .snapshots()
        .listen((snap) {
      final list = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      state = list;

      // Self-heal / correct legacy favourites with slug IDs or missing trainerId
      print('[Favourites] Total items in list: ${list.length}');
      for (final item in list) {
        final trainerId = (item['trainerId'] ?? item['id'] ?? '').toString().trim();
        final name = (item['name'] ?? '').toString().trim();
        final bool isSlug = trainerId.isEmpty || trainerId.contains('_') || trainerId.length < 20;

        print('[Favourites] Item: "$name", trainerId: "$trainerId", isSlug: $isSlug');

        if (isSlug && name.isNotEmpty && name.toLowerCase() != 'trainer') {
          final docId = item['id'].toString();
          final normSearch = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
          print('[Favourites] Querying users for role=trainer to resolve name: "$name" (norm: "$normSearch")');

          _firestore.collection('users')
              .where('role', isEqualTo: 'trainer')
              .get()
              .then((usersSnap) {
            print('[Favourites] Users query returned ${usersSnap.docs.length} trainers');
            DocumentSnapshot? match;
            for (final doc in usersSnap.docs) {
              final d = doc.data() as Map<String, dynamic>?;
              if (d == null) continue;
              final dbName = (d['name'] ?? d['fullName'] ?? d['displayName'] ?? '').toString().trim();
              final normDb = dbName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
              print('[Favourites] Comparing with DB Trainer: "$dbName" (norm: "$normDb")');
              if (normDb == normSearch) {
                match = doc;
                break;
              }
            }
            if (match != null) {
              print('[Favourites] Resolved! Found match: ${match.id} for "$name". Updating Firestore doc: $docId');
              _firestore.collection('users')
                  .doc(uid)
                  .collection('favourites')
                  .doc(docId)
                  .update({
                    'trainerId': match.id,
                    'id': match.id,
                  }).then((_) {
                    print('[Favourites] Firestore doc $docId updated successfully!');
                  }).catchError((e) {
                    print('[Favourites] Firestore update error: $e');
                  });
            } else {
              print('[Favourites] No match found in DB for trainer name: "$name"');
            }
          }).catchError((e) {
            print('[Favourites] Users query error: $e');
          });
        }
      }
    }, onError: (_) {});
  }

  bool isFavourite(String name) => state.any((t) => t['name'] == name);

  Future<void> toggle(Map<String, dynamic> trainer) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final name = trainer['name'] as String? ?? '';
    final docId = _docId(name);

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favourites')
        .doc(docId);

    if (isFavourite(name)) {
      await ref.delete();
    } else {
      await ref.set(_normalise(trainer));
    }
    // State auto-updates from stream
  }

  /// Stable document ID derived from trainer name
  String _docId(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  Map<String, dynamic> _normalise(Map<String, dynamic> t) {
    int? portrait = t['portrait'] as int?;
    if (portrait == null) {
      final img = (t['image'] as String? ?? '');
      final match = RegExp(r'/(?:men|women)/(\d+)\.jpg').firstMatch(img);
      if (match != null) portrait = int.tryParse(match.group(1) ?? '');
    }

    final String name = t['name'] ?? '';
    final int fallbackPortrait = name.isNotEmpty ? (name.hashCode.abs() % 90 + 10) : 10;

    return {
      'name': name,
      'specialty': t['specialty'] ?? '',
      'rating': (t['rating'] as num?)?.toDouble() ?? 0.0,
      'price': ((t['price'] ?? t['pricePerHour'] ?? 0) as num).toInt(),
      'sessions': ((t['sessions'] ?? 0) as num).toInt(),
      'portrait': portrait ?? fallbackPortrait,
      'available': t['available'] ?? t['isAvailable'] ?? false,
      'image': t['image'] ?? '',
      'trainerId': (t['trainerId'] ?? t['id'] ?? '').toString(),
    };
  }
}

final favouritesServiceProvider =
    NotifierProvider<FavouritesNotifier, List<Map<String, dynamic>>>(
  () => FavouritesNotifier(),
);
