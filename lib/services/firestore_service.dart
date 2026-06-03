import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_constants.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _users => _firestore.collection(FirebaseConstants.usersCollection);
  CollectionReference get _chatRooms => _firestore.collection(FirebaseConstants.chatRoomsCollection);

  DocumentReference userDoc(String uid) => _users.doc(uid);
  DocumentReference chatRoomDoc(String id) => _chatRooms.doc(id);
  CollectionReference messagesRef(String chatRoomId) =>
      _chatRooms.doc(chatRoomId).collection(FirebaseConstants.messagesCollection);

  Stream<UserModel> userStream(String uid) {
    return userDoc(uid).snapshots().map(
      (snapshot) => UserModel.fromMap(snapshot.data() as Map<String, dynamic>),
    );
  }

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final snapshot = await _users
        .where(FirebaseConstants.username, isGreaterThanOrEqualTo: query)
        .where(FirebaseConstants.username, isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<bool> usernameExists(String username) async {
    final snapshot = await _users
        .where(FirebaseConstants.username, isEqualTo: username)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final snapshot = await _users
        .where(FirebaseConstants.email, isEqualTo: email)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> createUser(UserModel user) async {
    await userDoc(user.uid).set(user.toMap());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await userDoc(uid).update(data);
  }

  Future<UserModel?> getUser(String uid) async {
    final snapshot = await userDoc(uid).get();
    if (!snapshot.exists) return null;
    return UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final snapshot = await _users
        .where(FieldPath.documentId, whereIn: uids)
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Stream<List<ChatRoomModel>> chatRoomsStream(String currentUid) {
    return _chatRooms
        .where(FirebaseConstants.participants, arrayContains: currentUid)
        .orderBy(FirebaseConstants.lastMessageTime, descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoomModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((room) => !room.deletedForUsers.contains(currentUid))
          .toList();
    });
  }

  String getChatRoomId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<ChatRoomModel> getOrCreateChatRoom(String currentUid, String otherUid) async {
    final chatRoomId = getChatRoomId(currentUid, otherUid);
    final doc = await chatRoomDoc(chatRoomId).get();

    if (!doc.exists) {
      final room = ChatRoomModel(
        id: chatRoomId,
        participants: [currentUid, otherUid],
      );
      await chatRoomDoc(chatRoomId).set(room.toMap());
      return room;
    }

    return ChatRoomModel.fromMap(doc.data() as Map<String, dynamic>, chatRoomId);
  }

  Stream<List<MessageModel>> messagesStream(String chatRoomId, String currentUid, {DateTime? clearedAt}) {
    var query = messagesRef(chatRoomId)
        .orderBy(FirebaseConstants.timestamp, descending: false);

    return query.snapshots().map((snapshot) {
      var messages = snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      messages = messages.where((msg) {
        return !msg.deletedForUsers.contains(currentUid);
      }).toList();

      if (clearedAt != null) {
        messages = messages.where((msg) {
          return msg.timestamp.isAfter(clearedAt);
        }).toList();
      }

      return messages;
    });
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final message = MessageModel(
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      timestamp: DateTime.now(),
    );

    await messagesRef(chatRoomId).add(message.toMap());

    await chatRoomDoc(chatRoomId).update({
      FirebaseConstants.lastMessage: text,
      FirebaseConstants.lastMessageTime: FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessageForEveryone(String chatRoomId, String messageId) async {
    await messagesRef(chatRoomId).doc(messageId).update({
      FirebaseConstants.isDeleted: true,
      FirebaseConstants.deletedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessageForMe(String chatRoomId, String messageId, String currentUid) async {
    await messagesRef(chatRoomId).doc(messageId).update({
      FirebaseConstants.deletedForUsers: FieldValue.arrayUnion([currentUid]),
    });
  }

  Future<void> deleteChatForMe(String chatRoomId, String currentUid) async {
    await chatRoomDoc(chatRoomId).update({
      FirebaseConstants.deletedForUsers: FieldValue.arrayUnion([currentUid]),
    });
  }

  Future<void> clearChat(String chatRoomId, String currentUid) async {
    await chatRoomDoc(chatRoomId).update({
      FirebaseConstants.clearedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(String currentUid, String blockedUid) async {
    await userDoc(currentUid).update({
      FirebaseConstants.blockedUsers: FieldValue.arrayUnion([blockedUid]),
    });
  }

  Future<void> unblockUser(String currentUid, String blockedUid) async {
    await userDoc(currentUid).update({
      FirebaseConstants.blockedUsers: FieldValue.arrayRemove([blockedUid]),
    });
  }

  Future<bool> isBlocked(String uid1, String uid2) async {
    final user1Doc = await userDoc(uid1).get();
    final user1Data = user1Doc.data() as Map<String, dynamic>?;
    final blockedByUser1 = List<String>.from(user1Data?['blockedUsers'] as List? ?? []);
    if (blockedByUser1.contains(uid2)) return true;

    final user2Doc = await userDoc(uid2).get();
    final user2Data = user2Doc.data() as Map<String, dynamic>?;
    final blockedByUser2 = List<String>.from(user2Data?['blockedUsers'] as List? ?? []);
    if (blockedByUser2.contains(uid1)) return true;

    return false;
  }

  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    await userDoc(uid).update({
      FirebaseConstants.isOnline: isOnline,
      FirebaseConstants.lastSeen: FieldValue.serverTimestamp(),
    });
  }
}
