import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreakDetailsState {
  final int streak;
  final List<Map<String, dynamic>> streakHistory;

  StreakDetailsState({
    required this.streak,
    required this.streakHistory,
  });

  StreakDetailsState copyWith({
    int? streak,
    List<Map<String, dynamic>>? streakHistory,
  }) {
    return StreakDetailsState(
      streak: streak ?? this.streak,
      streakHistory: streakHistory ?? this.streakHistory,
    );
  }
}

class StreakDetailsNotifier extends AutoDisposeNotifier<StreakDetailsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  StreakDetailsState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });

    _listenToStreakData();

    return StreakDetailsState(streak: 0, streakHistory: []);
  }

  void _listenToStreakData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sub = _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() ?? const <String, dynamic>{};
      final streakVal = (data['streak'] as num?)?.toInt() ?? 0;

      final history = <Map<String, dynamic>>[];
      for (int i = 0; i < streakVal; i++) {
        final daysAgo = streakVal - 1 - i;
        final date = DateTime.now().subtract(Duration(days: daysAgo));
        history.add({
          'date': date,
          'day': date.toString().split(' ')[0],
          'dayOfWeek':
              ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1],
          'completed': true,
        });
      }

      state = StreakDetailsState(streak: streakVal, streakHistory: history);
    });
  }
}

final streakDetailsNotifierProvider = AutoDisposeNotifierProvider<StreakDetailsNotifier, StreakDetailsState>(() {
  return StreakDetailsNotifier();
});
