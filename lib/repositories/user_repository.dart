import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService = FirestoreService();

  Stream<UserModel> userStream(String uid) => _firestoreService.userStream(uid);

  Stream<List<UserModel>> allUsersExcept(String currentUid) =>
      _firestoreService.allUsersExcept(currentUid);

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
}
