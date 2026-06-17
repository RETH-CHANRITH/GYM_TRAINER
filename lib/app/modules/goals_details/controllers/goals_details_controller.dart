import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoalsDetailsState {
  final int goalsCount;
  final List<Map<String, dynamic>> goals;

  GoalsDetailsState({
    required this.goalsCount,
    required this.goals,
  });

  GoalsDetailsState copyWith({
    int? goalsCount,
    List<Map<String, dynamic>>? goals,
  }) {
    return GoalsDetailsState(
      goalsCount: goalsCount ?? this.goalsCount,
      goals: goals ?? this.goals,
    );
  }
}

class GoalsDetailsNotifier extends AutoDisposeNotifier<GoalsDetailsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  GoalsDetailsState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });

    _listenToGoalsData();

    return GoalsDetailsState(goalsCount: 0, goals: []);
  }

  void _listenToGoalsData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sub = _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() ?? const <String, dynamic>{};
      final count = (data['goalsCount'] as num?)?.toInt() ?? 0;

      final sampleGoals = _generateSampleGoals(count);
      state = GoalsDetailsState(goalsCount: count, goals: sampleGoals);
    });
  }

  List<Map<String, dynamic>> _generateSampleGoals(int count) {
    final sampleGoals = <Map<String, dynamic>>[
      {
        'title': 'Build Upper Body Strength',
        'description': 'Focus on chest, shoulders, and arms',
        'progress': 65.0,
        'completed': false,
        'icon': Icons.fitness_center_rounded,
      },
      {
        'title': 'Improve Flexibility',
        'description': 'Daily yoga and stretching sessions',
        'progress': 40.0,
        'completed': false,
        'icon': Icons.self_improvement_rounded,
      },
      {
        'title': 'Run 5K in 25 mins',
        'description': 'Cardio endurance goal',
        'progress': 75.0,
        'completed': false,
        'icon': Icons.directions_run_rounded,
      },
      {
        'title': 'Lose 5 lbs',
        'description': 'Achieve fitness milestone',
        'progress': 50.0,
        'completed': false,
        'icon': Icons.monitor_weight_rounded,
      },
      {
        'title': 'Perfect Your Form',
        'description': 'Master proper lifting technique',
        'progress': 85.0,
        'completed': false,
        'icon': Icons.star_rounded,
      },
    ];

    if (count > 0) {
      return sampleGoals.take(count).toList();
    }
    return [];
  }
}

final goalsDetailsNotifierProvider = AutoDisposeNotifierProvider<GoalsDetailsNotifier, GoalsDetailsState>(() {
  return GoalsDetailsNotifier();
});
