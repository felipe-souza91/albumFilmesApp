// lib/models/achievement.dart
class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final String category;
  final String ruleType;
  final dynamic ruleValue;
  final Map<String, dynamic> ruleCriteria;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.category,
    required this.ruleType,
    required this.ruleValue,
    required this.ruleCriteria,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['iconUrl'],
      category: json['category'],
      ruleType: json['ruleType'],
      ruleValue: json['ruleValue'],
      ruleCriteria: Map<String, dynamic>.from(json['ruleCriteria'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'category': category,
      'ruleType': ruleType,
      'ruleValue': ruleValue,
      'ruleCriteria': ruleCriteria,
    };
  }
}

class UserAchievement {
  final String userId;
  final String achievementId;
  final bool unlocked;
  final int progress;
  final DateTime? unlockedAt;

  UserAchievement({
    required this.userId,
    required this.achievementId,
    this.unlocked = false,
    this.progress = 0,
    this.unlockedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      userId: json['userId'],
      achievementId: json['achievementId'],
      unlocked: json['unlocked'] ?? false,
      progress: json['progress'] ?? 0,
      unlockedAt: json['unlockedAt'] != null
          ? (json['unlockedAt'] is DateTime
              ? json['unlockedAt']
              : DateTime.parse(json['unlockedAt']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'achievementId': achievementId,
      'unlocked': unlocked,
      'progress': progress,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  UserAchievement copyWith({
    String? userId,
    String? achievementId,
    bool? unlocked,
    int? progress,
    DateTime? unlockedAt,
  }) {
    return UserAchievement(
      userId: userId ?? this.userId,
      achievementId: achievementId ?? this.achievementId,
      unlocked: unlocked ?? this.unlocked,
      progress: progress ?? this.progress,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}
