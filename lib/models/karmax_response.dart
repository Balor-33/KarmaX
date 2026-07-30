import 'dart:convert';

class Quest {
  final String title;
  final int xp;
  final String category;
  final String why;

  Quest({
    required this.title,
    required this.xp,
    required this.category,
    required this.why,
  });

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        title: json['title'] as String,
        xp: json['xp'] as int,
        category: json['category'] as String,
        why: json['why'] as String,
      );
}

class KarmaxResponse {
  final String primaryProblem;
  final String rootCause;
  final String reasoning;
  final List<Quest> daily;
  final List<Quest> weekly;

  KarmaxResponse({
    required this.primaryProblem,
    required this.rootCause,
    required this.reasoning,
    required this.daily,
    required this.weekly,
  });

  factory KarmaxResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> dailyJson = json['daily'] as List<dynamic>;
    List<dynamic> weeklyJson = json['weekly'] as List<dynamic>;

    return KarmaxResponse(
      primaryProblem: json['primary_problem'] as String,
      rootCause: json['root_cause'] as String,
      reasoning: json['reasoning'] as String,
      daily: dailyJson
          .map((e) => Quest.fromJson(e as Map<String, dynamic>))
          .toList(),
      weekly: weeklyJson
          .map((e) => Quest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Helper to pretty‑print for debugging
  @override
  String toString() => jsonEncode({
        'primary_problem': primaryProblem,
        'root_cause': rootCause,
        'reasoning': reasoning,
        'daily': daily.map((q) => q.toJson()).toList(),
        'weekly': weekly.map((q) => q.toJson()).toList(),
      });
}

extension on Quest {
  Map<String, dynamic> toJson() => {
        'title': title,
        'xp': xp,
        'category': category,
        'why': why,
      };
}
