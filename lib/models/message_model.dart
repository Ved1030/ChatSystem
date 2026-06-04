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
  final String status;
  final DateTime? readAt;

  const MessageModel({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedForUsers = const [],
    this.status = 'sent',
    this.readAt,
  });

  bool get isSent => status == 'sent';
  bool get isDeliveredOrRead => status == 'delivered' || status == 'read';
  bool get isRead => status == 'read';

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    String resolvedStatus;
    final statusRaw = map['status'] as String?;
    if (statusRaw != null) {
      resolvedStatus = statusRaw;
    } else if (map['isRead'] == true) {
      resolvedStatus = 'read';
    } else if (map['isDelivered'] == true) {
      resolvedStatus = 'delivered';
    } else {
      resolvedStatus = 'sent';
    }
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      deletedForUsers: List<String>.from(map['deletedForUsers'] as List? ?? []),
      status: resolvedStatus,
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
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
      'status': status,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }
}
