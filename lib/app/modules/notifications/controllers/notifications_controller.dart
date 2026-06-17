import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/notification_service.dart';

// Carries a single new notification to be shown as an in-app alert
class NewNotificationEvent {
  final String title;
  final String body;
  final String colorKey;
  final String iconKey;
  final String senderPhotoUrl;
  /// JSON-decodable payload for deep-link navigation on tap.
  final Map<String, dynamic> routePayload;

  NewNotificationEvent({
    required this.title,
    required this.body,
    required this.colorKey,
    required this.iconKey,
    required this.senderPhotoUrl,
    required this.routePayload,
  });
}

class NotificationsState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationsState({
    required this.notifications,
    required this.unreadCount,
    required this.isLoading,
  });

  NotificationsState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

class NotificationsNotifier extends AutoDisposeNotifier<NotificationsState> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _sub;

  // Broadcasts new notifications for in-app alert banners
  final _newNotifController = StreamController<NewNotificationEvent>.broadcast();
  Stream<NewNotificationEvent> get newNotificationStream => _newNotifController.stream;

  // IDs we knew about on first snapshot load (not "new")
  final Set<String> _knownIds = {};
  bool _firstLoad = true;

  @override
  NotificationsState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _newNotifController.close();
    });

    final authState = ref.watch(authStateChangesProvider);

    authState.when(
      data: (user) {
        if (user != null) {
          _subscribeToNotifications(user.uid);
        } else {
          _sub?.cancel();
          _sub = null;
          _knownIds.clear();
          _firstLoad = true;
          Future.microtask(() {
            state = NotificationsState(
              notifications: const [],
              unreadCount: 0,
              isLoading: false,
            );
          });
        }
      },
      error: (_, __) {
        Future.microtask(() {
          state = state.copyWith(isLoading: false);
        });
      },
      loading: () {},
    );

    return NotificationsState(
      notifications: const [],
      unreadCount: 0,
      isLoading: true,
    );
  }

  void _subscribeToNotifications(String uid) {
    _sub?.cancel();
    _firstLoad = true;
    _knownIds.clear();
    _sub = _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .listen((snap) {
      final list =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      final unread = list.where((n) => n['read'] == false).length;

      if (_firstLoad) {
        // Snapshot on first load — just record all existing IDs
        _firstLoad = false;
        _knownIds.addAll(snap.docs.map((d) => d.id));
      } else {
        // Detect brand-new docs that just arrived
        for (final doc in snap.docChanges) {
          if (doc.type == DocumentChangeType.added &&
              !_knownIds.contains(doc.doc.id)) {
            _knownIds.add(doc.doc.id);
            final data = doc.doc.data() ?? <String, dynamic>{};
            // Only alert for unread ones
            if (data['read'] != true) {
              // Build route payload for navigation
              final routePayload = _buildRoutePayload(data);

              // Fire native OS notification (shows on device lock screen / notification shade)
              NotificationService.instance.showNotification(
                title: (data['title'] ?? 'Notification').toString(),
                body: (data['body'] ?? '').toString(),
                routePayload: routePayload,
              );

              _newNotifController.add(NewNotificationEvent(
                title: (data['title'] ?? 'Notification').toString(),
                body: (data['body'] ?? '').toString(),
                colorKey: (data['color'] ?? data['type'] ?? 'lilac').toString(),
                iconKey: (data['icon'] ?? data['type'] ?? 'bell').toString(),
                senderPhotoUrl: (data['senderPhotoUrl'] ?? '').toString(),
                routePayload: routePayload,
              ));
            }
          }
        }
      }

      state = state.copyWith(
        notifications: list,
        unreadCount: unread,
        isLoading: false,
      );
    }, onError: (_) => state = state.copyWith(isLoading: false));
  }

  Future<void> markAllRead() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final unread = state.notifications.where((n) => n['read'] == false);
    if (unread.isEmpty) return;
    final batch = _firestore.batch();
    for (final n in unread) {
      final id = n['id'] as String? ?? '';
      if (id.isEmpty) continue;
      batch.update(
        _firestore
            .collection('notifications')
            .doc(user.uid)
            .collection('items')
            .doc(id),
        {'read': true},
      );
    }
    await batch.commit();
    // State will auto-update from stream
  }

  Future<void> tappedNotification(Map<String, dynamic> target) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final id = target['id'] as String? ?? '';
    if (id.isEmpty || target['read'] == true) return;
    await _firestore
        .collection('notifications')
        .doc(user.uid)
        .collection('items')
        .doc(id)
        .update({'read': true});
    // State will auto-update from stream
  }

  Future<void> addNotification(Map<String, dynamic> notif) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('notifications')
          .doc(user.uid)
          .collection('items')
          .add({
        ...notif,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // State will auto-update from stream
    } catch (_) {}
  }
  /// Builds a deep-link payload map from a Firestore notification document.
  Map<String, dynamic> _buildRoutePayload(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    return {
      'type': type,
      'postId': (data['postId'] ?? '').toString(),
      'trainerName': (data['trainerName'] ?? data['senderName'] ?? 'Trainer').toString(),
      'otherId': (data['senderId'] ?? data['otherId'] ?? '').toString(),
      'otherName': (data['senderName'] ?? data['otherName'] ?? '').toString(),
      'otherPhoto': (data['senderPhotoUrl'] ?? data['otherPhoto'] ?? '').toString(),
    };
  }
}

final notificationsNotifierProvider =
    AutoDisposeNotifierProvider<NotificationsNotifier, NotificationsState>(
  () => NotificationsNotifier(),
);
