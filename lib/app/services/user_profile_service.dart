import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileState {
  final String name;
  final String email;
  final String photoUrl;
  final bool isUploadingPhoto;
  final String gender;
  final int age;
  final int weight;
  final int height;
  final String fitnessGoal;
  final String activityLevel;
  final String fitnessLevel;
  final String role;

  UserProfileState({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isUploadingPhoto,
    required this.gender,
    required this.age,
    required this.weight,
    required this.height,
    required this.fitnessGoal,
    required this.activityLevel,
    required this.fitnessLevel,
    required this.role,
  });

  UserProfileState copyWith({
    String? name,
    String? email,
    String? photoUrl,
    bool? isUploadingPhoto,
    String? gender,
    int? age,
    int? weight,
    int? height,
    String? fitnessGoal,
    String? activityLevel,
    String? fitnessLevel,
    String? role,
  }) {
    return UserProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      role: role ?? this.role,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  final _auth = fa.FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  StreamSubscription<fa.User?>? _authSub;
  // Real-time Firestore listener — lives as long as the user is logged in.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  @override
  UserProfileState build() {
    ref.onDispose(() {
      _authSub?.cancel();
      _profileSub?.cancel();
    });

    final initialState = UserProfileState(
      name: 'User',
      email: '',
      photoUrl: '',
      isUploadingPhoto: false,
      gender: 'Male',
      age: 25,
      weight: 70,
      height: 170,
      fitnessGoal: 'Muscle Gain',
      activityLevel: 'Moderately Active',
      fitnessLevel: 'Intermediate',
      role: 'user',
    );

    final currentUser = _auth.currentUser;
    UserProfileState stateWithUser = initialState;
    if (currentUser != null) {
      stateWithUser = _getAuthUserState(currentUser, initialState);
      // Subscribe to real-time Firestore stream.
      _subscribeToProfile(currentUser);
    }

    // Listen to auth changes to attach/detach the Firestore stream.
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        // User logged out — cancel Firestore stream and reset sensitive fields.
        _profileSub?.cancel();
        _profileSub = null;
        state = state.copyWith(name: 'User', email: '', photoUrl: '');
      } else {
        // User logged in (or token refreshed) — update basic auth fields and
        // attach a fresh real-time stream.
        state = _getAuthUserState(user, state);
        _subscribeToProfile(user);
      }
    });

    return stateWithUser;
  }

  /// Attaches a **real-time** Firestore listener to `users/{uid}`.
  /// Every time a field changes in Firestore (from any device/session),
  /// the Riverpod state — and therefore all `ref.watch()` widgets — updates
  /// instantly without any manual refresh.
  void _subscribeToProfile(fa.User user) {
    // Cancel previous subscription to avoid duplicate listeners.
    _profileSub?.cancel();

    _profileSub = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots() // 🔥 Real-time stream
        .listen(
      (snap) {
        if (!snap.exists) return;
        final d = snap.data() ?? <String, dynamic>{};

        // Merge Firestore fields into Riverpod state.
        // Only override values that actually exist in Firestore (so local
        // optimistic updates are not wiped while Firestore is still writing).
        state = state.copyWith(
          name: _str(d['name']) ?? state.name,
          gender: _str(d['gender']) ?? state.gender,
          age: _toInt(d['age']) ?? state.age,
          weight: _toInt(d['weight']) ?? state.weight,
          height: _toInt(d['height']) ?? state.height,
          fitnessGoal: _str(d['fitnessGoal']) ?? state.fitnessGoal,
          activityLevel: _str(d['activityLevel']) ?? state.activityLevel,
          fitnessLevel: _str(d['fitnessLevel']) ?? state.fitnessLevel,
          photoUrl: _str(d['photoUrl']) ?? state.photoUrl,
          role: _str(d['role']) ?? state.role,
        );
      },
      onError: (_) {
        // Silently ignore network errors — last known state remains.
      },
    );
  }

  UserProfileState _getAuthUserState(fa.User user, UserProfileState currentState) {
    final display = user.displayName?.trim() ?? '';
    final mail = user.email?.trim() ?? '';
    String name = currentState.name;
    if (display.isNotEmpty) {
      name = display;
    } else if (mail.isNotEmpty) {
      name = mail.split('@').first;
    }
    return currentState.copyWith(
      name: name,
      email: mail,
      photoUrl: user.photoURL?.trim() ?? '',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ── Individual setters (used during onboarding steps) ──────────────────────
  void setGender(String gender) => state = state.copyWith(gender: gender);
  void setAge(int age) => state = state.copyWith(age: age);
  void setWeight(int weight) => state = state.copyWith(weight: weight);
  void setHeight(int height) => state = state.copyWith(height: height);
  void setFitnessGoal(String goal) => state = state.copyWith(fitnessGoal: goal);
  void setActivityLevel(String level) => state = state.copyWith(activityLevel: level);
  void setFitnessLevel(String level) => state = state.copyWith(fitnessLevel: level);

  /// Saves ALL profile fields to Firestore.
  /// The real-time listener will immediately reflect the change back to the UI,
  /// so every screen that does `ref.watch(userProfileServiceProvider)` updates
  /// within milliseconds — even on other devices.
  Future<void> saveFullProfile({
    required String fullName,
    required String selectedGender,
    required int selectedAge,
    required int selectedWeight,
    required int selectedHeight,
    required String selectedGoal,
    required String selectedActivity,
    required String selectedFitness,
  }) async {
    // Optimistic local update first — UI reacts instantly.
    state = state.copyWith(
      name: fullName,
      gender: selectedGender,
      age: selectedAge,
      weight: selectedWeight,
      height: selectedHeight,
      fitnessGoal: selectedGoal,
      activityLevel: selectedActivity,
      fitnessLevel: selectedFitness,
    );

    final current = _auth.currentUser;
    if (current == null) return;

    // Update Firebase Auth display name if changed.
    if (fullName.trim().isNotEmpty && current.displayName != fullName.trim()) {
      try {
        await current.updateDisplayName(fullName.trim());
      } catch (_) {}
    }

    // Write to Firestore → real-time stream fires → other devices/tabs update.
    try {
      await _firestore.collection('users').doc(current.uid).set({
        'name': fullName.trim(),
        'gender': selectedGender,
        'age': selectedAge,
        'weight': selectedWeight,
        'height': selectedHeight,
        'fitnessGoal': selectedGoal,
        'activityLevel': selectedActivity,
        'fitnessLevel': selectedFitness,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Optimistic state already set above — will sync when back online.
    }
  }

  /// Legacy alias kept for compatibility with profile edit sheet.
  Future<void> updateProfile({
    required String fullName,
    required String selectedGender,
    required int selectedAge,
    required int selectedWeight,
    required int selectedHeight,
    required String selectedGoal,
    required String selectedActivity,
    required String selectedFitness,
  }) async {
    await saveFullProfile(
      fullName: fullName,
      selectedGender: selectedGender,
      selectedAge: selectedAge,
      selectedWeight: selectedWeight,
      selectedHeight: selectedHeight,
      selectedGoal: selectedGoal,
      selectedActivity: selectedActivity,
      selectedFitness: selectedFitness,
    );
  }

  Future<bool> pickAndUploadProfilePhoto({
    required void Function(String title, String message) onNotification,
  }) async {
    final current = _auth.currentUser;
    if (current == null) {
      onNotification('Login required', 'Please login first to update photo.');
      return false;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked == null) return false;

    state = state.copyWith(isUploadingPhoto: true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final safeExt = ext.isEmpty ? 'jpg' : ext;
      final path =
          'profiles/${current.uid}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

      await _supabase.storage
          .from('images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFor(safeExt),
            ),
          );

      final publicUrl = _supabase.storage.from('images').getPublicUrl(path);
      await current.updatePhotoURL(publicUrl);

      // Persist to Firestore — real-time stream updates the UI everywhere.
      await _firestore.collection('users').doc(current.uid).set({
        'photoUrl': publicUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      state = state.copyWith(photoUrl: publicUrl);
      onNotification('Updated', 'Profile image updated successfully.');
      return true;
    } catch (_) {
      onNotification('Upload failed', 'Could not upload profile image.');
      return false;
    } finally {
      state = state.copyWith(isUploadingPhoto: false);
    }
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default: return 'image/jpeg';
    }
  }
}

final userProfileServiceProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(
  () => UserProfileNotifier(),
);
