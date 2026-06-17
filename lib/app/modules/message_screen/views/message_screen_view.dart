import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/glass_ui.dart';

const Color ink = Color(0xFF0A0A0F);
const Color card = Color(0xFF17171F);
const Color raised = Color(0xFF1E1E28);
const Color stroke = Color(0xFF2A2A36);
const Color neon = Color(0xFFCBFF47);
const Color coral = Color(0xFFFF5C5C);
const Color sky = Color(0xFF5CE8FF);
const Color lilac = Color(0xFFA78BFA);
const Color muted = Color(0xFF6B6B7E);

class MessagingScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;
  const MessagingScreen({super.key, this.arguments});
  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  Color get ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0F) : const Color(0xFFF9F9FC);
  Color get surface => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111118) : const Color(0xFFFFFFFF);
  Color get card => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17171F) : const Color(0xFFFFFFFF);
  Color get raised => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : const Color(0xFFF0EFF5);
  Color get stroke => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A36) : const Color(0xFFE5E7EB);
  Color get neon => Theme.of(context).colorScheme.primary;
  Color get muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6B6B7E) : Colors.black45;
  Color get text => Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _showExtras = false;
  bool _isSending = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Conversation data
  late final Map<String, dynamic> _conv;
  String _convId = '';
  String _otherName = 'Trainer';
  String _otherPhotoUrl = '';
  bool _otherOnline = false;

  // Messages
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot>? _msgSub;
  StreamSubscription<DocumentSnapshot>? _otherUserSub;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _otherUserSub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _listenToOtherUser(String otherId) {
    if (otherId.isEmpty) return;
    _otherUserSub?.cancel();
    _otherUserSub = _firestore
        .collection('users')
        .doc(otherId)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;
      final data = doc.data() ?? {};
      setState(() {
        final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString().trim();
        final photo = (data['photoUrl'] ?? data['imageUrl'] ?? '').toString().trim();

        if (name.isNotEmpty) _otherName = name;
        if (photo.isNotEmpty) _otherPhotoUrl = photo;
        _otherOnline = (data['isOnline'] ?? data['isActive'] ?? _otherOnline) as bool;
      });
    }, onError: (_) {});
  }

  Future<void> _clearUnread() async {
    final user = _auth.currentUser;
    if (user == null || _convId.isEmpty) return;
    try {
      await _firestore.collection('conversations').doc(_convId).update({
        'unreadCounts.${user.uid}': 0,
      });
    } catch (e, s) {
      debugPrint('Error clearing unread in message screen: $e\n$s');
    }
  }

  void _initConversation() {
    final args = widget.arguments ?? {};
    _otherName = (args['name'] ?? 'Trainer').toString();
    _otherPhotoUrl = (args['photoUrl'] ?? '').toString();
    _otherOnline = args['online'] == true || args['isOnline'] == true;

    final user = _auth.currentUser;
    if (user == null) return;

    _conv = args;

    // Support otherId or trainerId
    final otherId = (args['otherId'] ?? args['trainerId'] ?? '').toString();

    if (otherId.isNotEmpty) {
      _conv['otherId'] = otherId;
      final ids = [user.uid, otherId]..sort();
      _convId = ids.join('_');
      _listenToOtherUser(otherId);
      _ensureConversationDoc(user, otherId).then((_) => _clearUnread());
      _listenToMessages();
    } else {
      // Lookup fallback by trainer name
      _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .get()
          .then((snap) {
        String? foundUid;
        for (final doc in snap.docs) {
          final data = doc.data();
          final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString().trim().toLowerCase();
          if (name == _otherName.trim().toLowerCase()) {
            foundUid = doc.id;
            break;
          }
        }

        if (foundUid != null && mounted) {
          setState(() {
            _conv['otherId'] = foundUid;
          });
          final ids = [user.uid, foundUid]..sort();
          _convId = ids.join('_');
          _listenToOtherUser(foundUid);
          _ensureConversationDoc(user, foundUid).then((_) => _clearUnread());
          _listenToMessages();
        } else {
          _convId = (args['convId'] ?? 'unknown_${user.uid}').toString();
          _listenToMessages();
        }
      }).catchError((_) {
        _convId = (args['convId'] ?? 'unknown_${user.uid}').toString();
        _listenToMessages();
      });
    }
  }

  /// Create the conversation document if it doesn't exist yet
  Future<void> _ensureConversationDoc(User user, String otherId) async {
    if (otherId.isEmpty) return;
    final ref = _firestore.collection('conversations').doc(_convId);
    final snap = await ref.get();
    if (!snap.exists) {
      // Fetch other user's name/photo from Firestore if not passed
      String otherName = _otherName;
      String otherPhoto = _otherPhotoUrl;
      try {
        final otherDoc =
            await _firestore.collection('users').doc(otherId).get();
        if (otherDoc.exists) {
          final d = otherDoc.data()!;
          otherName = (d['name'] ?? d['displayName'] ?? otherName).toString();
          otherPhoto = (d['photoUrl'] ?? '').toString();
        }
      } catch (_) {}

      String myName =
          user.displayName ?? user.email?.split('@').first ?? 'User';
      String myPhoto = user.photoURL ?? '';
      try {
        final myDoc = await _firestore.collection('users').doc(user.uid).get();
        if (myDoc.exists) {
          final d = myDoc.data()!;
          myName = (d['name'] ?? d['fullName'] ?? d['displayName'] ?? myName).toString();
          myPhoto = (d['photoUrl'] ?? d['avatarUrl'] ?? d['profileImage'] ?? myPhoto).toString();
        }
      } catch (_) {}

      await ref.set({
        'participantIds': [user.uid, otherId],
        'participantNames': {
          user.uid: myName,
          otherId: otherName,
        },
        'participantPhotos': {
          user.uid: myPhoto,
          otherId: otherPhoto,
        },
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'unreadCounts': {user.uid: 0, otherId: 0},
        'specialty': _conv['specialty'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _listenToMessages() {
    _msgSub = _firestore
        .collection('conversations')
        .doc(_convId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final user = _auth.currentUser;
      final uid = user?.uid ?? '';
      final msgs = snap.docs.map((d) {
        final data = d.data();
        final senderId = (data['senderId'] ?? '').toString();
        final sentAt = data['sentAt'];
        String timeStr = '';
        if (sentAt is Timestamp) {
          final dt = sentAt.toDate();
          final h = dt.hour.toString().padLeft(2, '0');
          final m = dt.minute.toString().padLeft(2, '0');
          timeStr = '$h:$m';
        }
        return {
          'id': d.id,
          'text': (data['text'] ?? '').toString(),
          'isMe': senderId == uid,
          'time': timeStr,
          'status': data['read'] == true ? 'read' : 'sent',
          'timestamp': sentAt,
          'edited': data['edited'] == true,
        };
      }).toList();

      setState(() => _messages = msgs);
    }, onError: (_) {});
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
      _showExtras = false;
    });
    _controller.clear();

    try {
      final batch = _firestore.batch();

      // Add message to sub-collection
      final msgRef = _firestore
          .collection('conversations')
          .doc(_convId)
          .collection('messages')
          .doc();

      batch.set(msgRef, {
        'text': text,
        'senderId': user.uid,
        'senderName': user.displayName ?? user.email ?? 'User',
        'sentAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update conversation metadata
      final otherId = (_conv['otherId'] ?? '').toString();
      final convRef = _firestore.collection('conversations').doc(_convId);
      final updateData = {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
      };
      if (otherId.isNotEmpty) {
        updateData['unreadCounts.$otherId'] =
            FieldValue.increment(1) as dynamic;
      }
      batch.update(convRef, updateData);

      await batch.commit();

      // Send a notification to the recipient so they get an in-app banner + device notification
      if (otherId.isNotEmpty && otherId != user.uid) {
        final myName = (user.displayName ?? user.email?.split('@').first ?? 'Someone').trim();
        final myPhoto = user.photoURL ?? '';
        _firestore
            .collection('notifications')
            .doc(otherId)
            .collection('items')
            .add({
          'title': myName,
          'body': text,
          'type': 'chat',
          'color': 'sky',
          'icon': 'chat',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': user.uid,
          'senderName': myName,
          'senderPhotoUrl': myPhoto,
          // Deep-link: tap to open this chat
          'otherId': user.uid,
          'otherName': myName,
          'otherPhoto': myPhoto,
        });
      }
    } catch (e, s) {
      debugPrint('Error sending message: $e\n$s');
      // Re-populate text field on error
      if (mounted) _controller.text = text;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<bool> _confirmDeleteMessage(BuildContext context) async {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
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

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final msgId = msg['id'] as String? ?? '';
    if (msgId.isEmpty || _convId.isEmpty) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(_convId)
          .collection('messages')
          .doc(msgId)
          .delete();

      final index = _messages.indexWhere((m) => m['id'] == msgId);
      if (index == 0) {
        String nextMsgText = '';
        Timestamp? nextMsgAt;
        if (_messages.length > 1) {
          final nextMsg = _messages[1];
          nextMsgText = nextMsg['text'] as String? ?? '';
          nextMsgAt = nextMsg['timestamp'] as Timestamp?;
        }

        await _firestore.collection('conversations').doc(_convId).update({
          'lastMessage': nextMsgText,
          'lastMessageAt': nextMsgAt ?? FieldValue.serverTimestamp(),
        });
      }
    } catch (e, s) {
      debugPrint('Error deleting message: $e\n$s');
    }
  }

  void _showEditSheet(BuildContext context, Map<String, dynamic> msg) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Message Options'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Edit Message'),
            onPressed: () {
              Navigator.pop(context);
              _showEditDialog(context, msg);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteMessage(context).then((confirmed) {
                if (confirmed) {
                  _deleteMessage(msg);
                }
              });
            },
            child: const Text('Delete Message'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> msg) {
    final editController = TextEditingController(text: msg['text'] as String? ?? '');
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Message'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: editController,
            style: TextStyle(color: text, fontSize: 14),
            placeholder: 'Type message...',
            placeholderStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Colors.black38),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: stroke),
            ),
            maxLines: null,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty) {
                _editMessage(msg, newText);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(Map<String, dynamic> msg, String newText) async {
    final msgId = msg['id'] as String? ?? '';
    if (msgId.isEmpty || _convId.isEmpty) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(_convId)
          .collection('messages')
          .doc(msgId)
          .update({
        'text': newText,
        'edited': true,
      });

      final index = _messages.indexWhere((m) => m['id'] == msgId);
      if (index == 0) {
        await _firestore.collection('conversations').doc(_convId).update({
          'lastMessage': newText,
        });
      }
    } catch (e, s) {
      debugPrint('Error editing message: $e\n$s');
    }
  }

  String _formatDateSeparator(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        children: [
          Positioned.fill(child: trainerBackground(context)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context),
                _buildSessionBanner(),
                Expanded(child: _buildList()),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: raised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.back,
                color: text,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: stroke.withOpacity(0.5), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _otherPhotoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _otherPhotoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => InitialsAvatar(
                            name: _otherName,
                            size: 44,
                            fontSize: 15,
                            borderRadius: 12,
                          ),
                          errorWidget: (context, url, error) => InitialsAvatar(
                            name: _otherName,
                            size: 44,
                            fontSize: 15,
                            borderRadius: 12,
                          ),
                        )
                      : InitialsAvatar(
                          name: _otherName,
                          size: 44,
                          fontSize: 15,
                          borderRadius: 12,
                        ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: ink,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _otherOnline ? const Color(0xFF22C55E) : muted,
                      shape: BoxShape.circle,
                      boxShadow: _otherOnline
                          ? [
                              const BoxShadow(
                                color: Color(0xFF22C55E),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _otherName,
                  style: TextStyle(
                    color: text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _otherOnline
                        ? const _PulsingDot()
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                    const SizedBox(width: 7),
                    Text(
                      _otherOnline ? 'Active now' : 'Offline',
                      style: TextStyle(
                        color: _otherOnline ? const Color(0xFF22C55E) : muted,
                        fontSize: 11.5,
                        fontWeight: _otherOnline ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _hBtn(CupertinoIcons.phone),
          const SizedBox(width: 8),
          _hBtn(CupertinoIcons.video_camera),
        ],
      ),
    );
  }

  Widget _hBtn(IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: text, size: 19),
      );

  Widget _buildSessionBanner() {
    final specialty =
        (_conv['specialty'] ?? _conv['sessionType'] ?? '').toString();
    if (specialty.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: neon.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neon.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: neon.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(CupertinoIcons.sportscourt, color: neon, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              specialty,
              style: TextStyle(
                color: text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.chat_bubble, color: muted, size: 40),
            const SizedBox(height: 12),
            Text(
              'Send a message to start\nthe conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final isMe = msg['isMe'] as bool;
        final showAvatar =
            !isMe && (i == _messages.length - 1 || (_messages[i + 1]['isMe'] as bool));
        final isLast = i == 0 || (_messages[i - 1]['isMe'] as bool) != isMe;

        // Check if we need to show a date separator above this message (visually above means next item in list index)
        bool showDateSeparator = false;
        String dateStr = '';
        if (i == _messages.length - 1) {
          showDateSeparator = true;
          dateStr = _formatDateSeparator(msg['timestamp'] as Timestamp?);
        } else {
          final prevMsg = _messages[i + 1];
          final ts1 = msg['timestamp'] as Timestamp?;
          final ts2 = prevMsg['timestamp'] as Timestamp?;
          if (ts1 != null && ts2 != null) {
            final d1 = ts1.toDate();
            final d2 = ts2.toDate();
            if (d1.year != d2.year || d1.month != d2.month || d1.day != d2.day) {
              showDateSeparator = true;
              dateStr = _formatDateSeparator(ts1);
            }
          }
        }

        final bubbleContent = Padding(
          padding: EdgeInsets.only(bottom: isLast ? 14 : 3),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: showAvatar
                      ? Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: stroke.withOpacity(0.5)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: _otherPhotoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _otherPhotoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => InitialsAvatar(
                                      name: _otherName,
                                      size: 30,
                                      fontSize: 11,
                                      borderRadius: 9,
                                    ),
                                    errorWidget: (context, url, error) => InitialsAvatar(
                                      name: _otherName,
                                      size: 30,
                                      fontSize: 11,
                                      borderRadius: 9,
                                    ),
                                  )
                                : InitialsAvatar(
                                    name: _otherName,
                                    size: 30,
                                    fontSize: 11,
                                    borderRadius: 9,
                                  ),
                          ),
                        )
                      : const SizedBox(width: 38),
                ),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        debugPrint('DEBUG: Long-pressed message. isMe: $isMe');
                        if (isMe) {
                          _showEditSheet(context, msg);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.68,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? LinearGradient(
                                  colors: [neon, Color.lerp(neon, Colors.black, 0.18) ?? neon],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isMe ? null : card.withOpacity(0.7),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : (isLast ? 4 : 18)),
                            bottomRight: Radius.circular(isMe ? (isLast ? 4 : 18) : 18),
                          ),
                          border: isMe ? null : Border.all(color: stroke.withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          msg['text'] as String,
                          style: TextStyle(
                            color: isMe ? ink : text,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (isLast) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            msg['time'] as String,
                            style: TextStyle(color: muted, fontSize: 10),
                          ),
                          if (msg['edited'] == true) ...[
                            const SizedBox(width: 4),
                            Text(
                              '• Edited',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (isMe && msg['status'] != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              msg['status'] == 'read'
                                  ? CupertinoIcons.checkmark_alt
                                  : CupertinoIcons.checkmark,
                              color: msg['status'] == 'read' ? neon : muted,
                              size: 12,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDateSeparator && dateStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: raised.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: stroke.withOpacity(0.3)),
                    ),
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            Dismissible(
              key: ValueKey(msg['id'] ?? i.toString()),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await _confirmDeleteMessage(context);
              },
              onDismissed: (direction) {
                _deleteMessage(msg);
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.transparent,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: coral.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.trash, color: coral, size: 16),
                ),
              ),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(msg['id'] ?? i),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    alignment: isMe ? Alignment.bottomRight : Alignment.bottomLeft,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: bubbleContent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _showExtras
                ? Container(
                    height: 40,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: const [
                        _QuickReply(CupertinoIcons.hand_thumbsup_fill, 'Sounds good!'),
                        _QuickReply(CupertinoIcons.clock, 'What time?'),
                        _QuickReply(CupertinoIcons.bolt_fill, 'Ready!'),
                        _QuickReply(CupertinoIcons.flame_fill, 'Let\'s go!'),
                      ]
                          .map(
                            (q) => GestureDetector(
                              onTap: () {
                                _controller.text = q.text;
                                setState(() => _showExtras = false);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: card.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: stroke.withOpacity(0.4)),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        q.icon,
                                        size: 13,
                                        color: neon,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        q.text,
                                        style: TextStyle(
                                          color: text.withValues(alpha: 0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: ink.withOpacity(0.95),
              border: Border(top: BorderSide(color: stroke.withOpacity(0.5))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showExtras = !_showExtras),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _showExtras ? neon.withOpacity(0.15) : raised.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _showExtras ? neon.withOpacity(0.4) : stroke.withOpacity(0.5),
                      ),
                    ),
                    child: Icon(
                      _showExtras ? CupertinoIcons.xmark : CupertinoIcons.add,
                      color: _showExtras ? neon : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      maxHeight: 110,
                    ),
                    decoration: BoxDecoration(
                      color: card.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: stroke.withOpacity(0.5)),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message $_otherName...',
                        hintStyle: TextStyle(color: muted, fontSize: 13.5),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isSending ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSending ? raised : neon,
                      shape: BoxShape.circle,
                      boxShadow: _isSending
                          ? null
                          : [
                              BoxShadow(
                                color: neon.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: _isSending
                        ? Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(ink),
                              ),
                            ),
                          )
                        : Icon(
                            CupertinoIcons.paperplane_fill,
                            color: ink,
                            size: 17,
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
}

class _QuickReply {
  final IconData icon;
  final String text;
  const _QuickReply(this.icon, this.text);
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({super.key});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF22C55E),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(0.35 + (0.4 * _controller.value)),
                blurRadius: 3 + (5 * _controller.value),
                spreadRadius: 1 + (1.5 * _controller.value),
              ),
            ],
          ),
        );
      },
    );
  }
}
