import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String username;
  final String email;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final bool isOnline;
  final List<String> blockedUsers;
  final String? fcmToken;
  final bool notificationsEnabled;

  const UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    this.photoUrl,
    this.createdAt,
    this.lastSeen,
    this.isOnline = false,
    this.blockedUsers = const [],
    this.fcmToken,
    this.notificationsEnabled = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      isOnline: map['isOnline'] as bool? ?? false,
      blockedUsers: List<String>.from(map['blockedUsers'] as List? ?? []),
      fcmToken: map['fcmToken'] as String?,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastSeen': lastSeen ?? FieldValue.serverTimestamp(),
      'isOnline': isOnline,
      'blockedUsers': blockedUsers,
      'fcmToken': fcmToken,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'username': username,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen ?? FieldValue.serverTimestamp(),
      'notificationsEnabled': notificationsEnabled,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? username,
    String? email,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
    List<String>? blockedUsers,
    String? fcmToken,
    bool? notificationsEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
