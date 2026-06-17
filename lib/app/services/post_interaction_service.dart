import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostInteractionService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Toggles a like on a post by the current user.
  /// Uses a cache-first read then direct updates to ensure instant local optimistic updates.
  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final postRef = _firestore.collection('trainerPosts').doc(postId);

    DocumentSnapshot snap;
    try {
      snap = await postRef.get(const GetOptions(source: Source.cache));
      if (!snap.exists) {
        snap = await postRef.get(const GetOptions(source: Source.server));
      }
    } catch (_) {
      snap = await postRef.get();
    }

    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>? ?? {};
    final likedByList = List<String>.from(data['likedBy'] ?? <dynamic>[]);
    final trainerId = data['trainerId']?.toString() ?? '';
    final postTitle = data['title']?.toString() ?? 'your post';

    if (likedByList.contains(uid)) {
      // Unlike post
      postRef.update({
        'likedBy': FieldValue.arrayRemove([uid]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Like post
      postRef.update({
        'likedBy': FieldValue.arrayUnion([uid]),
        'likesCount': FieldValue.increment(1),
      });

      // Send notification (non-blocking)
      if (trainerId.isNotEmpty && trainerId != uid) {
        _firestore
            .collection('notifications')
            .doc(trainerId)
            .collection('items')
            .add({
          'title': 'New Like',
          'body': '${user.displayName ?? "Someone"} liked your post "$postTitle"',
          'type': 'like',
          'color': 'coral',
          'icon': 'bell',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': uid,
          'senderName': user.displayName ?? 'Someone',
          'senderPhotoUrl': user.photoURL ?? '',
          // Deep-link fields
          'postId': postId,
          'trainerName': data['name']?.toString() ?? postTitle,
        });
      }
    }
  }

  /// Adds a comment to the post and increments commentsCount.
  /// Uses direct set & update calls to apply changes locally instantly.
  Future<void> addComment(String postId, String commentText, {String? trainerId, String? postTitle}) async {
    final user = _auth.currentUser;
    if (user == null || commentText.trim().isEmpty) return;

    final name = (user.displayName ?? user.email?.split('@').first ?? 'User').trim();
    final photoUrl = (user.photoURL ?? '').trim();

    final commentsRef = _firestore.collection('trainerPosts').doc(postId).collection('comments');
    final postRef = _firestore.collection('trainerPosts').doc(postId);
    final commentDocRef = commentsRef.doc();

    commentDocRef.set({
      'userId': user.uid,
      'userName': name,
      'userPhotoUrl': photoUrl,
      'text': commentText.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': [],
      'likesCount': 0,
    });

    postRef.update({
      'commentsCount': FieldValue.increment(1),
    });

    final targetTrainerId = trainerId ?? '';
    final targetPostTitle = postTitle ?? 'your post';

    if (targetTrainerId.isNotEmpty && targetTrainerId != user.uid) {
      _firestore
          .collection('notifications')
          .doc(targetTrainerId)
          .collection('items')
          .add({
        'title': 'New Comment',
        'body': '$name commented on your post "$targetPostTitle": "$commentText"',
        'type': 'comment',
        'color': 'lilac',
        'icon': 'chat',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': user.uid,
        'senderName': name,
        'senderPhotoUrl': photoUrl,
        // Deep-link fields
        'postId': postId,
        'trainerName': targetPostTitle,
      });
    }
  }

  /// Deletes a comment and all its replies, then decrements commentsCount.
  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final commentRef = _firestore
        .collection('trainerPosts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final postRef = _firestore.collection('trainerPosts').doc(postId);

    // Delete all replies first to avoid orphans
    final repliesSnap = await commentRef.collection('replies').get();
    final repliesCount = repliesSnap.docs.length;

    final batch = _firestore.batch();
    for (final reply in repliesSnap.docs) {
      batch.delete(reply.reference);
    }
    batch.delete(commentRef);
    // Keep commentsCount in sync by decrementing parent comment + replies count
    batch.update(postRef, {
      'commentsCount': FieldValue.increment(-(1 + repliesCount)),
    });
    await batch.commit();
  }

  /// Toggles a like on a comment by the current user.
  Future<void> toggleCommentLike(String postId, String commentId, {bool? isLiked, String? commentAuthorId, String? commentText}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final commentRef = _firestore
        .collection('trainerPosts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    if (isLiked == null || commentAuthorId == null || commentText == null) {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(commentRef);
        if (!snap.exists) return;

        final data = snap.data() ?? <String, dynamic>{};
        final likedByList = List<String>.from(data['likedBy'] ?? <dynamic>[]);
        final authorId = data['userId']?.toString() ?? '';
        final text = data['text']?.toString() ?? '';

        final currentLiked = likedByList.contains(uid);
        if (currentLiked) {
          transaction.update(commentRef, {
            'likedBy': FieldValue.arrayRemove([uid]),
            'likesCount': FieldValue.increment(-1),
          });
        } else {
          transaction.update(commentRef, {
            'likedBy': FieldValue.arrayUnion([uid]),
            'likesCount': FieldValue.increment(1),
          });
          if (authorId.isNotEmpty && authorId != uid) {
            final notifRef = _firestore
                .collection('notifications')
                .doc(authorId)
                .collection('items')
                .doc();
            transaction.set(notifRef, {
              'title': 'Comment Liked',
              'body': '${user.displayName ?? "Someone"} liked your comment "$text"',
              'type': 'like',
              'color': 'coral',
              'icon': 'bell',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
              'senderId': uid,
              'senderName': user.displayName ?? 'Someone',
              'senderPhotoUrl': user.photoURL ?? '',
              'postId': postId,
            });
          }
        }
      });
      return;
    }

    if (isLiked) {
      commentRef.update({
        'likedBy': FieldValue.arrayRemove([uid]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      commentRef.update({
        'likedBy': FieldValue.arrayUnion([uid]),
        'likesCount': FieldValue.increment(1),
      });

      if (commentAuthorId.isNotEmpty && commentAuthorId != uid) {
        _firestore
            .collection('notifications')
            .doc(commentAuthorId)
            .collection('items')
            .add({
          'title': 'Comment Liked',
          'body': '${user.displayName ?? "Someone"} liked your comment "$commentText"',
          'type': 'like',
          'color': 'coral',
          'icon': 'bell',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'senderId': uid,
          'senderName': user.displayName ?? 'Someone',
          'senderPhotoUrl': user.photoURL ?? '',
          'postId': postId,
        });
      }
    }
  }

  /// Adds a reply to a comment and increments repliesCount on the parent comment.
  Future<void> addCommentReply(String postId, String commentId, String replyText, {String? commentAuthorId}) async {
    final user = _auth.currentUser;
    if (user == null || replyText.trim().isEmpty) return;

    final name = (user.displayName ?? user.email?.split('@').first ?? 'User').trim();
    final photoUrl = (user.photoURL ?? '').trim();

    final postRef = _firestore.collection('trainerPosts').doc(postId);
    final commentRef = _firestore
        .collection('trainerPosts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final replyDocRef = commentRef.collection('replies').doc();

    // Write reply + increment repliesCount atomically
    final batch = _firestore.batch();
    batch.set(replyDocRef, {
      'userId': user.uid,
      'userName': name,
      'userPhotoUrl': photoUrl,
      'text': replyText.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(commentRef, {
      'repliesCount': FieldValue.increment(1),
    });
    batch.update(postRef, {
      'commentsCount': FieldValue.increment(1),
    });
    await batch.commit();

    final targetAuthorId = commentAuthorId ?? '';
    if (targetAuthorId.isNotEmpty && targetAuthorId != user.uid) {
      _firestore
          .collection('notifications')
          .doc(targetAuthorId)
          .collection('items')
          .add({
        'title': 'New Reply',
        'body': '$name replied to your comment: "$replyText"',
        'type': 'comment',
        'color': 'lilac',
        'icon': 'chat',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': user.uid,
        'senderName': name,
        'senderPhotoUrl': photoUrl,
        'postId': postId,
      });
    }
  }

  /// Deletes a reply and decrements repliesCount on the parent comment.
  Future<void> deleteCommentReply(String postId, String commentId, String replyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('trainerPosts').doc(postId);
    final commentRef = _firestore
        .collection('trainerPosts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final replyRef = commentRef.collection('replies').doc(replyId);

    // Delete reply + decrement repliesCount atomically
    final batch = _firestore.batch();
    batch.delete(replyRef);
    batch.update(commentRef, {
      'repliesCount': FieldValue.increment(-1),
    });
    batch.update(postRef, {
      'commentsCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }
}

final postInteractionServiceProvider = Provider<PostInteractionService>((ref) {
  return PostInteractionService();
});
