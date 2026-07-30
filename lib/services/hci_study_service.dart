import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/hci_mode.dart';
class HciStudyService {
  final _db = Supabase.instance.client;
  Future<String?> startSession({required String problemTitle}) async {
    final sessionId = HciMode.instance.currentSessionId;
    if (sessionId == null) return null;

    try {
      final userId = _db.auth.currentUser?.id;
      await _db.from('hci_sessions').insert({
        'id': sessionId,
        'user_id': userId,
        'condition': HciMode.instance.conditionLabel,
        'problem_title': problemTitle,
      });
      return sessionId;
    } catch (e) {
      debugPrint('HciStudyService.startSession failed: $e');
      return null;
    }
  }
  Future<void> logQuestionEvent({
    required int questionIndex,
    required DateTime shownAt,
    DateTime? answeredAt,
    DateTime? lastModifiedAt,
    required int revisionCount,
    int backtrackCount = 0,
    int? selectedOptionIndex,
    String? answerText,
  }) async {
    final sessionId = HciMode.instance.currentSessionId;
    if (sessionId == null) return;

    try {
      await _db.from('hci_question_events').upsert(
        {
          'session_id': sessionId,
          'question_index': questionIndex,
          'shown_at': shownAt.toIso8601String(),
          'answered_at': answeredAt?.toIso8601String(),
          'last_modified_at': lastModifiedAt?.toIso8601String(),
          'revision_count': revisionCount,
          'backtrack_count': backtrackCount,
          'selected_option_index': selectedOptionIndex,
          'answer_text': answerText,
        },
        onConflict: 'session_id,question_index',
      );
    } catch (e) {
      debugPrint('HciStudyService.logQuestionEvent failed: $e');
    }
  }
  Future<void> markQuizFinished() async {
    final sessionId = HciMode.instance.currentSessionId;
    if (sessionId == null) return;

    try {
      await _db.from('hci_sessions').update({
        'quiz_finished_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('HciStudyService.markQuizFinished failed: $e');
    }
  }
  Future<void> submitSus({
    required double susScore,
    required List<int> rawAnswers,
  }) async {
    final sessionId = HciMode.instance.currentSessionId;
    if (sessionId == null) return;

    try {
      await _db.from('hci_sessions').update({
        'sus_score': susScore,
        'sus_raw_answers': rawAnswers,
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('HciStudyService.submitSus failed: $e');
    }
  }
  Future<void> submitQuestRating(int rating) async {
    final sessionId = HciMode.instance.currentSessionId;
    try {
      if (sessionId != null) {
        await _db.from('hci_sessions').update({
          'quest_rating': rating,
          'completed_at': DateTime.now().toIso8601String(),
        }).eq('id', sessionId);
      }
    } catch (e) {
      debugPrint('HciStudyService.submitQuestRating failed: $e');
    } finally {
      HciMode.instance.endSession();
    }
  }
}
