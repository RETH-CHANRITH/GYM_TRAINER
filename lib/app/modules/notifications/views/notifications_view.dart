import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../config/glass_ui.dart';
import '../controllers/notifications_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/notification_service.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
const Color ink = Color(0xFF0A0A0F);
const Color surface = Color(0xFF111118);
const Color card = Color(0xFF17171F);
const Color raised = Color(0xFF1E1E28);
const Color stroke = Color(0xFF2A2A36);
const Color neon = Color(0xFFCBFF47);
const Color coral = Color(0xFFFF5C5C);
const Color sky = Color(0xFF5CE8FF);
const Color lilac = Color(0xFFA78BFA);
const Color muted = Color(0xFF6B6B7E);
const Color gold = Color(0xFFFFBB33);

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsNotifierProvider);
    final controller = ref.read(notificationsNotifierProvider.notifier);
    final unread = state.unreadCount;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
    final surface = isDark ? const Color(0xFF111118) : const Color(0xFFFFFFFF);
    final card = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final raised = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final neon = Theme.of(context).colorScheme.primary;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black45;
    final text = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: text),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Notifications',
          style: TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: controller.markAllRead,
            child: Text(
              'Mark all read',
              style: TextStyle(color: neon, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          Column(
            children: [
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: neon.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neon.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.bell_fill,
                        color: neon,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$unread unread notification${unread > 1 ? "s" : ""}',
                        style: TextStyle(
                          color: neon,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  itemCount: state.notifications.length,
                  itemBuilder: (_, i) => _buildNotifCard(context, state.notifications[i], controller),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNotificationTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    }

    if (dt == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Widget _buildNotifCard(BuildContext context, Map<String, dynamic> n, NotificationsNotifier controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
    final raised = isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
    final stroke = isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
    final neon = Theme.of(context).colorScheme.primary;
    final muted = isDark ? const Color(0xFF6B6B7E) : Colors.black45;
    final text = isDark ? Colors.white : Colors.black87;

    final isRead = n['read'] == true;
    final colorKey = (n['color'] ?? n['type'] ?? 'lilac').toString();
    final Color accentColor = colorKey == 'neon'
        ? neon
        : colorKey == 'sky' || colorKey == 'booking'
            ? sky
            : colorKey == 'coral' || colorKey == 'like'
                ? coral
                : colorKey == 'gold' || colorKey == 'payment'
                    ? gold
                    : colorKey == 'comment'
                        ? lilac
                        : lilac;

    final iconKey = (n['icon'] ?? n['type'] ?? 'bell').toString();
    final IconData icon = iconKey == 'calendar' || iconKey == 'booking'
        ? CupertinoIcons.calendar
        : iconKey == 'alarm'
            ? CupertinoIcons.alarm_fill
            : iconKey == 'payment'
                ? CupertinoIcons.creditcard_fill
                : iconKey == 'chat' || iconKey == 'comment'
                    ? CupertinoIcons.chat_bubble_fill
                    : iconKey == 'review'
                        ? CupertinoIcons.star_fill
                        : iconKey == 'promo'
                            ? CupertinoIcons.gift_fill
                            : iconKey == 'check'
                                ? CupertinoIcons.checkmark_circle_fill
                                : iconKey == 'bell' || iconKey == 'like'
                                    ? CupertinoIcons.bell_fill
                                    : iconKey == 'clock'
                                        ? CupertinoIcons.clock_fill
                                        : CupertinoIcons.bell_fill;

    final timeStr = n['time'] != null
        ? n['time'].toString()
        : _formatNotificationTime(n['createdAt']);

    final rawPhoto = n['senderPhotoUrl'];
    final name = (n['senderName'] ?? '').toString();
    String photoUrl = '';
    if (rawPhoto != null) {
      final rawStr = rawPhoto.toString().trim();
      if (rawStr.isNotEmpty) {
        if (rawStr.startsWith('http://') || rawStr.startsWith('https://')) {
          photoUrl = rawStr;
        } else {
          final parsedInt = int.tryParse(rawStr);
          if (parsedInt != null) {
            final nameLower = name.toLowerCase();
            String gender = 'men';
            if (nameLower.contains('kaiya') ||
                nameLower.contains('kaya') ||
                nameLower.contains('kiaya') ||
                nameLower.contains('lisa') ||
                nameLower.contains('sara') ||
                nameLower.contains('anna') ||
                nameLower.contains('maria') ||
                nameLower.contains('emma') ||
                nameLower.contains('sofia') ||
                nameLower.contains('julia') ||
                nameLower.contains('lucy') ||
                nameLower.contains('charlotte')) {
              gender = 'women';
            }
            photoUrl = 'https://randomuser.me/api/portraits/$gender/$parsedInt.jpg';
          } else {
            photoUrl = rawStr;
          }
        }
      }
    }

    return GestureDetector(
      onTap: () {
        controller.tappedNotification(n);
        // Build route payload and navigate using NotificationService for consistent deep-linking
        final routePayload = {
          'type': (n['type'] ?? '').toString(),
          'postId': (n['postId'] ?? '').toString(),
          'trainerName': (n['trainerName'] ?? n['senderName'] ?? 'Trainer').toString(),
          'otherId': (n['senderId'] ?? n['otherId'] ?? '').toString(),
          'otherName': (n['senderName'] ?? n['otherName'] ?? '').toString(),
          'otherPhoto': (n['senderPhotoUrl'] ?? n['otherPhoto'] ?? '').toString(),
        };
        NotificationService.instance.navigateFromPayload(routePayload);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? card : raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? stroke : accentColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoUrl.isNotEmpty)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.5),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: accentColor.withOpacity(0.12),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: accentColor.withOpacity(0.12),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.25)),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (n['title'] ?? 'Notification').toString(),
                          style: TextStyle(
                            color: text,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: neon,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (n['body'] ?? '').toString(),
                    style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: muted.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
