import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<String> deletedForUsers;
  final DateTime? clearedAt;

  const ChatRoomModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.deletedForUsers = const [],
    this.clearedAt,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoomModel(
      id: id,
      participants: List<String>.from(map['participants'] as List? ?? []),
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      deletedForUsers: List<String>.from(map['deletedForUsers'] as List? ?? []),
      clearedAt: (map['clearedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'deletedForUsers': deletedForUsers,
      'clearedAt': clearedAt != null ? Timestamp.fromDate(clearedAt!) : null,
    };
  }
}
