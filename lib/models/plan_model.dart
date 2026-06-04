import 'package:cloud_firestore/cloud_firestore.dart';

enum PlanCategory { travel, food, adventure, movies }

enum PlanStatus { planning, done, cancelled }

class PlanModel {
  final String? id;
  final List<String> participants;
  final String creatorId;
  final String title;
  final PlanCategory category;
  final PlanStatus status;
  final DateTime? deadline;
  final DateTime createdAt;

  const PlanModel({
    this.id,
    required this.participants,
    required this.creatorId,
    required this.title,
    this.category = PlanCategory.travel,
    this.status = PlanStatus.planning,
    this.deadline,
    required this.createdAt,
  });

  factory PlanModel.fromMap(Map<String, dynamic> map, String id) {
    return PlanModel(
      id: id,
      participants: List<String>.from(map['participants'] as List? ?? []),
      creatorId: map['creatorId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      category: _categoryFromString(map['category'] as String? ?? 'travel'),
      status: _statusFromString(map['status'] as String? ?? 'planning'),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'creatorId': creatorId,
      'title': title,
      'category': _categoryToString(category),
      'status': _statusToString(status),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static PlanCategory _categoryFromString(String s) {
    switch (s) {
      case 'food':
        return PlanCategory.food;
      case 'adventure':
        return PlanCategory.adventure;
      case 'movies':
        return PlanCategory.movies;
      default:
        return PlanCategory.travel;
    }
  }

  static String _categoryToString(PlanCategory c) {
    switch (c) {
      case PlanCategory.food:
        return 'food';
      case PlanCategory.adventure:
        return 'adventure';
      case PlanCategory.movies:
        return 'movies';
      case PlanCategory.travel:
        return 'travel';
    }
  }

  static PlanStatus _statusFromString(String s) {
    switch (s) {
      case 'done':
        return PlanStatus.done;
      case 'cancelled':
        return PlanStatus.cancelled;
      default:
        return PlanStatus.planning;
    }
  }

  static String _statusToString(PlanStatus s) {
    switch (s) {
      case PlanStatus.done:
        return 'done';
      case PlanStatus.cancelled:
        return 'cancelled';
      case PlanStatus.planning:
        return 'planning';
    }
  }
}
