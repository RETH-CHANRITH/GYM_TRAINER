import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../routes/app_router.dart';
import '../../../providers/rx_compat.dart';

class AdminDashboardController extends ChangeNotifier {
  final Ref ref;
  final FirebaseFirestore _firestore;

  AdminDashboardController({required this.ref, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    
    displayName.addListener(notifyListeners);
    isLoading.addListener(notifyListeners);
    isActionLoading.addListener(notifyListeners);
    selectedPanel.addListener(notifyListeners);
    currentTab.addListener(notifyListeners);
    trainerApplications.addListener(notifyListeners);
    users.addListener(notifyListeners);
    bookings.addListener(notifyListeners);
    transactions.addListener(notifyListeners);
    supportTickets.addListener(notifyListeners);
    disputes.addListener(notifyListeners);
    refunds.addListener(notifyListeners);
    payouts.addListener(notifyListeners);
    gdprRequests.addListener(notifyListeners);
    auditLogs.addListener(notifyListeners);
    activeTrainersCount.addListener(notifyListeners);
    pendingTrainerApplicationsCount.addListener(notifyListeners);
    activeUsersCount.addListener(notifyListeners);
    openBookingsCount.addListener(notifyListeners);
    supportOpenCount.addListener(notifyListeners);
    disputeOpenCount.addListener(notifyListeners);
    payoutPendingCount.addListener(notifyListeners);
    refundPendingCount.addListener(notifyListeners);
    gdprPendingCount.addListener(notifyListeners);
    monthlyRevenue.addListener(notifyListeners);
    recentActivity.addListener(notifyListeners);
    searchUsersQuery.addListener(notifyListeners);
    filterUsersStatus.addListener(notifyListeners);
    sortUsersBy.addListener(notifyListeners);
    filterBookingsStatus.addListener(notifyListeners);
    filterBookingsTrainerId.addListener(notifyListeners);
    filterBookingsDateFrom.addListener(notifyListeners);
    filterBookingsDateTo.addListener(notifyListeners);

    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      displayName.value = name;
    }
    _listenCollections();
  }

  @override
  void dispose() {
    _kpiRecomputeDebounce?.cancel();
    _activityRecomputeDebounce?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  final displayName = 'Admin'.obs;
  final isLoading = true.obs;
  final isActionLoading = false.obs;
  final selectedPanel = 0.obs;
  final currentTab = 0.obs;

  void changeTab(int index) => currentTab.value = index;

  final trainerApplications = <Map<String, dynamic>>[].obs;
  final users = <Map<String, dynamic>>[].obs;
  final bookings = <Map<String, dynamic>>[].obs;
  final transactions = <Map<String, dynamic>>[].obs;
  final supportTickets = <Map<String, dynamic>>[].obs;
  final disputes = <Map<String, dynamic>>[].obs;
  final refunds = <Map<String, dynamic>>[].obs;
  final payouts = <Map<String, dynamic>>[].obs;
  final gdprRequests = <Map<String, dynamic>>[].obs;
  final auditLogs = <Map<String, dynamic>>[].obs;
  final Set<String> _creatingRefundIds = {};

  final activeTrainersCount = 0.obs;
  final pendingTrainerApplicationsCount = 0.obs;
  final activeUsersCount = 0.obs;
  final openBookingsCount = 0.obs;
  final supportOpenCount = 0.obs;
  final disputeOpenCount = 0.obs;
  final payoutPendingCount = 0.obs;
  final refundPendingCount = 0.obs;
  final gdprPendingCount = 0.obs;
  final monthlyRevenue = 0.0.obs;

  final recentActivity = <Map<String, String>>[].obs;

  final searchUsersQuery = ''.obs;
  final filterUsersStatus = 'active'.obs;
  final sortUsersBy = 'createdAt'.obs;
  final filterBookingsStatus = 'pending'.obs;
  final filterBookingsTrainerId = ''.obs;
  final filterBookingsDateFrom = Rx<DateTime?>(null);
  final filterBookingsDateTo = Rx<DateTime?>(null);

  final _subscriptions = <StreamSubscription<dynamic>>[];
  static const int _dashboardCollectionLimit = 120;
  Timer? _kpiRecomputeDebounce;
  Timer? _activityRecomputeDebounce;

  void setPanel(int index) {
    selectedPanel.value = index;
  }

  void _listenCollections() {
    _subscriptions.add(
      _firestore
          .collection('trainerApplications')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            trainerApplications.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleRecentActivityRecompute();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('users')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            users.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('bookings')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            bookings.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
            _scheduleRecentActivityRecompute();
            _checkAndCreateMissingRefunds();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('transactions')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            transactions.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('supportTickets')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            supportTickets.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
            _scheduleRecentActivityRecompute();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('disputes')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            disputes.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
            _scheduleRecentActivityRecompute();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('refunds')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            refunds.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
            _checkAndCreateMissingRefunds();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('payouts')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            payouts.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('gdprRequests')
          .limit(_dashboardCollectionLimit)
          .snapshots()
          .listen((snap) {
            gdprRequests.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleKpiRecompute();
          }, onError: (_) {}),
    );

    _subscriptions.add(
      _firestore
          .collection('auditLogs')
          .orderBy('createdAt', descending: true)
          .limit(120)
          .snapshots()
          .listen((snap) {
            auditLogs.assignAll(
              snap.docs.map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              }),
            );
            _scheduleRecentActivityRecompute();
          }, onError: (_) {}),
    );

    Future<void>.delayed(const Duration(milliseconds: 700), () {
      isLoading.value = false;
    });
  }

  void _scheduleKpiRecompute() {
    _kpiRecomputeDebounce?.cancel();
    _kpiRecomputeDebounce = Timer(const Duration(milliseconds: 220), () {
      _recomputeKpis();
    });
  }

  void _scheduleRecentActivityRecompute() {
    _activityRecomputeDebounce?.cancel();
    _activityRecomputeDebounce = Timer(const Duration(milliseconds: 280), () {
      _recomputeRecentActivity();
    });
  }

  void _recomputeKpis() {
    pendingTrainerApplicationsCount.value =
        trainerApplications.where((a) {
          final status = (a['status'] ?? 'pending').toString().toLowerCase();
          return status == 'pending';
        }).length;

    activeUsersCount.value =
        users.where((u) {
          final role = (u['role'] ?? 'user').toString().toLowerCase();
          final status =
              (u['accountStatus'] ?? 'active').toString().toLowerCase();
          return role == 'user' && status != 'suspended';
        }).length;

    activeTrainersCount.value =
        users.where((u) {
          final role = (u['role'] ?? '').toString().toLowerCase();
          final status =
              (u['accountStatus'] ?? 'active').toString().toLowerCase();
          return role == 'trainer' && status != 'suspended';
        }).length;

    openBookingsCount.value =
        bookings.where((b) {
          final status = (b['status'] ?? '').toString().toLowerCase();
          return status == 'pending' || status == 'confirmed';
        }).length;

    supportOpenCount.value =
        supportTickets.where((t) {
          final status = (t['status'] ?? '').toString().toLowerCase();
          return status == 'open' ||
              status == 'pending' ||
              status == 'received' ||
              status == 'in_progress';
        }).length;

    disputeOpenCount.value =
        disputes.where((d) {
          final status = (d['status'] ?? '').toString().toLowerCase();
          return status == 'open' ||
              status == 'pending' ||
              status == 'assigned';
        }).length;

    payoutPendingCount.value =
        payouts.where((p) {
          final status = (p['status'] ?? '').toString().toLowerCase();
          return status == 'requested' ||
              status == 'pending' ||
              status == 'approved';
        }).length;

    refundPendingCount.value =
        refunds.where((r) {
          final status = (r['status'] ?? '').toString().toLowerCase();
          return status == 'requested' ||
              status == 'pending' ||
              status == 'approved';
        }).length;

    gdprPendingCount.value =
        gdprRequests.where((g) {
          final status = (g['status'] ?? '').toString().toLowerCase();
          return status == 'received' ||
              status == 'pending' ||
              status == 'identity-verified';
        }).length;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    var revenue = 0.0;

    if (transactions.isNotEmpty) {
      for (final tx in transactions) {
        final status = (tx['status'] ?? '').toString().toLowerCase();
        final type = (tx['type'] ?? '').toString().toLowerCase();
        if (status.isNotEmpty &&
            status != 'success' &&
            status != 'completed' &&
            status != 'paid') {
          continue;
        }
        if (type != 'payment' && type != 'credit') continue;

        final createdAt = _toDateTime(tx['createdAt']);
        if (createdAt != null && createdAt.isBefore(startOfMonth)) continue;

        revenue += _toDouble(tx['amount']);
      }
    } else {
      for (final booking in bookings) {
        final status = (booking['status'] ?? '').toString().toLowerCase();
        if (status == 'cancelled' || status == 'rejected') continue;

        final paymentStatus = (booking['paymentStatus'] ?? '').toString().toLowerCase();
        final paid = booking['paid'] == true;
        if (paymentStatus == 'unpaid') continue;
        if (paymentStatus.isEmpty && !paid && _toDouble(booking['amountPaid']) <= 0) continue;

        double amount = _toDouble(booking['amountPaid']);
        if (amount <= 0) {
          if (paid || (paymentStatus.isEmpty && status == 'completed')) {
            amount = _toDouble(booking['price'] ?? booking['amount']);
          }
        }
        if (amount <= 0) continue;

        final createdAt = _toDateTime(booking['createdAt']);
        if (createdAt != null && createdAt.isBefore(startOfMonth)) continue;

        revenue += amount;
      }
    }
    monthlyRevenue.value = revenue;
  }

  void _recomputeRecentActivity() {
    final activity = <Map<String, String>>[];

    final pendingApplications =
        trainerApplications.where((a) {
          final status = (a['status'] ?? 'pending').toString().toLowerCase();
          return status == 'pending';
        }).length;
    if (pendingApplications > 0) {
      activity.add({
        'title': 'Trainer verification queue updated',
        'subtitle': '$pendingApplications pending applications',
        'time': 'Live',
      });
    }

    if (supportOpenCount.value > 0) {
      activity.add({
        'title': 'Support backlog requires review',
        'subtitle': '${supportOpenCount.value} open support tickets',
        'time': 'Live',
      });
    }

    if (disputeOpenCount.value > 0) {
      activity.add({
        'title': 'Disputes awaiting action',
        'subtitle': '${disputeOpenCount.value} unresolved dispute cases',
        'time': 'Live',
      });
    }

    if (payoutPendingCount.value > 0 || refundPendingCount.value > 0) {
      activity.add({
        'title': 'Finance approvals pending',
        'subtitle':
            '${payoutPendingCount.value} payouts and ${refundPendingCount.value} refunds pending',
        'time': 'Live',
      });
    }

    if (gdprPendingCount.value > 0) {
      activity.add({
        'title': 'GDPR queue requires verification',
        'subtitle': '${gdprPendingCount.value} GDPR requests in progress',
        'time': 'Live',
      });
    }

    if (auditLogs.isNotEmpty) {
      final log = auditLogs.first;
      activity.add({
        'title':
            'Latest admin action: ${(log['action'] ?? 'update').toString()}',
        'subtitle': 'Actor ${(log['actorId'] ?? 'unknown').toString()}',
        'time': 'Now',
      });
    }

    if (activity.isEmpty) {
      activity.add({
        'title': 'Operations look healthy',
        'subtitle': 'No pending escalations right now',
        'time': 'Now',
      });
    }

    recentActivity.assignAll(activity.take(5));
  }

  void _checkAndCreateMissingRefunds() {
    if (bookings.isEmpty) return;

    final refundBookingIds = refunds
        .map((r) => r['bookingId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final booking in bookings) {
      final status = (booking['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled') {
        final bookingId = booking['id']?.toString() ?? '';
        if (bookingId.isNotEmpty &&
            !refundBookingIds.contains(bookingId) &&
            !_creatingRefundIds.contains(bookingId)) {
          _creatingRefundIds.add(bookingId);
          _createMissingRefund(booking);
        }
      }
    }
  }

  Future<void> _createMissingRefund(Map<String, dynamic> booking) async {
    final bookingId = booking['id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final paymentStatus = (booking['paymentStatus'] ?? '').toString().toLowerCase();
    final paid = booking['paid'] == true ||
                 paymentStatus == 'fully_paid' ||
                 paymentStatus == 'partially_paid';

    double amountPaid = (booking['amountPaid'] as num?)?.toDouble() ?? 0.0;
    if (amountPaid == 0.0 && paid) {
      amountPaid = (booking['price'] as num?)?.toDouble() ?? 0.0;
    }
    final userId = booking['userId']?.toString() ?? '';
    final trainerId = booking['trainerId']?.toString() ?? '';
    final trainerName = (booking['trainer'] ?? booking['trainerName'] ?? 'Trainer').toString();
    final clientName = (booking['clientName'] ?? booking['userName'] ?? 'Client').toString();

    if (userId.isNotEmpty && amountPaid > 0 && paid) {
      try {
        await _firestore.collection('refunds').add({
          'bookingId': bookingId,
          'userId': userId,
          'clientName': clientName,
          'trainerId': trainerId,
          'trainerName': trainerName,
          'amount': amountPaid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'sessionDate': (booking['date'] ?? '').toString(),
          'sessionTime': (booking['time'] ?? '').toString(),
          'sessionType': (booking['type'] ?? booking['sessionType'] ?? 'Session').toString(),
        });
        debugPrint('Auto-created missing refund for booking $bookingId');
      } catch (e) {
        _creatingRefundIds.remove(bookingId);
        debugPrint('Error creating missing refund: $e');
      }
    }
  }

  Future<void> resolveSupportTicket(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id']?.toString();
    if (ticketId == null || ticketId.isEmpty) return;

    await _guardedAction(
      action: 'support.resolve',
      targetId: ticketId,
      before: ticket,
      run: () async {
        await _firestore.collection('supportTickets').doc(ticketId).set({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Ticket resolved', 'Support ticket marked as resolved.');
      },
    );
  }

  Future<void> markSupportInProgress(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id']?.toString();
    if (ticketId == null || ticketId.isEmpty) return;

    await _guardedAction(
      action: 'support.in_progress',
      targetId: ticketId,
      before: ticket,
      run: () async {
        await _firestore.collection('supportTickets').doc(ticketId).set({
          'status': 'in_progress',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Ticket updated', 'Support ticket moved to in-progress.');
      },
    );
  }

  Future<void> assignDisputeToSelf(Map<String, dynamic> dispute) async {
    final disputeId = dispute['id']?.toString();
    if (disputeId == null || disputeId.isEmpty) return;

    await _guardedAction(
      action: 'dispute.assign_self',
      targetId: disputeId,
      before: dispute,
      run: () async {
        await _firestore.collection('disputes').doc(disputeId).set({
          'status': 'assigned',
          'assignedTo': FirebaseAuth.instance.currentUser?.uid,
          'assignedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Dispute assigned', 'Dispute assigned to your queue.');
      },
    );
  }

  Future<void> resolveDispute(Map<String, dynamic> dispute) async {
    final disputeId = dispute['id']?.toString();
    if (disputeId == null || disputeId.isEmpty) return;

    await _guardedAction(
      action: 'dispute.resolve',
      targetId: disputeId,
      before: dispute,
      run: () async {
        await _firestore.collection('disputes').doc(disputeId).set({
          'status': 'resolved',
          'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
          'resolvedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Dispute resolved', 'Dispute marked as resolved.');
      },
    );
  }

  Future<void> approveRefund(Map<String, dynamic> refund) async {
    await _setRefundStatus(refund, 'approved', 'Refund approved');
  }

  Future<void> rejectRefund(Map<String, dynamic> refund) async {
    await _setRefundStatus(refund, 'rejected', 'Refund rejected');
  }

  Future<void> processRefund(Map<String, dynamic> refund) async {
    await _setRefundStatus(refund, 'processed', 'Refund processed');
  }

  Future<void> _setRefundStatus(
    Map<String, dynamic> refund,
    String status,
    String message,
  ) async {
    final refundId = refund['id']?.toString();
    if (refundId == null || refundId.isEmpty) return;

    await _guardedAction(
      action: 'refund.$status',
      targetId: refundId,
      before: refund,
      run: () async {
        final batch = _firestore.batch();
        batch.set(_firestore.collection('refunds').doc(refundId), {
          'status': status,
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final currentStatus = (refund['status'] ?? '').toString().toLowerCase();
        final isAlreadyCredited = currentStatus == 'approved' || currentStatus == 'processed';

        if ((status == 'approved' || status == 'processed') && !isAlreadyCredited) {
          final userId = refund['userId']?.toString() ?? '';
          final amount = (refund['amount'] as num?)?.toDouble() ?? 0.0;
          if (userId.isNotEmpty && amount > 0) {
            final userDoc = await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() ?? {};
              final currentBalance = (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;
              final newBalance = currentBalance + amount;
              
              batch.update(_firestore.collection('users').doc(userId), {
                'walletBalance': newBalance,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              final trainerName = refund['trainerName']?.toString() ?? 'Trainer';
              batch.set(_firestore.collection('transactions').doc(), {
                'userId': userId,
                'title': 'Refund — $trainerName Session',
                'amount': amount,
                'type': 'credit',
                'date': _today(),
                'createdAt': FieldValue.serverTimestamp(),
              });

              batch.set(_firestore.collection('notifications').doc(userId).collection('items').doc(), {
                'title': 'Refund Processed',
                'body': 'Your refund of \$${amount.toStringAsFixed(0)} for session with $trainerName has been credited to your wallet.',
                'type': 'wallet',
                'color': 'sky',
                'icon': 'payment',
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });

              final trainerId = refund['trainerId']?.toString() ?? '';
              final clientName = refund['clientName']?.toString() ?? 'Client';
              if (trainerId.isNotEmpty) {
                batch.set(_firestore.collection('notifications').doc(trainerId).collection('items').doc(), {
                  'title': 'Refund Approved',
                  'body': 'Refund of \$${amount.toStringAsFixed(0)} for session with $clientName has been processed. This amount was cut from your earnings.',
                  'type': 'refund',
                  'color': 'red',
                  'icon': 'payment',
                  'read': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        }

        await batch.commit();
      },
      onSuccess: () {
        showSnackbar('Refund updated', message);
      },
    );
  }

  Future<void> rejectPayout(Map<String, dynamic> payout) async {
    await _setPayoutStatus(payout, 'rejected', 'Payout rejected');
  }

  /// Set user suspension status - used by the inline suspend button
  Future<void> setUserSuspended(Map<String, dynamic> user, bool suspend) async {
    final userId = user['id']?.toString();
    if (userId == null || userId.isEmpty) return;

    await _guardedAction(
      action: suspend ? 'user.suspend' : 'user.reactivate',
      targetId: userId,
      before: user,
      run: () async {
        await _firestore.collection('users').doc(userId).set({
          'accountStatus': suspend ? 'suspended' : 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar(
          suspend ? 'User suspended' : 'User reactivated',
          suspend
              ? 'Account has been suspended.'
              : 'Account access restored successfully.',
        );
      },
    );
  }

  Future<void> markPayoutPaid(Map<String, dynamic> payout) async {
    await _setPayoutStatus(payout, 'paid', 'Payout marked as paid');
  }

  Future<void> _setPayoutStatus(
    Map<String, dynamic> payout,
    String status,
    String message,
  ) async {
    final payoutId = payout['id']?.toString();
    if (payoutId == null || payoutId.isEmpty) return;

    await _guardedAction(
      action: 'payout.$status',
      targetId: payoutId,
      before: payout,
      run: () async {
        await _firestore.collection('payouts').doc(payoutId).set({
          'status': status,
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          if (status == 'paid') 'paidAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Payout updated', message);
      },
    );
  }

  Future<void> verifyGdprIdentity(Map<String, dynamic> request) async {
    await _setGdprStatus(
      request,
      'identity-verified',
      'GDPR identity verification completed.',
    );
  }

  Future<void> completeGdprRequest(Map<String, dynamic> request) async {
    await _setGdprStatus(request, 'completed', 'GDPR request marked complete.');
  }

  Future<void> _setGdprStatus(
    Map<String, dynamic> request,
    String status,
    String message,
  ) async {
    final requestId = request['id']?.toString();
    if (requestId == null || requestId.isEmpty) return;

    await _guardedAction(
      action: 'gdpr.$status',
      targetId: requestId,
      before: request,
      run: () async {
        await _firestore.collection('gdprRequests').doc(requestId).set({
          'status': status,
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          if (status == 'completed')
            'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('GDPR request updated', message);
      },
    );
  }

  Future<void> _guardedAction({
    required Future<void> Function() run,
    required String action,
    required String targetId,
    Map<String, dynamic>? before,
    void Function()? onSuccess,
  }) async {
    if (isActionLoading.value) return;
    isActionLoading.value = true;
    try {
      await run();
      await _writeAuditLog(
        action: action,
        targetId: targetId,
        before: before,
        after: {'result': 'success'},
        status: 'success',
      );
      onSuccess?.call();
    } catch (e, stack) {
      debugPrint('❌ Guarded action failed: $e\n$stack');
      await _writeAuditLog(
        action: action,
        targetId: targetId,
        before: before,
        after: {'result': 'failed', 'error': e.toString()},
        status: 'failed',
      );
      showSnackbar(
        'Action failed',
        'Unable to complete this action: $e',
      );
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> _writeAuditLog({
    required String action,
    required String targetId,
    required String status,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final requestId =
        '${DateTime.now().millisecondsSinceEpoch}-${targetId.hashCode.abs()}';

    try {
      await _firestore.collection('auditLogs').add({
        'actorId': uid,
        'action': action,
        'targetId': targetId,
        'before': before,
        'after': after,
        'status': status,
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Keep user flow responsive if audit write fails.
    }
  }

  DateTime? _toDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  // ─── WRAPPER METHODS FOR TAB COMPATIBILITY ────────────────────────────────

  /// Suspend a user by their ID
  Future<void> suspendUser(String userId, String reason) async {
    if (userId.isEmpty) return;

    final userList = users.where((u) => u['id'] == userId).toList();
    if (userList.isEmpty) return;

    final user = userList.first;
    await _guardedAction(
      action: 'user.suspend',
      targetId: userId,
      before: user,
      run: () async {
        await _firestore.collection('users').doc(userId).set({
          'accountStatus': 'suspended',
          'suspensionReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('User suspended', 'Account has been suspended.');
      },
    );
  }

  /// Reactivate a user by their ID
  Future<void> reactivateUser(String userId) async {
    if (userId.isEmpty) return;

    final userList = users.where((u) => u['id'] == userId).toList();
    if (userList.isEmpty) return;

    final user = userList.first;
    await _guardedAction(
      action: 'user.reactivate',
      targetId: userId,
      before: user,
      run: () async {
        await _firestore.collection('users').doc(userId).set({
          'accountStatus': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('User reactivated', 'Account access restored.');
      },
    );
  }

  /// Load bookings (real-time listeners handle this)
  Future<void> loadBookings() async {
    // Real-time listeners in _listenCollections() handle loading
  }

  /// Cancel a booking by its ID
  Future<void> cancelBooking(String bookingId, String reason) async {
    if (bookingId.isEmpty) return;

    final bookingList = bookings.where((b) => b['id'] == bookingId).toList();
    if (bookingList.isEmpty) return;

    final booking = bookingList.first;
    await _guardedAction(
      action: 'booking.cancel',
      targetId: bookingId,
      before: booking,
      run: () async {
        await _firestore.collection('bookings').doc(bookingId).set({
          'status': 'cancelled',
          'cancellationReason': reason,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': FirebaseAuth.instance.currentUser?.uid,
        }, SetOptions(merge: true));

        final paymentStatus = (booking['paymentStatus'] ?? '').toString().toLowerCase();
        final paid = booking['paid'] == true ||
                     paymentStatus == 'fully_paid' ||
                     paymentStatus == 'partially_paid';

        double amountPaid = (booking['amountPaid'] as num?)?.toDouble() ?? 0.0;
        if (amountPaid == 0.0 && paid) {
          amountPaid = (booking['price'] as num?)?.toDouble() ?? 0.0;
        }
        final userId = booking['userId']?.toString() ?? '';
        final trainerId = booking['trainerId']?.toString() ?? '';
        final trainerName = (booking['trainer'] ?? booking['trainerName'] ?? 'Trainer').toString();
        final clientName = (booking['clientName'] ?? booking['userName'] ?? 'Client').toString();

        if (userId.isNotEmpty && amountPaid > 0 && paid) {
          // Refund logic if booking is paid
          final refundDoc = await _firestore.collection('refunds').where('bookingId', isEqualTo: bookingId).get();
          if (refundDoc.docs.isEmpty) {
            await _firestore.collection('refunds').add({
              'bookingId': bookingId,
              'userId': userId,
              'clientName': clientName,
              'trainerId': trainerId,
              'trainerName': trainerName,
              'amount': amountPaid,
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
              'sessionDate': (booking['date'] ?? '').toString(),
              'sessionTime': (booking['time'] ?? '').toString(),
              'sessionType': (booking['type'] ?? booking['sessionType'] ?? 'Session').toString(),
            });
          }
        }

        final dateStr = (booking['date'] ?? '').toString();
        final timeStr = (booking['time'] ?? '').toString();

        // Notify Trainer
        if (trainerId.isNotEmpty) {
          await _firestore
              .collection('notifications')
              .doc(trainerId)
              .collection('items')
              .add({
            'title': 'Booking Cancelled by Admin',
            'body': 'Your session with $clientName on $dateStr at $timeStr has been cancelled by Admin.',
            'type': 'booking',
            'color': 'coral',
            'icon': 'calendar',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Notify Client
        if (userId.isNotEmpty) {
          await _firestore
              .collection('notifications')
              .doc(userId)
              .collection('items')
              .add({
            'title': 'Booking Cancelled by Admin',
            'body': 'Your session with $trainerName on $dateStr at $timeStr has been cancelled by Admin. \$${amountPaid.toStringAsFixed(0)} has been requested for refund.',
            'type': 'booking',
            'color': 'coral',
            'icon': 'calendar',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      },
      onSuccess: () {
        showSnackbar('Booking cancelled', 'Booking has been cancelled.');
      },
    );
  }

  /// Reassign a booking to a different trainer
  Future<void> reassignBooking(String bookingId, String trainerId) async {
    if (bookingId.isEmpty || trainerId.isEmpty) return;

    isActionLoading.value = true;
    try {
      await _firestore.collection('bookings').doc(bookingId).set({
        'trainerId': trainerId,
        'reassignedAt': FieldValue.serverTimestamp(),
        'reassignedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));
      showSnackbar('Reassigned', 'Booking reassigned to trainer.');
    } catch (_) {
      showSnackbar('Error', 'Unable to reassign booking.');
    } finally {
      isActionLoading.value = false;
    }
  }

  /// Load trainer applications (real-time listeners handle this)
  Future<void> loadTrainerApplications() async {
    // Real-time listeners in _listenCollections() handle loading
  }

  /// Approve a trainer application by its ID
  Future<void> approveTrainerApplication(String appId, String userId) async {
    if (appId.isEmpty || userId.isEmpty) return;

    final appList =
        trainerApplications.where((a) => a['id'] == appId).toList();
    if (appList.isEmpty) return;

    final app = appList.first;
    await _guardedAction(
      action: 'trainer_application.approve',
      targetId: appId,
      before: app,
      run: () async {
        // Update application status
        await _firestore.collection('trainerApplications').doc(appId).set({
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        }, SetOptions(merge: true));

        // Promote user to trainer role
        await _firestore.collection('users').doc(userId).set({
          'role': 'trainer',
          'trainerApproved': true,
          'accountStatus': 'active',
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Approved', 'Trainer application approved.');
      },
    );
  }

  /// Reject a trainer application by its ID
  Future<void> rejectTrainerApplication(String appId, String notes) async {
    if (appId.isEmpty) return;

    final appList =
        trainerApplications.where((a) => a['id'] == appId).toList();
    if (appList.isEmpty) return;

    final app = appList.first;
    await _guardedAction(
      action: 'trainer_application.reject',
      targetId: appId,
      before: app,
      run: () async {
        await _firestore.collection('trainerApplications').doc(appId).set({
          'status': 'rejected',
          'rejectionNotes': notes,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Rejected', 'Trainer application rejected.');
      },
    );
  }

  /// Dynamic user role modification method
  Future<void> changeUserRole(String userId, String newRole) async {
    if (userId.isEmpty || newRole.isEmpty) return;

    final userList = users.where((u) => u['id'] == userId).toList();
    if (userList.isEmpty) return;

    final user = userList.first;
    final cleanRole = newRole.toLowerCase();

    await _guardedAction(
      action: 'user.change_role',
      targetId: userId,
      before: user,
      run: () async {
        await _firestore.collection('users').doc(userId).set({
          'role': cleanRole,
          'trainerApproved': cleanRole == 'trainer',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      },
      onSuccess: () {
        showSnackbar('Role updated', 'User role updated to ${cleanRole.toUpperCase()}.');
      },
    );
  }

  /// Publish special platform promotion campaign
  Future<void> publishCampaignPromotion({
    required String title,
    required int discount,
    required String label,
  }) async {
    isActionLoading.value = true;
    try {
      await _firestore.collection('promotions').doc('activeCampaign').set({
        'title': title,
        'discount': '$discount\n%',
        'label': label.toUpperCase(),
        'isActive': true,
      }, SetOptions(merge: true));

      final userSnap = await _firestore.collection('users').get();
      final clientUsers = userSnap.docs.where((d) {
        final role = (d.data()['role'] ?? 'user').toString().toLowerCase();
        return role == 'user';
      }).toList();
      final batch = _firestore.batch();

      for (final client in clientUsers) {
        final clientUid = client.id;
        if (clientUid.isEmpty) continue;

        final ref = _firestore
            .collection('notifications')
            .doc(clientUid)
            .collection('items')
            .doc();

        batch.set(ref, {
          'title': 'New Special Promotion!',
          'body': 'A new platform promotion has been launched: $discount% off! Tap here to claim it now.',
          'type': 'promo',
          'color': 'neon',
          'icon': 'promo',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': 'admin',
          'senderName': 'Admin Platform',
          'senderPhotoUrl': '',
          'promoDiscountValue': discount,
        });
      }

      await batch.commit();

      await _firestore.collection('auditLogs').add({
        'action': 'publish_campaign',
        'details': 'Published campaign: "$title" with $discount% discount',
        'performedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── Send real FCM push to all devices via backend ──────────────────
      try {
        final idToken =
            await FirebaseAuth.instance.currentUser?.getIdToken();
        if (idToken != null) {
          final pushRes = await http
              .post(
                Uri.parse(
                    'https://gym-trainer-afeu.onrender.com/api/v1/admin/send-campaign-push'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                },
                body: jsonEncode({
                  'title': title,
                  'discount': discount,
                  'label': label,
                }),
              )
              .timeout(const Duration(seconds: 30));
          debugPrint(
              '📱 FCM push response: ${pushRes.statusCode} ${pushRes.body}');
        }
      } catch (pushErr) {
        // Push failure is non-critical — campaign is already published
        debugPrint('⚠️ FCM push failed (non-critical): $pushErr');
      }

      showSnackbar('Campaign published', 'All clients notified successfully.');
    } catch (e) {
      showSnackbar('Error', 'Failed to publish campaign.');
    } finally {
      isActionLoading.value = false;
    }
  }

  /// Mark a payout as paid by its ID
  Future<void> markPayoutAsPaid(String payoutId) async {
    if (payoutId.isEmpty) return;

    isActionLoading.value = true;
    try {
      await _firestore.collection('payouts').doc(payoutId).set({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'markedPaidBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));
      showSnackbar('Marked paid', 'Payout marked as paid.');
    } catch (_) {
      showSnackbar('Error', 'Unable to mark payout as paid.');
    } finally {
      isActionLoading.value = false;
    }
  }

  /// Load audit logs (real-time listeners handle this)
  Future<void> loadAuditLogs() async {
    // Real-time listeners in _listenCollections() handle loading
  }

  /// Search users by query (search filtering done in memories instead)
  Future<void> searchUsers() async {
    // The actual search filtering is done in the users_tab UI
    // This method exists for tab compatibility
  }

  /// Approve a payout
  Future<void> approvePayout(String payoutId) async {
    if (payoutId.isEmpty) return;

    isActionLoading.value = true;
    try {
      final payoutList = payouts.where((p) => p['id'] == payoutId).toList();
      if (payoutList.isEmpty) return;

      await _firestore.collection('payouts').doc(payoutId).set({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));
      showSnackbar('Approved', 'Payout approved successfully.');
    } catch (_) {
      showSnackbar('Error', 'Unable to approve payout.');
    } finally {
      isActionLoading.value = false;
    }
  }

  // ─── ALIASES FOR COMPATIBILITY ────────────────────────────────────────────
  RxBool get loadingUsers => isActionLoading;
  RxBool get loadingApplications => isActionLoading;
  RxBool get actionLoading => isActionLoading;
  RxBool get loadingBookings => isActionLoading;
  RxBool get loadingFinance => isActionLoading;

  String _today() {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    ref.read(routerProvider).go(Routes.LOGIN);
  }
}

final adminDashboardProvider = ChangeNotifierProvider((ref) {
  return AdminDashboardController(ref: ref);
});
