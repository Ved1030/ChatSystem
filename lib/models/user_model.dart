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
  final String? oneSignalId;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

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
    this.oneSignalId,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
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
      oneSignalId: map['oneSignalId'] as String?,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      vibrationEnabled: map['vibrationEnabled'] as bool? ?? true,
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
      'oneSignalId': oneSignalId,
      'notificationsEnabled': notificationsEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
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
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
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
    String? oneSignalId,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
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
      oneSignalId: oneSignalId ?? this.oneSignalId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}
