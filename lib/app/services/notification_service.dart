import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../routes/app_router.dart';
import 'user_role_service.dart';

/// Central service for native device notifications + deep-link navigation.
/// Works for all roles: user, trainer, admin.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'gym_trainer_channel';
  static const _channelName = 'Gym Trainer Notifications';
  static const _channelDesc = 'Activity alerts: likes, comments, bookings, chat';

  bool _initialized = false;

  /// Call once in main() before runApp.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    // Create high-importance Android channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableLights: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Request permissions on iOS
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Request permissions on Android 13+ (API 33+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('✅ NotificationService initialized');
  }

  // ─── Show native OS notification ─────────────────────────────────────────

  int _notifId = 0;

  Future<void> showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> routePayload,
  }) async {
    try {
      final payloadStr = jsonEncode(routePayload);

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        styleInformation: BigTextStyleInformation(''),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(_notifId++, title, body, details, payload: payloadStr);
    } catch (e) {
      debugPrint('❌ Error displaying native local notification: $e');
    }
  }

  // ─── Navigation on tap ───────────────────────────────────────────────────

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      navigateFromPayload(map);
    } catch (_) {}
  }

  /// Navigate based on a decoded payload map.
  /// Called both from device-notification taps and in-app banner taps.
  void navigateFromPayload(Map<String, dynamic> payload) async {
    final nav = rootNavigatorKey.currentContext;
    if (nav == null) return;

    final type = (payload['type'] ?? '').toString();
    final postId = payload['postId']?.toString() ?? '';
    final trainerName = payload['trainerName']?.toString() ?? 'Trainer';
    final otherId = (payload['otherId'] ?? payload['senderId'] ?? '').toString();
    final otherName = (payload['otherName'] ?? payload['senderName'] ?? '').toString();
    final otherPhoto = (payload['otherPhoto'] ?? payload['senderPhotoUrl'] ?? '').toString();

    final user = FirebaseAuth.instance.currentUser;
    String role = 'user';
    if (user != null) {
      try {
        role = await UserRoleService().getCachedRole(user);
      } catch (_) {}
    }

    switch (type) {
      case 'like':
      case 'comment':
        if (postId.isNotEmpty) {
          if (role == 'trainer') {
            // Open trainer dashboard with auto-open post comments sheet
            GoRouter.of(nav).go(
              '${Routes.TRAINER_DASHBOARD}?postId=$postId&trainerName=${Uri.encodeComponent(trainerName)}',
            );
          } else {
            // Open user home with auto-open post comments sheet
            GoRouter.of(nav).go(
              '${Routes.HOME}?postId=$postId&trainerName=${Uri.encodeComponent(trainerName)}',
            );
          }
        } else {
          GoRouter.of(nav).push(Routes.NOTIFICATIONS);
        }
        break;

      case 'chat':
      case 'message':
        if (otherId.isNotEmpty) {
          GoRouter.of(nav).push(
            Routes.MESSAGE_SCREEN,
            extra: {
              'otherId': otherId,
              'name': otherName,
              'photoUrl': otherPhoto,
            },
          );
        } else {
          GoRouter.of(nav).push(Routes.NOTIFICATIONS);
        }
        break;

      case 'booking':
        if (role == 'trainer') {
          GoRouter.of(nav).go('${Routes.TRAINER_DASHBOARD}?tab=bookings');
        } else {
          GoRouter.of(nav).push(Routes.MY_BOOKINGS);
        }
        break;

      case 'payment':
        if (role == 'trainer') {
          GoRouter.of(nav).go('${Routes.TRAINER_DASHBOARD}?tab=payouts');
        } else {
          GoRouter.of(nav).push(Routes.WALLET);
        }
        break;

      case 'refund':
        if (role == 'trainer') {
          GoRouter.of(nav).go('${Routes.TRAINER_DASHBOARD}?tab=payouts');
        } else {
          GoRouter.of(nav).push(Routes.WALLET);
        }
        break;

      case 'review':
        if (role == 'trainer') {
          GoRouter.of(nav).go('${Routes.TRAINER_DASHBOARD}?tab=studio');
        } else {
          GoRouter.of(nav).push(Routes.TRAINER_DASHBOARD);
        }
        break;

      case 'promo':
        GoRouter.of(nav).go(Routes.HOME);
        break;

      default:
        GoRouter.of(nav).push(Routes.NOTIFICATIONS);
        break;
    }
  }
}

/// Top-level handler required by flutter_local_notifications for background taps.
@pragma('vm:entry-point')
void _onBackgroundTap(NotificationResponse response) {
  // Navigation is handled when app opens via onDidReceiveNotificationResponse
}
