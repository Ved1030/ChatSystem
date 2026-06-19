import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/album_model.dart';
import '../models/chat_model.dart';
import '../models/media_model.dart';
import '../models/message_model.dart';
import '../models/plan_model.dart';
import '../core/constants/supabase_constants.dart';
import '../services/firestore_service.dart';
import '../services/notification_api_service.dart';
import '../services/supabase_storage_service.dart';

class ChatRepository {
  final FirestoreService _firestoreService = FirestoreService();

  String getChatRoomId(String uid1, String uid2) =>
      _firestoreService.getChatRoomId(uid1, uid2);

  Future<ChatRoomModel> getOrCreateChatRoom(
    String currentUid,
    String otherUid,
  ) => _firestoreService.getOrCreateChatRoom(currentUid, otherUid);

  Stream<List<ChatRoomModel>> chatRoomsStream(String currentUid) =>
      _firestoreService.chatRoomsStream(currentUid);

  Stream<List<MessageModel>> messagesStream(
    String chatRoomId,
    String currentUid, {
    DateTime? clearedAt,
  }) => _firestoreService.messagesStream(
    chatRoomId,
    currentUid,
    clearedAt: clearedAt,
  );

  Future<String> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String text,
    String messageType = 'text',
    String? imageMode,
    String? mediaUrl,
    DateTime? expiresAt,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final messageId = await _firestoreService.sendMessage(
      chatRoomId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      messageType: messageType,
      imageMode: imageMode,
      mediaUrl: mediaUrl,
      expiresAt: expiresAt,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSender: replyToSender,
    );

    _triggerNotification(
      chatRoomId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      messageType: messageType,
      messageId: messageId,
    );

    return messageId;
  }

  Future<void> _triggerNotification({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String text,
    required String messageType,
    required String messageId,
  }) async {
    try {
      final sender = FirebaseAuth.instance.currentUser;
      if (sender == null) return;
      if (senderId == receiverId) return;

      final statusSnap = await FirebaseDatabase.instance
          .ref('status/$receiverId/isOnline')
          .get();
      final isOnline = statusSnap.value as bool? ?? false;
      if (isOnline) return;

      final [userSnap, roomSnap] = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(receiverId).get(),
        FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).get(),
      ]);

      if (!userSnap.exists) return;
      final userData = userSnap.data()!;

      final notificationsEnabled = userData['notificationsEnabled'] as bool? ?? true;
      if (!notificationsEnabled) return;

      final soundEnabled = userData['soundEnabled'] as bool? ?? true;
      final vibrationEnabled = userData['vibrationEnabled'] as bool? ?? true;

      bool isMuted = false;
      if (roomSnap.exists) {
        final roomData = roomSnap.data()!;
        final mutedBy = List<String>.from(roomData['mutedBy'] as List? ?? []);
        if (mutedBy.contains(receiverId)) {
          isMuted = true;
        }
        if (!isMuted) {
          final mutedUntil = roomData['mutedUntil'] as Map<String, dynamic>? ?? {};
          final until = mutedUntil[receiverId];
          if (until != null) {
            final untilDate = (until as Timestamp).toDate();
            if (untilDate.isAfter(DateTime.now())) {
              isMuted = true;
            }
          }
        }
      }

      final senderName = sender.displayName ?? 'User';

      await NotificationApiService.sendNotification(
        senderId: senderId,
        receiverId: receiverId,
        roomId: chatRoomId,
        message: text,
        messageType: messageType,
        messageId: messageId,
        senderName: senderName,
        notificationsEnabled: notificationsEnabled,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
        isMuted: isMuted,
      );
    } catch (_) {}
  }

  Future<void> deleteMessageForEveryone(String chatRoomId, String messageId) =>
      _firestoreService.deleteMessageForEveryone(chatRoomId, messageId);

  Future<void> deleteChatImageForEveryone(
    String chatRoomId,
    String messageId,
    String mediaUrl,
  ) async {
    final storage = SupabaseStorageService();
    final path = storage.extractStoragePath(mediaUrl, SupabaseConstants.chatImagesBucket);
    if (path != null) {
      await storage.deleteFile(SupabaseConstants.chatImagesBucket, path);
    }
    await _firestoreService.deleteMessageForEveryone(chatRoomId, messageId);
  }

  Future<void> deleteMessageForMe(
    String chatRoomId,
    String messageId,
    String currentUid,
  ) => _firestoreService.deleteMessageForMe(chatRoomId, messageId, currentUid);

  Future<void> deleteChatForMe(String chatRoomId, String currentUid) =>
      _firestoreService.deleteChatForMe(chatRoomId, currentUid);

  Future<void> clearChat(String chatRoomId, String currentUid) =>
      _firestoreService.clearChat(chatRoomId, currentUid);

  Future<bool> isBlocked(String uid1, String uid2) =>
      _firestoreService.isBlocked(uid1, uid2);

  Stream<List<AlbumModel>> albumsStream(String currentUid) =>
      _firestoreService.albumsStream(currentUid);

  Future<void> deliverIncomingMessages(
    String currentUid,
    List<String> chatRoomIds,
  ) => _firestoreService.deliverIncomingMessages(currentUid, chatRoomIds);

  Future<String> addAlbum(AlbumModel album) =>
      _firestoreService.addAlbum(album);

  Future<void> updateAlbum(String albumId, Map<String, dynamic> data) =>
      _firestoreService.updateAlbum(albumId, data);

  Future<void> deleteAlbum(String albumId) =>
      _firestoreService.deleteAlbum(albumId);

  Stream<List<AlbumPhotoModel>> albumPhotosStream(String albumId) =>
      _firestoreService.albumPhotosStream(albumId);

  Future<String> addAlbumPhoto(String albumId, AlbumPhotoModel photo) =>
      _firestoreService.addAlbumPhoto(albumId, photo);

  Future<void> deleteAlbumPhoto(String albumId, String photoId) =>
      _firestoreService.deleteAlbumPhoto(albumId, photoId);

  Future<void> deleteAllAlbumPhotos(String albumId) =>
      _firestoreService.deleteAllAlbumPhotos(albumId);

  Future<void> deleteAlbumWithImages(String albumId) async {
    final storage = SupabaseStorageService();
    await storage.deleteAlbumFolder(albumId);
    await _firestoreService.deleteAllAlbumPhotos(albumId);
    await _firestoreService.deleteAlbum(albumId);
  }

  Future<void> deleteAlbumPhotoWithImage(String albumId, String photoId, String imageUrl) async {
    final storage = SupabaseStorageService();
    final path = storage.extractAlbumImagePath(imageUrl);
    if (path != null) {
      await storage.deleteFile('albums', path);
    }
    await _firestoreService.deleteAlbumPhoto(albumId, photoId);
  }

  Stream<List<PlanModel>> plansStream(String currentUid) =>
      _firestoreService.plansStream(currentUid);

  Future<void> addPlan(PlanModel plan) => _firestoreService.addPlan(plan);

  Future<void> updatePlan(String planId, Map<String, dynamic> data) =>
      _firestoreService.updatePlan(planId, data);

  Future<void> deletePlan(String planId) =>
      _firestoreService.deletePlan(planId);

  Future<void> updateMessageStatus(
    String chatRoomId,
    String messageId,
    String status, {
    bool setDeliveredAt = false,
  }) => _firestoreService.updateMessageStatus(
    chatRoomId,
    messageId,
    status,
    setDeliveredAt: setDeliveredAt,
  );

  Future<void> markAllMessagesAsRead(
    String chatRoomId,
    String currentUid,
    String otherUid,
  ) =>
      _firestoreService.markAllMessagesAsRead(chatRoomId, currentUid, otherUid);

  Future<void> resetUnreadCount(String chatRoomId, String currentUid) =>
      _firestoreService.resetUnreadCount(chatRoomId, currentUid);

  Future<void> updateChatRoom(String chatRoomId, Map<String, dynamic> data) =>
      _firestoreService.updateChatRoom(chatRoomId, data);

  Future<ChatRoomModel?> getChatRoom(String chatRoomId) =>
      _firestoreService.getChatRoom(chatRoomId);

  Stream<List<MediaItem>> chatMediaStream(
    String chatRoomId,
    String currentUid,
  ) =>
      _firestoreService.chatMediaStream(chatRoomId, currentUid);

  Stream<int> unreadCountStream(
    String chatRoomId,
    String currentUid,
    String otherUid,
  ) => _firestoreService.unreadCountStream(
    chatRoomId,
    currentUid,
    otherUid,
  );
}
