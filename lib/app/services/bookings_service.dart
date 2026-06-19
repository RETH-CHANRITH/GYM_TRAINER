import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookingsState {
  final List<Map<String, dynamic>> upcomingBookings;
  final List<Map<String, dynamic>> pastBookings;
  final bool isLoading;

  BookingsState({
    required this.upcomingBookings,
    required this.pastBookings,
    required this.isLoading,
  });

  BookingsState copyWith({
    List<Map<String, dynamic>>? upcomingBookings,
    List<Map<String, dynamic>>? pastBookings,
    bool? isLoading,
  }) {
    return BookingsState(
      upcomingBookings: upcomingBookings ?? this.upcomingBookings,
      pastBookings: pastBookings ?? this.pastBookings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BookingsNotifier extends Notifier<BookingsState> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _sub;

  static const _upcomingStatuses = ['pending', 'confirmed'];
  static const _pastStatuses = ['completed', 'cancelled', 'rejected'];

  @override
  BookingsState build() {
    ref.onDispose(() => _sub?.cancel());
    _listen();
    return BookingsState(
      upcomingBookings: const [],
      pastBookings: const [],
      isLoading: true,
    );
  }

  void _listen() {
    final user = _auth.currentUser;
    if (user == null) {
      // Re-try when auth state changes
      _auth.authStateChanges().listen((u) {
        if (u != null) _subscribeToBookings(u.uid);
      });
      state = state.copyWith(isLoading: false);
      return;
    }
    _subscribeToBookings(user.uid);
  }

  void _subscribeToBookings(String uid) {
    _sub?.cancel();
    _sub = _firestore
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            final all = snap.docs
                .map((d) => {'id': d.id, ...d.data()})
                .toList();

            state = state.copyWith(
              upcomingBookings: all
                  .where((b) => _upcomingStatuses.contains(b['status']))
                  .toList(),
              pastBookings: all
                  .where((b) => _pastStatuses.contains(b['status']))
                  .toList(),
              isLoading: false,
            );
          },
          onError: (_) => state = state.copyWith(isLoading: false),
        );
  }

  /// Write a new booking to Firestore. Returns the new document ID.
  Future<String?> addBooking(Map<String, dynamic> booking) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('bookings').add({
        ...booking,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return;
      final booking = doc.data() ?? {};

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final isPaid = booking['paid'] == true ||
                     booking['paymentStatus'] == 'fully_paid' ||
                     booking['paymentStatus'] == 'partially_paid' ||
                     booking['paymentStatus'] == 'completed';

      double amountPaid = (booking['amountPaid'] as num?)?.toDouble() ?? 0.0;
      if (amountPaid == 0.0) {
        amountPaid = (booking['paymentAmount'] as num?)?.toDouble() ?? 0.0;
      }
      if (amountPaid == 0.0 && isPaid) {
        amountPaid = (booking['price'] as num?)?.toDouble() ?? 0.0;
      }
      final userId = booking['userId']?.toString() ?? '';
      final trainerId = booking['trainerId']?.toString() ?? '';
      final trainerName = (booking['trainer'] ?? booking['trainerName'] ?? 'Trainer').toString();
      final clientName = (booking['clientName'] ?? booking['userName'] ?? 'Client').toString();

      final date = (booking['date'] ?? '').toString();
      final time = (booking['time'] ?? '').toString();

      if (userId.isNotEmpty && amountPaid > 0 && isPaid) {
        await _firestore.collection('refunds').add({
          'bookingId': bookingId,
          'userId': userId,
          'clientName': clientName,
          'trainerId': trainerId,
          'trainerName': trainerName,
          'amount': amountPaid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'sessionDate': date,
          'sessionTime': time,
          'sessionType': (booking['type'] ?? booking['sessionType'] ?? 'Session').toString(),
        });
      }

      final currentUser = _auth.currentUser;
      final currentUid = currentUser?.uid ?? '';

      // Notify Trainer (if client or admin cancelled it)
      if (trainerId.isNotEmpty && currentUid != trainerId) {
        await _firestore
            .collection('notifications')
            .doc(trainerId)
            .collection('items')
            .add({
          'title': isPaid ? 'Booking Cancelled (Earnings Cut)' : 'Booking Cancelled',
          'body': isPaid
              ? '$clientName cancelled the session on $date at $time. \$${amountPaid.toStringAsFixed(0)} was deducted from your monthly earnings.'
              : '$clientName cancelled the session on $date at $time.',
          'type': 'booking',
          'color': 'coral',
          'icon': 'calendar',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': userId,
          'senderName': clientName,
        });
      }

      // Notify Client (if trainer or admin cancelled it)
      if (userId.isNotEmpty && currentUid != userId) {
        await _firestore
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .add({
          'title': 'Booking Cancelled',
          'body': isPaid
              ? 'Your session with $trainerName on $date at $time was cancelled. A refund of \$${amountPaid.toStringAsFixed(0)} has been requested.'
              : 'Your session with $trainerName on $date at $time was cancelled.',
          'type': 'booking',
          'color': 'coral',
          'icon': 'calendar',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': trainerId,
          'senderName': trainerName,
        });
      }
    } catch (_) {}
  }

  Future<void> markPaid(String bookingId, int amountPaid) async {
    try {
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return;

      final bookingData = bookingDoc.data();
      if (bookingData == null) return;

      final trainerId = bookingData['trainerId']?.toString() ?? '';
      final price = (bookingData['price'] as num?)?.toInt() ?? 0;
      final date = bookingData['date']?.toString() ?? '';
      final time = bookingData['time']?.toString() ?? '';

      final discountApplied = (bookingData['discountApplied'] as num?)?.toInt() ?? 0;
      final targetPrice = discountApplied > 0 
          ? (price * (1 - (discountApplied / 100))).round() 
          : price;

      final currentPaid = (bookingData['amountPaid'] as num?)?.toInt() ?? 0;
      final newPaid = currentPaid + amountPaid;
      final isFullPayment = newPaid >= targetPrice;
      final paymentStatus = isFullPayment ? 'fully_paid' : 'partially_paid';

      await _firestore.collection('bookings').doc(bookingId).update({
        'amountPaid': newPaid,
        'paymentStatus': paymentStatus,
        'paid': isFullPayment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final user = _auth.currentUser;
      if (user != null && trainerId.isNotEmpty && trainerId != user.uid) {
        final userName = (user.displayName ?? user.email?.split('@').first ?? 'Someone').trim();

        // ── Custom Trainer Notification ──────────────────────────────────
        String trainerNotifTitle;
        String trainerNotifBody;
        if (currentPaid == 0) {
          if (isFullPayment) {
            trainerNotifTitle = 'Full Payment Received';
            trainerNotifBody = '$userName paid \$${amountPaid} (Full Session) for the session on $date at $time';
          } else {
            trainerNotifTitle = 'Deposit Received';
            trainerNotifBody = '$userName paid deposit (50%) of \$${amountPaid} for the session on $date at $time';
          }
        } else {
          trainerNotifTitle = 'Remaining Balance Paid';
          trainerNotifBody = '$userName paid remaining balance (50%) of \$${amountPaid} for the session on $date at $time';
        }

        await _firestore
            .collection('notifications')
            .doc(trainerId)
            .collection('items')
            .add({
          'title': trainerNotifTitle,
          'body': trainerNotifBody,
          'type': 'payment',
          'color': 'gold',
          'icon': 'payment',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': user.uid,
          'senderName': userName,
          'senderPhotoUrl': user.photoURL ?? '',
        });

        // ── Custom User Confirmation Notification ────────────────────────
        String userNotifTitle;
        String userNotifBody;
        if (currentPaid == 0) {
          if (isFullPayment) {
            userNotifTitle = 'Payment Confirmed';
            userNotifBody = 'Your payment of \$${amountPaid} for the session on $date at $time has been confirmed.';
          } else {
            userNotifTitle = 'Deposit Confirmed';
            userNotifBody = 'Your deposit payment of \$${amountPaid} (50%) for the session on $date at $time has been confirmed.';
          }
        } else {
          userNotifTitle = 'Payment Confirmed';
          userNotifBody = 'Your remaining balance payment of \$${amountPaid} (50%) for the session on $date at $time has been confirmed.';
        }

        await _firestore
            .collection('notifications')
            .doc(user.uid)
            .collection('items')
            .add({
          'title': userNotifTitle,
          'body': userNotifBody,
          'type': 'booking',
          'color': 'sky',
          'icon': 'calendar',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': trainerId,
          'senderName': 'Trainer',
          'senderPhotoUrl': '',
        });
      }
    } catch (_) {}
  }

  bool hasUpcomingConflict({
    required String trainer,
    required String date,
    required String time,
  }) {
    return state.upcomingBookings.any(
      (b) =>
          (b['trainerName'] ?? b['trainer']) == trainer &&
          b['date'] == date &&
          b['time'] == time,
    );
  }
}

final bookingsServiceProvider =
    NotifierProvider<BookingsNotifier, BookingsState>(() => BookingsNotifier());
