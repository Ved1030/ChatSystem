import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

class ChatRepository {
  final FirestoreService _firestoreService = FirestoreService();

  String getChatRoomId(String uid1, String uid2) =>
      _firestoreService.getChatRoomId(uid1, uid2);

  Future<ChatRoomModel> getOrCreateChatRoom(String currentUid, String otherUid) =>
      _firestoreService.getOrCreateChatRoom(currentUid, otherUid);

  Stream<List<MessageModel>> messagesStream(String chatRoomId) =>
      _firestoreService.messagesStream(chatRoomId);

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
}
