import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_constants.dart';
import '../models/album_model.dart';
import '../models/chat_model.dart';
import '../models/media_model.dart';
import '../models/message_model.dart';
import '../models/plan_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);
  CollectionReference get _chatRooms =>
      _firestore.collection(FirebaseConstants.chatRoomsCollection);
  CollectionReference get _albums =>
      _firestore.collection(FirebaseConstants.albumsCollection);
  CollectionReference get _plans =>
      _firestore.collection(FirebaseConstants.plansCollection);

  DocumentReference userDoc(String uid) => _users.doc(uid);
  DocumentReference chatRoomDoc(String id) => _chatRooms.doc(id);
  DocumentReference albumDoc(String id) => _albums.doc(id);
  CollectionReference messagesRef(String chatRoomId) => _chatRooms
      .doc(chatRoomId)
      .collection(FirebaseConstants.messagesCollection);
  CollectionReference albumPhotosRef(String albumId) =>
      _albums.doc(albumId).collection(FirebaseConstants.albumPhotosCollection);

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
              .map(
                (doc) => ChatRoomModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .where((room) => !room.deletedForUsers.contains(currentUid))
              .toList();
        });
  }

  String getChatRoomId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<ChatRoomModel> getOrCreateChatRoom(
    String currentUid,
    String otherUid,
  ) async {
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

    return ChatRoomModel.fromMap(
      doc.data() as Map<String, dynamic>,
      chatRoomId,
    );
  }

  Stream<List<MessageModel>> messagesStream(
    String chatRoomId,
    String currentUid, {
    DateTime? clearedAt,
  }) {
    var query = messagesRef(
      chatRoomId,
    ).orderBy(FirebaseConstants.timestamp, descending: false);

    return query.snapshots().map((snapshot) {
      var messages = snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      messages = messages.where((msg) {
        return !msg.deletedForUsers.contains(currentUid);
      }).toList();

      messages = messages.where((msg) {
        if (msg.isTemporary && msg.isExpired) return false;
        return true;
      }).toList();

      if (clearedAt != null) {
        messages = messages.where((msg) {
          return msg.timestamp.isAfter(clearedAt);
        }).toList();
      }

      return messages;
    });
  }

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
    final message = MessageModel(
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      timestamp: DateTime.now(),
      messageType: messageType,
      imageMode: imageMode,
      mediaUrl: mediaUrl,
      expiresAt: expiresAt,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSender: replyToSender,
    );

    final docRef = await messagesRef(chatRoomId).add(message.toMap());
    final messageId = docRef.id;

    final displayText = messageType == 'image'
        ? (imageMode == 'view_once' ? 'View Once Image' : 'Image')
        : text;

    await chatRoomDoc(chatRoomId).update({
      FirebaseConstants.lastMessage: displayText,
      FirebaseConstants.lastMessageTime: FieldValue.serverTimestamp(),
    });

    await incrementUnreadCount(chatRoomId, receiverId);

    return messageId;
  }

  Future<void> deleteMessageForEveryone(
    String chatRoomId,
    String messageId,
  ) async {
    await messagesRef(chatRoomId).doc(messageId).update({
      FirebaseConstants.isDeleted: true,
      FirebaseConstants.deletedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessageForMe(
    String chatRoomId,
    String messageId,
    String currentUid,
  ) async {
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
    await chatRoomDoc(
      chatRoomId,
    ).update({FirebaseConstants.clearedAt: FieldValue.serverTimestamp()});
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
    final blockedByUser1 = List<String>.from(
      user1Data?['blockedUsers'] as List? ?? [],
    );
    if (blockedByUser1.contains(uid2)) return true;

    final user2Doc = await userDoc(uid2).get();
    final user2Data = user2Doc.data() as Map<String, dynamic>?;
    final blockedByUser2 = List<String>.from(
      user2Data?['blockedUsers'] as List? ?? [],
    );
    if (blockedByUser2.contains(uid1)) return true;

    return false;
  }

  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    await userDoc(uid).update({
      FirebaseConstants.isOnline: isOnline,
      FirebaseConstants.lastSeen: FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AlbumModel>> albumsStream(String currentUid) {
    return _albums
        .where(FirebaseConstants.participants, arrayContains: currentUid)
        .orderBy(FirebaseConstants.createdAt, descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => AlbumModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  Future<String> addAlbum(AlbumModel album) async {
    final docRef = await _albums.add(album.toMap());
    return docRef.id;
  }

  Future<void> updateAlbum(String albumId, Map<String, dynamic> data) async {
    await albumDoc(albumId).update(data);
  }

  Future<void> deleteAlbum(String albumId) async {
    await albumDoc(albumId).delete();
  }

  Stream<List<AlbumPhotoModel>> albumPhotosStream(String albumId) {
    return albumPhotosRef(
      albumId,
    ).orderBy(FirebaseConstants.createdAt, descending: false).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map(
            (doc) => AlbumPhotoModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    });
  }

  Future<String> addAlbumPhoto(String albumId, AlbumPhotoModel photo) async {
    final docRef = await albumPhotosRef(albumId).add(photo.toMap());
    await albumDoc(
      albumId,
    ).update({FirebaseConstants.photoCount: FieldValue.increment(1)});
    return docRef.id;
  }

  Future<void> deleteAlbumPhoto(String albumId, String photoId) async {
    await albumPhotosRef(albumId).doc(photoId).delete();
    await albumDoc(
      albumId,
    ).update({FirebaseConstants.photoCount: FieldValue.increment(-1)});
  }

  Future<void> deleteAllAlbumPhotos(String albumId) async {
    final snapshot = await albumPhotosRef(albumId).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<List<PlanModel>> plansStream(String currentUid) {
    return _plans
        .where(FirebaseConstants.participants, arrayContains: currentUid)
        .orderBy(FirebaseConstants.createdAt, descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => PlanModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  Future<void> addPlan(PlanModel plan) async {
    await _plans.add(plan.toMap());
  }

  Future<void> updatePlan(String planId, Map<String, dynamic> data) async {
    await _plans.doc(planId).update(data);
  }

  Future<void> deletePlan(String planId) async {
    await _plans.doc(planId).delete();
  }

  Future<void> updateMessageStatus(
    String chatRoomId,
    String messageId,
    String status, {
    bool setDeliveredAt = false,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (status == 'delivered' || setDeliveredAt) {
      data['deliveredAt'] = FieldValue.serverTimestamp();
    }
    if (status == 'read') {
      data['readAt'] = FieldValue.serverTimestamp();
    }
    await messagesRef(chatRoomId).doc(messageId).update(data);
  }

  Future<void> markAllMessagesAsRead(
    String chatRoomId,
    String currentUid,
    String otherUid,
  ) async {
    final snapshot = await messagesRef(chatRoomId)
        .where(FirebaseConstants.senderId, isEqualTo: otherUid)
        .get();

    var batch = _firestore.batch();
    int count = 0;
    for (final doc in snapshot.docs) {
      final docData = doc.data() as Map<String, dynamic>?;
      final docStatus = docData?['status'] as String? ?? 'sent';
      if (docStatus == 'read') continue;
      final updates = <String, dynamic>{
        'status': 'read',
        'readAt': FieldValue.serverTimestamp(),
      };
      if (docStatus == 'sent') {
        updates['deliveredAt'] = FieldValue.serverTimestamp();
      }
      batch.update(doc.reference, updates);
      count++;
      if (count % 400 == 0) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }
    if (count > 0) {
      await batch.commit();
    }

    await chatRoomDoc(
      chatRoomId,
    ).update({'${FirebaseConstants.unreadCounts}.$currentUid': 0});
  }

  Stream<List<MediaItem>> chatMediaStream(
    String chatRoomId,
    String currentUid,
  ) {
    return messagesRef(chatRoomId)
        .orderBy(FirebaseConstants.timestamp, descending: true)
        .snapshots()
        .map((snapshot) {
          final items = <MediaItem>[];
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final messageType = data['messageType'] as String?;
            final imageMode = data['imageMode'] as String?;
            final isDeleted = data['isDeleted'] as bool? ?? false;

            if (isDeleted) continue;
            if (imageMode == 'view_once') continue;
            if (imageMode == 'temporary') {
              final expiresAt =
                  (data['expiresAt'] as Timestamp?)?.toDate();
              if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
                continue;
              }
            }

            final deletedFor = List<String>.from(data['deletedForUsers'] as List? ?? []);
            if (deletedFor.contains(currentUid)) continue;

            if (messageType == 'image') {
              final mediaUrl = data['mediaUrl'] as String?;
              if (mediaUrl != null && mediaUrl.isNotEmpty) {
                final alreadyAdded = items.any((item) => item.url == mediaUrl);
                if (!alreadyAdded) {
                  items.add(MediaItem(
                    url: mediaUrl,
                    messageId: doc.id,
                    senderId: data['senderId'] as String? ?? '',
                  ));
                }
              }
            } else {
              final text = data['text'] as String? ?? '';
              if (_isImageUrl(text)) {
                final alreadyAdded = items.any((item) => item.url == text);
                if (!alreadyAdded) {
                  items.add(MediaItem(
                    url: text,
                    messageId: doc.id,
                    senderId: data['senderId'] as String? ?? '',
                  ));
                }
              }
            }
          }
          return items;
        });
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('http') &&
        (lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.gif') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.bmp') ||
            lower.contains('firebasestorage.googleapis.com') ||
            lower.contains('supabase'));
  }

  Future<ChatRoomModel?> getChatRoom(String chatRoomId) async {
    final doc = await chatRoomDoc(chatRoomId).get();
    if (!doc.exists) return null;
    return ChatRoomModel.fromMap(
      doc.data() as Map<String, dynamic>,
      chatRoomId,
    );
  }

  Future<void> updateChatRoom(
    String chatRoomId,
    Map<String, dynamic> data,
  ) async {
    await chatRoomDoc(chatRoomId).update(data);
  }

  Future<void> deliverIncomingMessages(
    String currentUid,
    List<String> chatRoomIds,
  ) async {
    var batch = _firestore.batch();
    int count = 0;

    for (final roomId in chatRoomIds) {
      final snapshot = await messagesRef(roomId)
          .where(FirebaseConstants.receiverId, isEqualTo: currentUid)
          .where('status', isEqualTo: 'sent')
          .get();

      for (final doc in snapshot.docs) {
        if (count > 0 && count % 400 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
        batch.update(doc.reference, {
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> incrementUnreadCount(
    String chatRoomId,
    String receiverUid,
  ) async {
    await chatRoomDoc(chatRoomId).update({
      '${FirebaseConstants.unreadCounts}.$receiverUid': FieldValue.increment(1),
    });
  }

  Future<void> resetUnreadCount(String chatRoomId, String currentUid) async {
    await chatRoomDoc(
      chatRoomId,
    ).update({'${FirebaseConstants.unreadCounts}.$currentUid': 0});
  }

  Stream<int> unreadCountStream(
    String chatRoomId,
    String currentUid,
    String otherUid,
  ) {
    return messagesRef(chatRoomId)
        .where(FirebaseConstants.senderId, isEqualTo: otherUid)
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['isDeleted'] == true) continue;
            final deletedFor = data['deletedForUsers'] as List<dynamic>?;
            if (deletedFor != null && deletedFor.contains(currentUid)) continue;
            final status = data['status'] as String? ?? 'sent';
            if (status != 'read') {
              count++;
            }
          }
          return count;
        });
  }
}
