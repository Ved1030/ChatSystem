import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<String> deletedForUsers;
  final DateTime? clearedAt;
  final Map<String, int> unreadCounts;
  final String? wallpaper;
  final Map<String, String> nicknames;
  final List<String> mutedBy;
  final Map<String, DateTime> mutedUntil;

  const ChatRoomModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.deletedForUsers = const [],
    this.clearedAt,
    this.unreadCounts = const {},
    this.wallpaper,
    this.nicknames = const {},
    this.mutedBy = const [],
    this.mutedUntil = const {},
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['unreadCounts'] as Map<String, dynamic>?;
    final unread =
        raw?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? <String, int>{};
    final rawNicknames = map['nicknames'] as Map<String, dynamic>?;
    final nicknames =
        rawNicknames?.map((k, v) => MapEntry(k, v as String)) ??
        <String, String>{};
    final rawMutedUntil = map['mutedUntil'] as Map<String, dynamic>?;
    final mutedUntil = rawMutedUntil?.map(
      (k, v) => MapEntry(k, (v as Timestamp).toDate()),
    ) ?? <String, DateTime>{};
    return ChatRoomModel(
      id: id,
      participants: List<String>.from(map['participants'] as List? ?? []),
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      deletedForUsers: List<String>.from(map['deletedForUsers'] as List? ?? []),
      clearedAt: (map['clearedAt'] as Timestamp?)?.toDate(),
      unreadCounts: unread,
      wallpaper: map['wallpaper'] as String?,
      nicknames: nicknames,
      mutedBy: List<String>.from(map['mutedBy'] as List? ?? []),
      mutedUntil: mutedUntil,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'deletedForUsers': deletedForUsers,
      'clearedAt': clearedAt != null ? Timestamp.fromDate(clearedAt!) : null,
      'unreadCounts': unreadCounts,
      'wallpaper': wallpaper,
      'nicknames': nicknames,
      'mutedBy': mutedBy,
      'mutedUntil': mutedUntil.map(
        (k, v) => MapEntry(k, Timestamp.fromDate(v)),
      ),
    };
  }

  String? nicknameFor(String uid) => nicknames[uid];
}
