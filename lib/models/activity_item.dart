import '../models/profile.dart';

enum ActivityType { like, comment, follow }

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.createdAt,
    required this.actor,
    this.postId,
  });

  final ActivityType type;
  final DateTime createdAt;
  final Profile actor;
  final String? postId;

  String message(String actorName) => switch (type) {
    ActivityType.like => '$actorName gefällt dein Beitrag.',
    ActivityType.comment => '$actorName hat deinen Beitrag kommentiert.',
    ActivityType.follow => '$actorName folgt dir jetzt.',
  };
}
