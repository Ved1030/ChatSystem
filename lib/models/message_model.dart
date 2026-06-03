import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String? id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isDeleted;
  final DateTime? deletedAt;
  final List<String> deletedForUsers;

  const MessageModel({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedForUsers = const [],
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      deletedForUsers: List<String>.from(map['deletedForUsers'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedForUsers': deletedForUsers,
    };
  }
}
