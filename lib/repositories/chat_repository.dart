import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

class ChatRepository {
  final FirestoreService _firestoreService = FirestoreService();

  String getChatRoomId(String uid1, String uid2) =>
      _firestoreService.getChatRoomId(uid1, uid2);

  Future<ChatRoomModel> getOrCreateChatRoom(String currentUid, String otherUid) =>
      _firestoreService.getOrCreateChatRoom(currentUid, otherUid);

  Stream<List<ChatRoomModel>> chatRoomsStream(String currentUid) =>
      _firestoreService.chatRoomsStream(currentUid);

  Stream<List<MessageModel>> messagesStream(String chatRoomId, String currentUid, {DateTime? clearedAt}) =>
      _firestoreService.messagesStream(chatRoomId, currentUid, clearedAt: clearedAt);

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String text,
  }) =>
      _firestoreService.sendMessage(
        chatRoomId: chatRoomId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
      );

  Future<void> deleteMessageForEveryone(String chatRoomId, String messageId) =>
      _firestoreService.deleteMessageForEveryone(chatRoomId, messageId);

  Future<void> deleteMessageForMe(String chatRoomId, String messageId, String currentUid) =>
      _firestoreService.deleteMessageForMe(chatRoomId, messageId, currentUid);

  Future<void> deleteChatForMe(String chatRoomId, String currentUid) =>
      _firestoreService.deleteChatForMe(chatRoomId, currentUid);

  Future<void> clearChat(String chatRoomId, String currentUid) =>
      _firestoreService.clearChat(chatRoomId, currentUid);

  Future<bool> isBlocked(String uid1, String uid2) =>
      _firestoreService.isBlocked(uid1, uid2);
}
