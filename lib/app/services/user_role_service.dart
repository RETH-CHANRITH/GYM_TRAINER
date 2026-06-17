import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserRoleService {
  UserRoleService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _roleCachePrefix = 'user_role_';
  static const _profileCompletedPrefix = 'profile_completed_';

  /// Returns the cached role instantly from SharedPreferences (never blocks on network).
  Future<String> getCachedRole(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_roleCachePrefix${user.uid}') ?? 'user';
    return _normalizeRole(raw);
  }

  /// Returns true if the user has completed their profile setup (gender, age, etc.).
  /// Reads from local cache first for speed; falls back to Firestore if no cache entry.
  Future<bool> isProfileComplete(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_profileCompletedPrefix${user.uid}';

    // If we have a definitive cached true, return immediately.
    if (prefs.getBool(cacheKey) == true) return true;

    // Otherwise check Firestore (new install or cache cleared).
    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      if (!snap.exists) return false;
      final completed = snap.data()?['profileCompleted'] == true;
      if (completed) {
        await prefs.setBool(cacheKey, true);
      }
      return completed;
    } catch (_) {
      return false;
    }
  }

  /// Marks the user's profile as complete in Firestore and local cache.
  Future<void> markProfileComplete(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_profileCompletedPrefix${user.uid}', true);
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'profileCompleted': true}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Local cache already set — will sync next time.
    }
  }

  /// Checks if the trainer's profile is complete.
  Future<bool> isTrainerProfileComplete(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'trainer_profile_completed_${user.uid}';

    if (prefs.getBool(cacheKey) == true) return true;

    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      if (!snap.exists) return false;
      final completed = snap.data()?['trainerProfileComplete'] == true;
      if (completed) {
        await prefs.setBool(cacheKey, true);
      }
      return completed;
    } catch (_) {
      return false;
    }
  }

  /// Marks the trainer's profile as complete in Firestore and local cache.
  Future<void> markTrainerProfileComplete(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trainer_profile_completed_${user.uid}', true);
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'trainerProfileComplete': true}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 6));
    } catch (_) {
    }
  }

  /// Fetches the role from Firestore and updates cache. Runs in the background.
  Future<void> refreshRoleInBackground(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final ref = _firestore.collection('users').doc(user.uid);
    try {
      final snap = await ref
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 6));

      final nameToUse = (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : (user.email?.isNotEmpty == true ? user.email!.split('@').first : 'User');

      if (!snap.exists) {
        try {
          await ref
              .set({
                'name': nameToUse,
                'email': user.email ?? '',
                'photoUrl': user.photoURL ?? '',
                'role': 'user',
                'isActive': true,
                'profileCompleted': false,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              })
              .timeout(const Duration(seconds: 6));
        } catch (_) {
          // Ignore write failures when offline.
        }
        await prefs.setString('$_roleCachePrefix${user.uid}', 'user');
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};
      
      // Auto-heal empty, "User" or "Unknown" names
      final existingName = (data['name'] as String? ?? '').trim();
      if (existingName.isEmpty || existingName == 'User' || existingName == 'Unknown') {
        if (nameToUse != 'User') {
          try {
            await ref.update({
              'name': nameToUse,
              'updatedAt': FieldValue.serverTimestamp(),
            }).timeout(const Duration(seconds: 4));
          } catch (_) {}
        }
      }

      // Auto-heal empty photoUrl
      final existingPhoto = (data['photoUrl'] as String? ?? '').trim();
      if (existingPhoto.isEmpty && user.photoURL?.trim().isNotEmpty == true) {
        try {
          await ref.update({
            'photoUrl': user.photoURL!.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      final rawRole = (data['role'] ?? 'user').toString().toLowerCase();
      final role = _normalizeRole(rawRole);
      await prefs.setString('$_roleCachePrefix${user.uid}', role);
    } catch (_) {
      // Silently ignore — cached role remains valid.
    }
  }

  /// Legacy blocking method kept for compatibility.
  Future<String> ensureAndGetRole(User user, {String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString('$_roleCachePrefix${user.uid}') ?? 'user';
    final cachedRole = _normalizeRole(cachedRaw);

    final ref = _firestore.collection('users').doc(user.uid);
    try {
      final snap = await ref
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 4));

      final nameToUse = (displayName?.trim().isNotEmpty == true)
          ? displayName!.trim()
          : ((user.displayName?.trim().isNotEmpty == true)
              ? user.displayName!.trim()
              : (user.email?.isNotEmpty == true ? user.email!.split('@').first : 'User'));

      if (!snap.exists) {
        try {
          await ref
              .set({
                'name': nameToUse,
                'email': user.email ?? '',
                'photoUrl': user.photoURL ?? '',
                'role': 'user',
                'isActive': true,
                'profileCompleted': false,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              })
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          // Ignore write failures when offline; default user role still works.
        }
        await prefs.setString('$_roleCachePrefix${user.uid}', 'user');
        return 'user';
      }

      final data = snap.data() ?? <String, dynamic>{};
      
      // Auto-heal empty, "User" or "Unknown" names
      final existingName = (data['name'] as String? ?? '').trim();
      if (existingName.isEmpty || existingName == 'User' || existingName == 'Unknown') {
        if (nameToUse != 'User') {
          try {
            await ref.update({
              'name': nameToUse,
              'updatedAt': FieldValue.serverTimestamp(),
            }).timeout(const Duration(seconds: 4));
            data['name'] = nameToUse;
          } catch (_) {}
        }
      }

      // Auto-heal empty photoUrl
      final existingPhoto = (data['photoUrl'] as String? ?? '').trim();
      if (existingPhoto.isEmpty && user.photoURL?.trim().isNotEmpty == true) {
        try {
          await ref.update({
            'photoUrl': user.photoURL!.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 4));
          data['photoUrl'] = user.photoURL!.trim();
        } catch (_) {}
      }

      final rawRole = (data['role'] ?? 'user').toString().toLowerCase();
      final role = _normalizeRole(rawRole);
      await prefs.setString('$_roleCachePrefix${user.uid}', role);

      return role;
    } catch (_) {
      return cachedRole;
    }
  }

  String _normalizeRole(String role) {
    switch (role) {
      case 'trainer':
      case 'admin':
      case 'user':
        return role;
      default:
        return 'user';
    }
  }
}
