import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/controllers/notifications_controller.dart';

class WalletState {
  final double balance;
  final double spentThisMonth;
  final int totalSessions;
  final int topUps;
  final List<Map<String, dynamic>> transactions;
  final bool isLoading;

  WalletState({
    required this.balance,
    required this.spentThisMonth,
    required this.totalSessions,
    required this.topUps,
    required this.transactions,
    required this.isLoading,
  });

  WalletState copyWith({
    double? balance,
    double? spentThisMonth,
    int? totalSessions,
    int? topUps,
    List<Map<String, dynamic>>? transactions,
    bool? isLoading,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      spentThisMonth: spentThisMonth ?? this.spentThisMonth,
      totalSessions: totalSessions ?? this.totalSessions,
      topUps: topUps ?? this.topUps,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WalletNotifier extends AutoDisposeNotifier<WalletState> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<QuerySnapshot>? _txSub;

  @override
  WalletState build() {
    ref.onDispose(() {
      _userSub?.cancel();
      _txSub?.cancel();
    });
    _listen();
    return WalletState(
      balance: 0.0,
      spentThisMonth: 0.0,
      totalSessions: 0,
      topUps: 0,
      transactions: const [],
      isLoading: true,
    );
  }

  void _listen() {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    _subscribeToUser(user.uid);
    _subscribeToTransactions(user.uid);
  }

  void _subscribeToUser(String uid) {
    _userSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
      final spent = (data['walletSpentThisMonth'] as num?)?.toDouble() ?? 0.0;
      state = state.copyWith(balance: balance, spentThisMonth: spent);
    }, onError: (_) => state = state.copyWith(isLoading: false));
  }

  void _subscribeToTransactions(String uid) {
    _txSub = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      final txs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      final sessions = txs
          .where((t) =>
              t['type'] == 'debit' &&
              (t['title'] as String? ?? '').startsWith('Session'))
          .length;
      final topUps =
          txs.where((t) => t['type'] == 'credit').length;
      state = state.copyWith(
        transactions: txs,
        totalSessions: sessions,
        topUps: topUps,
        isLoading: false,
      );
    }, onError: (_) => state = state.copyWith(isLoading: false));
  }

  List<Map<String, dynamic>> get trainerSummary {
    final Map<String, Map<String, dynamic>> map = {};
    for (final t in state.transactions) {
      if (t['type'] != 'debit' ||
          !(t['title'] as String? ?? '').startsWith('Session')) continue;
      final name = (t['title'] as String).replaceFirst('Session — ', '');
      final amount = ((t['amount'] as num?)?.toInt().abs()) ?? 0;
      if (map.containsKey(name)) {
        map[name]!['total'] = (map[name]!['total'] as int) + amount;
        map[name]!['count'] = (map[name]!['count'] as int) + 1;
      } else {
        map[name] = {
          'name': name,
          'total': amount,
          'count': 1,
          'portrait': t['portrait'],
          'trainerPhotoUrl': t['trainerPhotoUrl'],
        };
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return list;
  }

  Future<void> addFunds(
    double amount, {
    required void Function(String msg) onNotifyUser,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final newBalance = state.balance + amount;
    try {
      final batch = _firestore.batch();

      // Update wallet balance on user doc
      batch.update(_firestore.collection('users').doc(user.uid), {
        'walletBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write transaction record
      batch.set(_firestore.collection('transactions').doc(), {
        'userId': user.uid,
        'title': 'Top-up via Card',
        'amount': amount.toInt(),
        'type': 'credit',
        'date': _today(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _pushNotification(
        title: 'Deposit Successful',
        body:
            '\$${amount.toStringAsFixed(0)} has been added to your wallet. New balance: \$${newBalance.toStringAsFixed(2)}.',
        icon: 'payment',
        color: 'neon',
      );
      onNotifyUser('\$${amount.toStringAsFixed(0)} added to your wallet.');
    } catch (_) {
      onNotifyUser('Failed to add funds. Please try again.');
    }
  }

  bool payForSession(
    String trainerName,
    int amount, {
    int? portrait,
    String? trainerPhotoUrl,
    required void Function(String msg) onNotifyUser,
  }) {
    if (amount > state.balance) {
      onNotifyUser('Top up your wallet to pay for this session.');
      return false;
    }
    _writeSessionPayment(trainerName, amount, portrait: portrait, trainerPhotoUrl: trainerPhotoUrl);
    return true;
  }

  Future<void> _writeSessionPayment(
    String trainerName,
    int amount, {
    int? portrait,
    String? trainerPhotoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final newBalance = state.balance - amount;
    final newSpent = state.spentThisMonth + amount;
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user.uid), {
        'walletBalance': newBalance,
        'walletSpentThisMonth': newSpent,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final txData = {
        'userId': user.uid,
        'title': 'Session — $trainerName',
        'amount': -amount,
        'type': 'debit',
        'date': _today(),
        'createdAt': FieldValue.serverTimestamp(),
        if (portrait != null) 'portrait': portrait,
        if (trainerPhotoUrl != null && trainerPhotoUrl.isNotEmpty) 'trainerPhotoUrl': trainerPhotoUrl,
      };
      batch.set(_firestore.collection('transactions').doc(), txData);
      await batch.commit();
    } catch (_) {}
  }

  Future<void> withdraw(
    double amount, {
    required void Function(String msg) onNotifyUser,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (amount > state.balance) {
      onNotifyUser("You don't have enough funds.");
      return;
    }
    final newBalance = state.balance - amount;
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user.uid), {
        'walletBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('transactions').doc(), {
        'userId': user.uid,
        'title': 'Withdrawal',
        'amount': -amount.toInt(),
        'type': 'debit',
        'date': _today(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      _pushNotification(
        title: 'Withdrawal Submitted',
        body:
            '\$${amount.toStringAsFixed(0)} withdrawal is being processed. Funds arrive in 1-3 business days.',
        icon: 'payment',
        color: 'sky',
      );
      onNotifyUser(
          '\$${amount.toStringAsFixed(0)} will arrive in 1-3 business days.');
    } catch (_) {
      onNotifyUser('Withdrawal failed. Please try again.');
    }
  }

  void _pushNotification({
    required String title,
    required String body,
    required String icon,
    required String color,
  }) {
    ref.read(notificationsNotifierProvider.notifier).addNotification({
      'title': title,
      'body': body,
      'time': 'Just now',
      'icon': icon,
      'read': false,
      'color': color,
      'route': '/wallet',
      'routeArgs': null,
    });
  }

  String _today() {
    final now = DateTime.now();
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month]} ${now.day}, ${now.year}';
  }
}

final walletNotifierProvider =
    AutoDisposeNotifierProvider<WalletNotifier, WalletState>(
  () => WalletNotifier(),
);
