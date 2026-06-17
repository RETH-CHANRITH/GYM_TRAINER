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
