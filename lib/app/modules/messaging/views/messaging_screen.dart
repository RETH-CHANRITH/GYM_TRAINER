import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/glass_ui.dart';
import '../../../services/user_role_service.dart';

// ─── Design Tokens ─────────────────────────────────────────────────────────
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

class MessagingScreen extends ConsumerStatefulWidget {
  const MessagingScreen({super.key});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  Color get ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get surface => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFFFFFFF);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

  int _tabIndex = 0;
  final _tabs = [
    {'label': 'All', 'icon': CupertinoIcons.chat_bubble_2},
    {'label': 'Unread', 'icon': CupertinoIcons.envelope_badge},
    {'label': 'Online', 'icon': CupertinoIcons.circle},
  ];

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _sub;
  String _role = 'user';

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final Map<String, StreamSubscription<DocumentSnapshot>> _userSubs = {};
  final Map<String, bool> _onlineUsers = {};
  final Map<String, String> _userNames = {};
  final Map<String, String> _userPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadRole();
    _listenToConversations();
  }

  void _loadRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final role = await UserRoleService().getCachedRole(user);
        if (mounted) {
          setState(() {
            _role = role;
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final sub in _userSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _updateUserSubscriptions(List<String> otherIds) {
    final idsToRemove = _userSubs.keys.where((id) => !otherIds.contains(id)).toList();
    for (final id in idsToRemove) {
      _userSubs[id]?.cancel();
      _userSubs.remove(id);
      _onlineUsers.remove(id);
      _userNames.remove(id);
      _userPhotos.remove(id);
    }

    for (final otherId in otherIds) {
      if (otherId.isEmpty || _userSubs.containsKey(otherId)) continue;

      _userSubs[otherId] = _firestore
          .collection('users')
          .doc(otherId)
          .snapshots()
          .listen((doc) {
        if (!mounted) return;
        if (doc.exists) {
          final data = doc.data() ?? {};
          final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString();
          final photo = (data['photoUrl'] ?? data['imageUrl'] ?? '').toString();
          final online = (data['isOnline'] ?? data['isActive'] ?? false) as bool;

          setState(() {
            if (name.isNotEmpty) _userNames[otherId] = name;
            if (photo.isNotEmpty) _userPhotos[otherId] = photo;
            _onlineUsers[otherId] = online;
          });
        }
      }, onError: (_) {});
    }
  }

  Future<void> _toggleUnread(Map<String, dynamic> conv) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final convId = conv['convId'] as String? ?? '';
    if (convId.isEmpty) return;

    final int currentUnread = conv['unread'] as int;
    final newUnread = currentUnread > 0 ? 0 : 1;

    try {
      await _firestore.collection('conversations').doc(convId).update({
        'unreadCounts.${user.uid}': newUnread,
      });
    } catch (e, s) {
      debugPrint('Error toggling unread status: $e\n$s');
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context, String name, String convId) async {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Are you sure you want to delete your conversation with $name? This will erase all messages.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteConversation(String convId) async {
    if (convId.isEmpty) return;
    try {
      await _firestore.collection('conversations').doc(convId).delete();
      final messagesSnap = await _firestore.collection('conversations').doc(convId).collection('messages').get();
      final batch = _firestore.batch();
      for (final doc in messagesSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e, s) {
      debugPrint('Error deleting conversation: $e\n$s');
    }
  }

  void _listenToConversations() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _sub = _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: user.uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final convs = snap.docs.map((d) {
        final data = d.data();
        final uid = user.uid;

        // Find the other participant's info
        final participants = List<String>.from(data['participantIds'] ?? []);
        final otherId = participants.firstWhere(
          (id) => id != uid,
          orElse: () => '',
        );

        final names =
            Map<String, dynamic>.from(data['participantNames'] ?? {});
        final photos =
            Map<String, dynamic>.from(data['participantPhotos'] ?? {});
        final unreadCounts =
            Map<String, dynamic>.from(data['unreadCounts'] ?? {});

        final unread = (unreadCounts[uid] as num?)?.toInt() ?? 0;
        final lastMsg = (data['lastMessage'] ?? '').toString();
        final lastAt = data['lastMessageAt'];
        String timeStr = '';
        if (lastAt is Timestamp) {
          final dt = lastAt.toDate();
          final now = DateTime.now();
          final diff = now.difference(dt);
          if (diff.inMinutes < 60) {
            timeStr = '${diff.inMinutes}m';
          } else if (diff.inHours < 24) {
            timeStr = '${diff.inHours}h';
          } else {
            timeStr = '${diff.inDays}d';
          }
        }

        return {
          'convId': d.id,
          'otherId': otherId,
          'name': names[otherId] ?? (_role == 'trainer' ? 'Client' : 'Trainer'),
          'photoUrl': photos[otherId] ?? '',
          'message': lastMsg,
          'time': timeStr,
          'unread': unread,
          'online': data['isOtherOnline'] ?? false,
          'specialty': data['specialty'] ?? '',
        };
      }).toList();

      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
      final otherIds = convs.map((c) => c['otherId'] as String).where((id) => id.isNotEmpty).toList();
      _updateUserSubscriptions(otherIds);
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_tabIndex == 1) {
      return _conversations.where((c) => (c['unread'] as int) > 0).toList();
    }
    if (_tabIndex == 2) {
      return _conversations.where((c) {
        final otherId = c['otherId'] as String? ?? '';
        return _onlineUsers[otherId] ?? c['online'] == true;
      }).toList();
    }
    return _conversations;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _conversations.where((c) => (c['unread'] as int) > 0).length;
    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (_role != 'trainer') ...[
                  _buildHeader(unreadCount),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 16),
                _buildTabs(),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: neon),
                        )
                      : _filtered.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 100),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) =>
                                  _buildConversationCard(
                                _filtered[index],
                                index,
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [sky.withOpacity(0.2), sky.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sky.withOpacity(0.3)),
            ),
            child: const Icon(
              CupertinoIcons.chat_bubble_fill,
              color: sky,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: TextStyle(
                    color: text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_conversations.length} conversations',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: coral.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: coral.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$unreadCount new',
                    style: const TextStyle(
                      color: coral,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke.withOpacity(0.5)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(
                          colors: [neon.withOpacity(0.18), neon.withOpacity(0.02)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: active
                      ? Border.all(color: neon.withOpacity(0.35))
                      : Border.all(color: Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      i == 2 && active
                          ? CupertinoIcons.circle_fill
                          : _tabs[i]['icon'] as IconData,
                      color: i == 2 && active ? const Color(0xFF22C55E) : (active ? neon : muted),
                      size: i == 2 && active ? 11 : 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tabs[i]['label'] as String,
                      style: TextStyle(
                        color: active ? text : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: card,
              shape: BoxShape.circle,
              border: Border.all(color: stroke),
            ),
            child: Icon(CupertinoIcons.chat_bubble, color: muted, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'No messages',
            style: TextStyle(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _role == 'trainer'
                ? 'Your client conversations will appear here'
                : 'Start a conversation with a trainer',
            style: TextStyle(color: muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conv, int index) {
    final int unread = conv['unread'] as int;
    final String otherId = conv['otherId'] as String? ?? '';
    final bool isOnline = _onlineUsers[otherId] ?? conv['online'] as bool;
    final bool hasUnread = unread > 0;
    final String photoUrl = (_userPhotos[otherId] != null && _userPhotos[otherId]!.isNotEmpty)
        ? _userPhotos[otherId]!
        : (conv['photoUrl'] as String? ?? '');
    final String specialty = conv['specialty'] as String? ?? '';
    final String name = _userNames[otherId] ?? conv['name'] as String? ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Dismissible(
        key: ValueKey(conv['convId'] ?? index.toString()),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _toggleUnread(conv);
            return false;
          } else {
            return await _showDeleteConfirmation(context, name, conv['convId'] as String? ?? '');
          }
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            _deleteConversation(conv['convId'] as String? ?? '');
          }
        },
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: neon.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: neon.withOpacity(0.3)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: Icon(
            hasUnread ? CupertinoIcons.envelope_open_fill : CupertinoIcons.envelope_fill,
            color: neon,
            size: 22,
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: coral.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: coral.withOpacity(0.3)),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(
            CupertinoIcons.trash_fill,
            color: coral,
            size: 22,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasUnread
                  ? [neon.withOpacity(0.06), card.withOpacity(0.9)]
                  : [card, card.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasUnread ? neon.withOpacity(0.35) : stroke.withOpacity(0.6),
              width: hasUnread ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(hasUnread ? 0.25 : 0.15),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _clearUnread(conv);
                  final updatedConv = Map<String, dynamic>.from(conv);
                  if (otherId.isNotEmpty) {
                    updatedConv['name'] = name;
                    updatedConv['photoUrl'] = photoUrl;
                    updatedConv['online'] = isOnline;
                  }
                  context.push('/message-screen', extra: updatedConv);
                },
              child: Stack(
                children: [
                  if (hasUnread)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: neon,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                            bottomLeft: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Avatar with online indicator
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isOnline ? const Color(0xFF22C55E) : stroke.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: photoUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: photoUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => InitialsAvatar(
                                            name: name,
                                            size: 50,
                                            fontSize: 16,
                                            borderRadius: 100,
                                          ),
                                          errorWidget: (context, url, error) => InitialsAvatar(
                                            name: name,
                                            size: 50,
                                            fontSize: 16,
                                            borderRadius: 100,
                                          ),
                                        )
                                      : InitialsAvatar(
                                          name: name,
                                          size: 50,
                                          fontSize: 16,
                                          borderRadius: 100,
                                        ),
                                ),
                              ),
                            ),
                            if (isOnline)
                              Positioned(
                                bottom: 1,
                                right: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: ink,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF22C55E),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 15,
                                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    conv['time'] as String,
                                    style: TextStyle(
                                      color: hasUnread ? neon : muted,
                                      fontSize: 11,
                                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (specialty.isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 2, bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sky.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: sky.withOpacity(0.18)),
                                  ),
                                  child: Text(
                                    specialty.toUpperCase(),
                                    style: const TextStyle(
                                      color: sky,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conv['message'] as String,
                                      style: TextStyle(
                                        color: hasUnread ? text : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                                        fontSize: 13,
                                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasUnread) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: neon,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: neon.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '$unread',
                                        style: TextStyle(
                                          color: ink,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _avatarFallback() => Container(
        color: raised,
        child: Icon(
          CupertinoIcons.person_fill,
          color: muted,
          size: 24,
        ),
      );

  Future<void> _clearUnread(Map<String, dynamic> conv) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final convId = conv['convId'] as String? ?? '';
    if (convId.isEmpty) return;
    try {
      await _firestore.collection('conversations').doc(convId).update({
        'unreadCounts.${user.uid}': 0,
      });
    } catch (e, s) {
      debugPrint('Error clearing unread: $e\n$s');
    }
  }
}
