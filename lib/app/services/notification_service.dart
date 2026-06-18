import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import 'user_role_service.dart';

// ─── Background FCM handler (top-level, required by FCM) ──────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // App is in background/terminated — FCM shows the notification automatically
  // via the system tray. No extra work needed here unless you want data-only msgs.
  debugPrint('📩 FCM background message: ${message.messageId}');
}

/// Central service for native device notifications + deep-link navigation.
/// Handles both flutter_local_notifications (in-app) and FCM (push).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const _channelId = 'gym_trainer_channel';
  static const _channelName = 'Gym Trainer Notifications';
  static const _channelDesc = 'Activity alerts: likes, comments, bookings, chat';

  bool _initialized = false;

  // ─── Initialize ────────────────────────────────────────────────────────────

  /// Call once in main() before runApp.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Register FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request FCM permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 3. Init flutter_local_notifications (for foreground display)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // 4. Create high-importance Android channel
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

    // 5. Request permissions on iOS
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // 6. Request permissions on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 7. FCM foreground messages → show as local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 8. App opened from notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);

    // 9. App opened from terminated state via notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      // Slight delay so router is ready
      await Future.delayed(const Duration(milliseconds: 800));
      _handleNotificationOpenedApp(initial);
    }

    debugPrint('✅ NotificationService initialized (FCM + Local)');
  }

  // ─── Save FCM token to Firestore ───────────────────────────────────────────

  /// Call after user logs in to save their FCM token.
  Future<void> saveFcmToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final token = await _fcm.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcmToken': token, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      debugPrint('✅ FCM token saved: ${token.substring(0, 20)}...');

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null) return;
        await FirebaseFirestore.instance.collection('users').doc(currentUid).set(
          {'fcmToken': newToken, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        debugPrint('🔄 FCM token refreshed');
      });
    } catch (e) {
      debugPrint('⚠️ Failed to save FCM token: $e');
    }
  }

  /// Remove FCM token when user logs out.
  Future<void> clearFcmToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcmToken': FieldValue.delete()},
        SetOptions(merge: true),
      );
      await _fcm.deleteToken();
      debugPrint('🗑️ FCM token cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear FCM token: $e');
    }
  }

  // ─── FCM foreground handler ────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    final data = message.data;
    final title = notif?.title ?? data['title'] ?? 'Gym Trainer';
    final body = notif?.body ?? data['body'] ?? '';
    final type = data['type'] ?? 'general';

    showNotification(
      title: title,
      body: body,
      routePayload: {'type': type, ...data},
    );
  }

  void _handleNotificationOpenedApp(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? 'general';
    navigateFromPayload({'type': type, ...data});
  }

  // ─── Show native OS notification ───────────────────────────────────────────

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

      await _plugin.show(_notifId++, title, body, details,
          payload: payloadStr);
    } catch (e) {
      debugPrint('❌ Error displaying native local notification: $e');
    }
  }

  // ─── Navigation on tap ─────────────────────────────────────────────────────

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      navigateFromPayload(map);
    } catch (_) {}
  }

  /// Navigate based on a decoded payload map.
  void navigateFromPayload(Map<String, dynamic> payload) async {
    final nav = rootNavigatorKey.currentContext;
    if (nav == null) return;

    final type = (payload['type'] ?? '').toString();
    final postId = payload['postId']?.toString() ?? '';
    final trainerName = payload['trainerName']?.toString() ?? 'Trainer';
    final otherId =
        (payload['otherId'] ?? payload['senderId'] ?? '').toString();
    final otherName =
        (payload['otherName'] ?? payload['senderName'] ?? '').toString();
    final otherPhoto =
        (payload['otherPhoto'] ?? payload['senderPhotoUrl'] ?? '').toString();

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
            GoRouter.of(nav).go(
              '${Routes.TRAINER_DASHBOARD}?postId=$postId&trainerName=${Uri.encodeComponent(trainerName)}',
            );
          } else {
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
        // Promo notification → go home to see/claim the banner
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
