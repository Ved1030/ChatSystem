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

  String get createdBy => creatorId;
  String get coverImageUrl => coverUrl;
  int get imageCount => photoCount;

  factory AlbumModel.fromMap(Map<String, dynamic> map, String id) {
    return AlbumModel(
      id: id,
      participants: List<String>.from(map['participants'] as List? ?? []),
      creatorId: map['creatorId'] as String? ?? map['createdBy'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? map['coverImageUrl'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isPrivate: map['isPrivate'] as bool? ?? false,
      pin: map['pin'] as String?,
      photoCount: (map['photoCount'] as num?)?.toInt() ?? (map['imageCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'creatorId': creatorId,
      'createdBy': creatorId,
      'coverUrl': coverUrl,
      'coverImageUrl': coverUrl,
      'title': title,
      'description': description,
      'isPrivate': isPrivate,
      'pin': pin,
      'photoCount': photoCount,
      'imageCount': photoCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AlbumModel copyWith({
    String? id,
    List<String>? participants,
    String? creatorId,
    String? coverUrl,
    String? title,
    String? description,
    bool? isPrivate,
    String? pin,
    int? photoCount,
    DateTime? createdAt,
  }) {
    return AlbumModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      creatorId: creatorId ?? this.creatorId,
      coverUrl: coverUrl ?? this.coverUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
      pin: pin ?? this.pin,
      photoCount: photoCount ?? this.photoCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AlbumPhotoModel {
  final String? id;
  final String imageUrl;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String? caption;

  const AlbumPhotoModel({
    this.id,
    required this.imageUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    this.caption,
  });

  String get creatorId => uploadedBy;
  DateTime get createdAt => uploadedAt;

  factory AlbumPhotoModel.fromMap(Map<String, dynamic> map, String id) {
    return AlbumPhotoModel(
      id: id,
      imageUrl: map['imageUrl'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? map['creatorId'] as String? ?? '',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      caption: map['caption'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'uploadedBy': uploadedBy,
      'creatorId': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'createdAt': Timestamp.fromDate(uploadedAt),
      'caption': caption,
    };
  }
}
