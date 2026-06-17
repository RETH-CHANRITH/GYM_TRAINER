import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserSupportService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<bool> createSupportTicket({
    required String subject,
    required String message,
    String category = 'general',
    required void Function(String title, String message) onNotification,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      onNotification('Login required', 'Please login to contact support.');
      return false;
    }

    final trimmedSubject = subject.trim();
    final trimmedMessage = message.trim();
    if (trimmedSubject.isEmpty || trimmedMessage.length < 10) {
      onNotification(
        'Invalid ticket',
        'Please add a subject and at least 10 characters in your message.',
      );
      return false;
    }

    await _firestore.collection('supportTickets').add({
      'userId': user.uid,
      'userEmail': user.email ?? '',
      'userName': user.displayName ?? 'User',
      'subject': trimmedSubject,
      'message': trimmedMessage,
      'category': category,
      'priority': 'medium',
      'status': 'open',
      'assignedAdminId': null,
      'source': 'mobile_app',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<bool> requestAccountDeletion({
    required String reason,
    required void Function(String title, String message) onNotification,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      onNotification('Login required', 'Please login to submit this request.');
      return false;
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      onNotification(
        'Reason required',
        'Please provide at least 10 characters for the deletion reason.',
      );
      return false;
    }

    await _firestore.collection('gdprRequests').add({
      'userId': user.uid,
      'userEmail': user.email ?? '',
      'userName': user.displayName ?? 'User',
      'type': 'delete',
      'status': 'received',
      'reason': trimmedReason,
      'source': 'mobile_app',
      'requestedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }
}

final userSupportServiceProvider = Provider<UserSupportService>((ref) {
  return UserSupportService();
});
