import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationPermissionNotifier extends AutoDisposeNotifier<bool> {
  @override
  bool build() {
    return false;
  }

  void toggleNotification(bool value) {
    state = value;
  }
}

final notificationPermissionProvider = AutoDisposeNotifierProvider<NotificationPermissionNotifier, bool>(() {
  return NotificationPermissionNotifier();
});
