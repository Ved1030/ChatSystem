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

  Stream<List<UserModel>> allUsersExcept(String currentUid) {
    return _users.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) => user.uid != currentUid)
          .toList();
    });
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

  Stream<List<MessageModel>> messagesStream(String chatRoomId) {
    return messagesRef(chatRoomId)
        .orderBy(FirebaseConstants.timestamp, descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
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

  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    await userDoc(uid).update({
      FirebaseConstants.isOnline: isOnline,
      FirebaseConstants.lastSeen: FieldValue.serverTimestamp(),
    });
  }
}
