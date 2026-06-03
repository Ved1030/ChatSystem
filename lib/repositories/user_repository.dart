import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService = FirestoreService();

  Stream<UserModel> userStream(String uid) => _firestoreService.userStream(uid);

  Future<List<UserModel>> searchUsers(String query) =>
      _firestoreService.searchUsers(query);

  Future<bool> usernameExists(String username) =>
      _firestoreService.usernameExists(username);

  Future<bool> emailExists(String email) =>
      _firestoreService.emailExists(email);

  Future<void> createUser(UserModel user) =>
      _firestoreService.createUser(user);

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _firestoreService.updateUser(uid, data);

  Future<UserModel?> getUser(String uid) =>
      _firestoreService.getUser(uid);

  Future<void> updateOnlineStatus(String uid, bool isOnline) =>
      _firestoreService.updateOnlineStatus(uid, isOnline);

  Future<List<UserModel>> getUsersByIds(List<String> uids) =>
      _firestoreService.getUsersByIds(uids);

  Stream<List<ChatRoomModel>> chatRoomsStream(String currentUid) =>
      _firestoreService.chatRoomsStream(currentUid);

  Future<void> blockUser(String currentUid, String blockedUid) =>
      _firestoreService.blockUser(currentUid, blockedUid);

  Future<void> unblockUser(String currentUid, String blockedUid) =>
      _firestoreService.unblockUser(currentUid, blockedUid);

  Future<bool> isBlocked(String uid1, String uid2) =>
      _firestoreService.isBlocked(uid1, uid2);
}
