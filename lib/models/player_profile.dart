class PlayerProfile {
  final String playerName;
  final String profession;
  final String schedule;
  final String goal;

  const PlayerProfile({
    required this.playerName,
    required this.profession,
    required this.schedule,
    required this.goal,
  });

  /// True once the user has at least set a name.
  bool get hasIdentity => playerName.trim().isNotEmpty;

  /// True once both name AND goal are saved — enough to reach the dashboard.
  /// profession/schedule are filled during onboarding but are not required
  /// for the routing gate so a partially-completed onboarding never loops.
  bool get isComplete => playerName.trim().isNotEmpty && goal.trim().isNotEmpty;

  PlayerProfile copyWith({
    String? playerName,
    String? profession,
    String? schedule,
    String? goal,
  }) {
    return PlayerProfile(
      playerName: playerName ?? this.playerName,
      profession: profession ?? this.profession,
      schedule: schedule ?? this.schedule,
      goal: goal ?? this.goal,
    );
  }

  @override
  String toString() =>
      'PlayerProfile(playerName: $playerName, profession: $profession, '
      'schedule: $schedule, goal: $goal, isComplete: $isComplete)';
}
