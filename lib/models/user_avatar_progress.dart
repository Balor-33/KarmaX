class UserAvatarProgress {
  final String id;
  final String userId;
  final String? selectedAvatarId;
  final int currentLevel;
  final String? dominantStat;
  final List<String> equippedBadges;
  final DateTime lastUpdated;

  UserAvatarProgress({
    required this.id,
    required this.userId,
    required this.selectedAvatarId,
    required this.currentLevel,
    required this.dominantStat,
    required this.equippedBadges,
    required this.lastUpdated,
  });

  factory UserAvatarProgress.fromJson(Map<String, dynamic> json) {
    final badgesRaw = json['equipped_badges'];
    List<String> badges = [];
    if (badgesRaw is List) {
      badges = badgesRaw.map((e) => e.toString()).toList();
    } else if (badgesRaw is String) {
      badges = badgesRaw.split(',').where((e) => e.isNotEmpty).toList();
    }

    return UserAvatarProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      // selected_avatar_id is nullable in the DB (e.g. before a user has
      // picked an avatar, or if their chosen avatar was later removed
      // from the catalog and the FK was set to null) — don't force-cast.
      selectedAvatarId: json['selected_avatar_id'] as String?,
      currentLevel: json['current_level'] as int,
      dominantStat: json['dominant_stat'] as String?,
      equippedBadges: badges,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'selected_avatar_id': selectedAvatarId,
      'current_level': currentLevel,
      'dominant_stat': dominantStat,
      'equipped_badges': equippedBadges,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  UserAvatarProgress copyWith({
    String? id,
    String? userId,
    String? selectedAvatarId,
    int? currentLevel,
    String? dominantStat,
    List<String>? equippedBadges,
    DateTime? lastUpdated,
  }) {
    return UserAvatarProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      selectedAvatarId: selectedAvatarId ?? this.selectedAvatarId,
      currentLevel: currentLevel ?? this.currentLevel,
      dominantStat: dominantStat ?? this.dominantStat,
      equippedBadges: equippedBadges ?? this.equippedBadges,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
