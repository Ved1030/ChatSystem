class NotificationData {
  final String type;
  final String senderId;
  final String receiverId;
  final String roomId;
  final String? messageId;

  const NotificationData({
    required this.type,
    required this.senderId,
    required this.receiverId,
    required this.roomId,
    this.messageId,
  });

  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      type: map['type'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      messageId: map['messageId'] as String?,
    );
  }

  Map<String, String> toMap() {
    return {
      'type': type,
      'senderId': senderId,
      'receiverId': receiverId,
      'roomId': roomId,
      if (messageId != null) 'messageId': messageId!,
    };
  }
}
