import 'package:cloud_firestore/cloud_firestore.dart';

class AlbumModel {
  final String? id;
  final List<String> participants;
  final String creatorId;
  final String coverUrl;
  final String title;
  final String description;
  final bool isPrivate;
  final String? pin;
  final int photoCount;
  final DateTime createdAt;

  const AlbumModel({
    this.id,
    required this.participants,
    required this.creatorId,
    required this.coverUrl,
    required this.title,
    this.description = '',
    this.isPrivate = false,
    this.pin,
    this.photoCount = 0,
    required this.createdAt,
  });

  factory AlbumModel.fromMap(Map<String, dynamic> map, String id) {
    return AlbumModel(
      id: id,
      participants: List<String>.from(map['participants'] as List? ?? []),
      creatorId: map['creatorId'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isPrivate: map['isPrivate'] as bool? ?? false,
      pin: map['pin'] as String?,
      photoCount: (map['photoCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'creatorId': creatorId,
      'coverUrl': coverUrl,
      'title': title,
      'description': description,
      'isPrivate': isPrivate,
      'pin': pin,
      'photoCount': photoCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class AlbumPhotoModel {
  final String? id;
  final String imageUrl;
  final String creatorId;
  final DateTime createdAt;

  const AlbumPhotoModel({
    this.id,
    required this.imageUrl,
    required this.creatorId,
    required this.createdAt,
  });

  factory AlbumPhotoModel.fromMap(Map<String, dynamic> map, String id) {
    return AlbumPhotoModel(
      id: id,
      imageUrl: map['imageUrl'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'creatorId': creatorId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
