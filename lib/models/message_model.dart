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
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String messageType;
  final String? imageMode;
  final String? mediaUrl;
  final DateTime? expiresAt;
  final bool viewed;

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
    this.deliveredAt,
    this.readAt,
    this.messageType = 'text',
    this.imageMode,
    this.mediaUrl,
    this.expiresAt,
    this.viewed = false,
  });

  bool get isSent => status == 'sent';
  bool get isDeliveredOrRead => status == 'delivered' || status == 'read';
  bool get isRead => status == 'read';
  bool get isImage => messageType == 'image';
  bool get isVideo => messageType == 'video';
  bool get isAudio => messageType == 'audio';
  bool get isText => messageType == 'text';
  bool get isViewOnce => imageMode == 'view_once';
  bool get isTemporary => imageMode == 'temporary';
  bool get isNormalImage => imageMode == 'normal';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

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
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      messageType: map['messageType'] as String? ?? 'text',
      imageMode: map['imageMode'] as String?,
      mediaUrl: map['mediaUrl'] as String?,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      viewed: map['viewed'] as bool? ?? false,
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
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'messageType': messageType,
      'imageMode': imageMode,
      'mediaUrl': mediaUrl,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'viewed': viewed,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    bool? isDeleted,
    DateTime? deletedAt,
    List<String>? deletedForUsers,
    String? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? messageType,
    String? imageMode,
    String? mediaUrl,
    DateTime? expiresAt,
    bool? viewed,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedForUsers: deletedForUsers ?? this.deletedForUsers,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      messageType: messageType ?? this.messageType,
      imageMode: imageMode ?? this.imageMode,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      expiresAt: expiresAt ?? this.expiresAt,
      viewed: viewed ?? this.viewed,
    );
  }
}
