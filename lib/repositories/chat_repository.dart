import '../models/album_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/plan_model.dart';
import '../services/firestore_service.dart';

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

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String text,
  }) => _firestoreService.sendMessage(
    chatRoomId: chatRoomId,
    senderId: senderId,
    receiverId: receiverId,
    text: text,
  );

  Future<void> deleteMessageForEveryone(String chatRoomId, String messageId) =>
      _firestoreService.deleteMessageForEveryone(chatRoomId, messageId);

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

  Future<String> addAlbum(AlbumModel album) =>
      _firestoreService.addAlbum(album);

  Future<void> updateAlbum(String albumId, Map<String, dynamic> data) =>
      _firestoreService.updateAlbum(albumId, data);

  Future<void> deleteAlbum(String albumId) =>
      _firestoreService.deleteAlbum(albumId);

  Stream<List<AlbumPhotoModel>> albumPhotosStream(String albumId) =>
      _firestoreService.albumPhotosStream(albumId);

  Future<void> addAlbumPhoto(String albumId, AlbumPhotoModel photo) =>
      _firestoreService.addAlbumPhoto(albumId, photo);

  Future<void> deleteAlbumPhoto(String albumId, String photoId) =>
      _firestoreService.deleteAlbumPhoto(albumId, photoId);

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
    String status,
  ) => _firestoreService.updateMessageStatus(chatRoomId, messageId, status);

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

  Stream<List<String>> chatMediaStream(String chatRoomId) =>
      _firestoreService.chatMediaStream(chatRoomId);
}
