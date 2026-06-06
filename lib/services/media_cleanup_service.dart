import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firebase_constants.dart';
import '../models/message_model.dart';
import 'supabase_storage_service.dart';

class MediaCleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseStorageService _storageService = SupabaseStorageService();
  Timer? _timer;

  void startPeriodicCleanup() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      cleanupExpiredImages();
    });
    cleanupExpiredImages();
  }

  void stopCleanup() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> cleanupExpiredImages() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final now = DateTime.now();

    final roomsSnapshot = await _firestore
        .collection(FirebaseConstants.chatRoomsCollection)
        .where(FirebaseConstants.participants, arrayContains: currentUid)
        .get();

    for (final roomDoc in roomsSnapshot.docs) {
      final roomId = roomDoc.id;

      try {
        final expiredMessages = await _firestore
            .collection(FirebaseConstants.chatRoomsCollection)
            .doc(roomId)
            .collection(FirebaseConstants.messagesCollection)
            .where(FirebaseConstants.messageType, isEqualTo: 'image')
            .where(FirebaseConstants.imageMode, isEqualTo: 'temporary')
            .where(FirebaseConstants.expiresAt, isLessThanOrEqualTo: now)
            .get();

        for (final msgDoc in expiredMessages.docs) {
          final message =
              MessageModel.fromMap(msgDoc.data(), msgDoc.id);
          final mediaUrl = message.mediaUrl;

          if (mediaUrl != null) {
            final path = _extractPathFromUrl(mediaUrl);
            if (path != null) {
              await _storageService.deleteImage('chat-images', path);
            }
          }

          await _firestore
              .collection(FirebaseConstants.chatRoomsCollection)
              .doc(roomId)
              .collection(FirebaseConstants.messagesCollection)
              .doc(msgDoc.id)
              .update({
            FirebaseConstants.isDeleted: true,
            FirebaseConstants.deletedAt: FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    }
  }

  Future<void> handleViewOnceImageOpened({
    required String chatRoomId,
    required String messageId,
    required String mediaUrl,
  }) async {
    final path = _extractPathFromUrl(mediaUrl);
    if (path != null) {
      await _storageService.deleteImage('chat-images', path);
    }

    final msgRef = _firestore
        .collection(FirebaseConstants.chatRoomsCollection)
        .doc(chatRoomId)
        .collection(FirebaseConstants.messagesCollection)
        .doc(messageId);

    await msgRef.update({
      FirebaseConstants.viewed: true,
      FirebaseConstants.mediaUrl: FieldValue.delete(),
      FirebaseConstants.text: 'Photo Opened',
    });
  }

  String? _extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.length > 2) {
        final bucketIndex = segments.indexOf('chat-images');
        if (bucketIndex >= 0 && bucketIndex + 1 < segments.length) {
          return segments.sublist(bucketIndex + 1).join('/');
        }
        if (segments.length >= 2) {
          return segments.sublist(segments.length - 2).join('/');
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
