import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bookings_service.dart' as bs;
import '../services/favourites_service.dart' as fs;
import '../services/user_profile_service.dart' as ups;
import '../services/user_role_service.dart' as urs;
import '../services/user_support_service.dart' as uss;

final bookingsServiceProvider = bs.bookingsServiceProvider;
final favouritesServiceProvider = fs.favouritesServiceProvider;
final userProfileServiceProvider = ups.userProfileServiceProvider;

final userRoleServiceProvider = Provider<urs.UserRoleService>((ref) {
  return urs.UserRoleService();
});

final userSupportServiceProvider = uss.userSupportServiceProvider;

final userTrainerApplicationProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('trainerApplications')
      .where('userId', isEqualTo: user.uid)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        return {'id': snap.docs.first.id, ...snap.docs.first.data()};
      });
});
