import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_similarity/string_similarity.dart';
import '../config/api_config.dart';

/// Central AI service – all heavy‑lifting is delegated to the Python FastAPI backend.
/// If the backend cannot be reached, this class returns safe hard‑coded fallback data
/// so the UI never crashes.
///
/// Caching strategy (mirrors the backend's own cache):
///   - Every cached entry carries a timestamp and is expired against a
///     per-endpoint TTL, so stale answers eventually fall off instead of
///     living in SharedPreferences forever.
///   - `analyseProblem` first tries an exact cache hit, then falls back to a
///     fuzzy match against previously-cached problem text on this device,
///     since the same problem is rarely phrased identically twice.
///   - `generateQuests` buckets continuous stats (sleep/study/screen hours,
///     GPA, etc.) before building its cache key, so this device reuses a
///     cached quest set for similar - not just identical - stat inputs.
class AiService {
  // -----------------------------------------------------------------
  //   Configuration
  // -----------------------------------------------------------------
  /// Base URL of the FastAPI backend (Render in production).
  /// Flutter ONLY communicates with this backend — never with Gemini directly.
  static String get _baseUrl => ApiConfig.backendBaseUrl;

  // Cache TTLs.
  static const Duration _problemCacheTtl = Duration(days: 7);
  static const Duration _quizCacheTtl = Duration(days: 7);
  static const Duration _questCacheTtl = Duration(hours: 24);

  /// Normalizes text for cache keys – lower‑cases, trims, and removes punctuation.
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // strip punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // collapse whitespace
        .trim();
  }

  /// Rounds a continuous value to the nearest [step] so similar (not just
  /// identical) inputs share a cache entry.
  double _bucket(double value, double step) => (value / step).round() * step;

  /// Categorizes raw student problem text into semantic intent clusters
  /// so equivalent phrasings (e.g. 'I cannot focus' vs 'I have problem focusing')
  /// share a cache entry.
  String _classifyProblemIntent(String text) {
    final lowered = text.toLowerCase();

    final hasFocus = lowered.contains('focus') ||
        lowered.contains('concentrat') ||
        lowered.contains('distract') ||
        lowered.contains('attention') ||
        lowered.contains('wander') ||
        lowered.contains('mind');
    final hasScreen = lowered.contains('screen') ||
        lowered.contains('phone') ||
        lowered.contains('scroll') ||
        lowered.contains('social media') ||
        lowered.contains('tiktok') ||
        lowered.contains('instagram') ||
        lowered.contains('youtube') ||
        lowered.contains('reels') ||
        lowered.contains('doomscroll');
    final hasSleep = lowered.contains('sleep') ||
        lowered.contains('tired') ||
        lowered.contains('exhaust') ||
        lowered.contains('wake') ||
        lowered.contains('insomnia') ||
        lowered.contains('fatigue') ||
        lowered.contains('nap') ||
        lowered.contains('drowsy') ||
        lowered.contains('yawn');
    final hasProcrastination = lowered.contains('procrastinat') ||
        lowered.contains('delay') ||
        lowered.contains('put off') ||
        lowered.contains('initiat') ||
        lowered.contains('motivation') ||
        lowered.contains('avoid');
    final hasStress = lowered.contains('stress') ||
        lowered.contains('overwhelm') ||
        lowered.contains('burnout') ||
        lowered.contains('burn out');
    final hasStudy = lowered.contains('study') ||
        lowered.contains('exam') ||
        lowered.contains('homework') ||
        lowered.contains('assignment') ||
        lowered.contains('grade') ||
        lowered.contains('gpa') ||
        lowered.contains('subject') ||
        lowered.contains('lecture') ||
        lowered.contains('textbook');

    // ── Specific intents checked BEFORE generic ones ──────────────────────
    final hasSocialAnxiety = lowered.contains('stage fright') ||
        lowered.contains('presentation') ||
        lowered.contains('public speak') ||
        lowered.contains('oral') ||
        lowered.contains('speech') ||
        lowered.contains('perform') ||
        lowered.contains('audience') ||
        lowered.contains('nervou') ||
        lowered.contains('anxi') ||
        lowered.contains('shy') ||
        lowered.contains('embarrass') ||
        lowered.contains('fear speak');
    final hasTimeMgmt = lowered.contains('time manag') ||
        lowered.contains('schedule') ||
        lowered.contains('deadline') ||
        lowered.contains('priorit') ||
        lowered.contains('plan') ||
        lowered.contains('organiz') ||
        lowered.contains('routine') ||
        lowered.contains('structure');
    final hasEating = lowered.contains('eat') ||
        lowered.contains('meal') ||
        lowered.contains('diet') ||
        lowered.contains('food') ||
        lowered.contains('skip meal') ||
        lowered.contains('snack') ||
        lowered.contains('nutrition') ||
        lowered.contains('hungry') ||
        lowered.contains('binge');
    final hasSocialRelations = lowered.contains('friend') ||
        lowered.contains('relation') ||
        lowered.contains('loneli') ||
        lowered.contains('isolat') ||
        lowered.contains('social') ||
        lowered.contains('people') ||
        lowered.contains('communic') ||
        lowered.contains('interact');
    final hasMemory = lowered.contains('memor') ||
        lowered.contains('forget') ||
        lowered.contains('recall') ||
        lowered.contains('retain') ||
        lowered.contains('remember') ||
        lowered.contains('revision');

    if (hasSocialAnxiety) return 'intent:social_anxiety_performance';
    if (hasMemory) return 'intent:memory_retention';
    if (hasEating) return 'intent:eating_habits';
    if (hasTimeMgmt) return 'intent:time_management';
    if (hasSocialRelations && !hasFocus) return 'intent:social_isolation';
    // Generic rules
    if (hasFocus && hasScreen) return 'intent:focus_digital';
    if (hasFocus && hasSleep) return 'intent:focus_burnout';
    if (hasFocus || (hasStudy && !(hasSleep || hasStress || hasProcrastination))) {
      return 'intent:focus_study';
    }
    if (hasSleep) return 'intent:sleep_fatigue';
    if (hasProcrastination) return 'intent:procrastination';
    if (hasStress) return 'intent:stress_anxiety';
    if (hasScreen) return 'intent:digital_drain';

    // ── Dynamic Intent ──────────────────────────────────────────────
    return _dynamicIntent(text);
  }

  // ── Stopwords excluded from dynamic keyword extraction ──────────────
  static const _stopwords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'is', 'am', 'are', 'was', 'were', 'be',
    'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
    'would', 'could', 'should', 'may', 'might', 'shall', 'can', 'i', 'my',
    'me', 'we', 'us', 'our', 'you', 'your', 'it', 'its', 'he', 'she',
    'they', 'them', 'their', 'this', 'that', 'these', 'those', 'what',
    'when', 'where', 'how', 'who', 'which', 'very', 'really', 'just', 'so',
    'too', 'also', 'always', 'never', 'get', 'got', 'feel', 'feels',
    'feeling', 'felt', 'make', 'makes', 'made', 'keep', 'keeps', 'kept',
    'seem', 'seems', 'like', 'want', 'not', 'no', 'any', 'all', 'some',
    'if', 'than', 'then', 'up', 'down', 'out', 'about', 'into', 'over',
    'after', 'before', 'more', 'much', 'many', 'every', 'bit', 'lot',
    'time', 'thing', 'things', 'way', 'days', 'day', 'life', 'now', 'even',
    'still', 'try', 'help', 'cannot', 'cant', 'dont', 'wont', 'couldnt',
    'shouldnt', 'wouldnt', 'ive', 'im', 'theyre', 'theres', 'whats',
  };

  /// Simple suffix-stripping to reduce word variants to a common root.
  String _stem(String word) {
    if (word.length < 5) return word;
    const rules = [
      // Longest first to avoid premature truncation
      ('inging', 'ing'), ('ations', 'ate'), ('nesses', ''), ('ments', ''),
      ('pping', 'p'), ('tting', 't'), ('nning', 'n'), // double-consonant+ing: skipping->skip
      ('ation', 'ate'), ('tions', 'tion'), ('ities', 'ity'), ('iness', 'y'),
      ('ness', ''), ('ment', ''), ('tion', ''), ('ings', ''), ('ing', ''),
      ('ity', ''), ('ies', 'y'), ('ped', 'p'), ('ted', 't'), ('ned', 'n'),
      ('ern', ''), ('tern', ''),
      ('ed', ''), ('er', ''), ('ly', ''),
      ('al', ''), ('ic', ''), ('es', 'e'), ('s', ''),
    ];
    for (final (suffix, replacement) in rules) {
      if (word.endsWith(suffix) && word.length - suffix.length >= 3) {
        return word.substring(0, word.length - suffix.length) + replacement;
      }
    }
    return word;
  }

  /// Builds a stable dynamic intent key from the meaningful keywords of
  /// an unmapped problem text. Stemming + alphabetical sorting ensures that
  /// reworded versions of the same topic collapse to the same key, e.g.:
  ///   "stage fright during oral presentations"
  ///   "nervousness giving presentations in class"
  ///   → both → "intent:dyn_class_nervous_oral_present_stage"
  String _dynamicIntent(String text) {
    final words = RegExp(r'[a-z]+').allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();
    final meaningful = words
        .where((w) => w.length >= 4 && !_stopwords.contains(w))
        .toList();
    final stems = meaningful.map(_stem).toSet().toList()..sort();
    final keyParts = stems.where((s) => s.length >= 3).take(5).toList();
    if (keyParts.isEmpty) return 'problem:${_normalize(text)}';
    return 'intent:dyn_${keyParts.join('_')}';
  }

  // -----------------------------------------------------------------
  //   1️⃣ Analyse free‑text problem
  // -----------------------------------------------------------------
  /// Calls `/analyze-problem` on the backend.
  /// Returns a map that contains at least:
  ///   `id`, `title`, `subtitle`, `icon`, `causes`, `summary`.
  Future<Map<String, dynamic>> analyseProblem(String rawProblem) async {
    final uri = Uri.parse('$_baseUrl/analyze-problem');
    final intentKey = _classifyProblemIntent(rawProblem);
    final cacheKey = _cacheKey('analyseProblem', {'intent': intentKey});

    // 1. Semantic intent cache match.
    final cached = await _getCached(cacheKey, _problemCacheTtl);
    if (cached != null) {
      debugPrint(
          '[AiService] Returning cached analyseProblem data (intent match: $intentKey)');
      return cached;
    }

    // 2. Fuzzy match against previously-seen problem text on this device —
    // students rarely phrase the exact same problem identically twice.
    final normalized = _normalize(rawProblem);
    final fuzzy =
        await _getCachedFuzzy('analyseProblem', normalized, _problemCacheTtl);
    if (fuzzy != null) {
      debugPrint(
          '[AiService] Returning cached analyseProblem data (fuzzy match)');
      return fuzzy;
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'problem': rawProblem}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (payload.containsKey('causes') && payload.containsKey('summary')) {
          await _setCached(cacheKey, payload);
          return payload;
        }
      } else {
        debugPrint(
            '[AiService] /analyze-problem returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[AiService] /analyze-problem failed: $e');
    }
    // fallback
    debugPrint('[AiService] Falling back to safe problem analysis data.');
    return {
      'id': 'focus_and_energy_reclaim',
      'title': 'Focus & Energy Reclaim',
      'subtitle': 'Overcoming distraction and rebuilding study momentum',
      'icon': '⚡',
      'causes': [
        'High evening screen time exposure',
        'Irregular sleep and recharge cycles',
        'Decision fatigue when starting tasks',
        'Dopamine burnout from social feeds',
        'Unstructured study environments'
      ],
      'summary':
          'You are experiencing focus fragmentation caused by digital fatigue. '
              'By restructuring your evening shutdown and study sprints, you can reclaim your mental momentum.'
    };
  }

  // -----------------------------------------------------------------
  //   2️⃣ Generate quiz questions
  // -----------------------------------------------------------------
  /// Calls `/generate-quiz` on the backend.
  /// Returns a map with a `questions` list.
  Future<Map<String, dynamic>> generateQuizQuestions({
    required String problemTitle,
    required List<String> causes,
    String problemSummary = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/generate-quiz');
    // Sort + normalize causes so option order never creates a spurious miss.
    final sortedCauses = causes.map(_normalize).toList()..sort();
    final cacheKey = _cacheKey('generateQuiz', {
      'problem_title': _normalize(problemTitle),
      'causes': sortedCauses,
    });
    final cached = await _getCached(cacheKey, _quizCacheTtl);
    if (cached != null) {
      debugPrint('[AiService] Returning cached quiz data');
      return cached;
    }
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'problem_title': problemTitle,
              'causes': causes,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (payload.containsKey('questions')) {
          await _setCached(cacheKey, payload);
          return payload;
        }
      } else {
        debugPrint(
            '[AiService] /generate-quiz returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[AiService] /generate-quiz failed: $e');
    }
    // fallback
    debugPrint('[AiService] Falling back to safe quiz data.');
    return {
      'questions': [
        {
          'question': 'When do you feel most distracted during the day?',
          'options': [
            'Late night before bed',
            'Right after waking up',
            'During study sessions',
            'In the late afternoon'
          ]
        },
        {
          'question': 'How often do you check your phone while studying?',
          'options': [
            'Every 5‑10 minutes',
            'Every 30 minutes',
            'Once an hour',
            'Only when taking a break'
          ]
        },
        {
          'question': 'What is your main barrier to starting a task?',
          'options': [
            'Feeling overwhelmed by size',
            'Lack of energy/sleepiness',
            'Digital notifications',
            'Unclear priorities'
          ]
        },
        {
          'question': 'How many hours of sleep do you average per night?',
          'options': [
            'Less than 5 hours',
            '5 to 6 hours',
            '6 to 7 hours',
            '8+ hours'
          ]
        },
        {
          'question': 'How do you feel after a long screen‑time session?',
          'options': [
            'Brain fog & exhausted',
            'Anxious or restless',
            'Neutral',
            'Motivated'
          ]
        },
      ]
    };
  }

  // -----------------------------------------------------------------
  //   3️⃣ Generate RPG‑style quests (main flow)
  // -----------------------------------------------------------------
  /// Calls `/analyze` on the backend – this is the **single source of truth**
  /// for the full quest payload.
  Future<Map<String, dynamic>> generateQuests({
    required String playerName,
    required String schedule,
    required String problemTitle,
    required String problemSubtitle,
    required List<String> selectedCauses,
    required List<String> quizAnswers,
    required double sleepHours,
    required double studyHours,
    required double screenTimeHours,
    required int stressLevel,
    required double physicalActivityHours,
    required double socialHours,
    required double gpa,
    required String emotion,
  }) async {
    final uri = Uri.parse('$_baseUrl/analyze');
    // NOTE: playerName is deliberately excluded from the cache key. It's
    // flavor text only (the backend prompt no longer even sends it to
    // Gemini) — including it here would make every request unique per
    // student and defeat caching entirely.
    // Continuous stats are bucketed so similar (not just identical)
    // profiles share a cache entry, mirroring the backend's own bucketing.
    final cacheKey = _cacheKey('generateQuests', {
      'schedule': _normalize(schedule),
      'problem_title': _normalize(problemTitle),
      'problem_subtitle': _normalize(problemSubtitle),
      'selected_causes': (selectedCauses.map(_normalize).toList()..sort()),
      'quiz_answers': quizAnswers.map(_normalize).toList(),
      'sleep_hours': _bucket(sleepHours, 1.0),
      'study_hours': _bucket(studyHours, 1.0),
      'screen_time_hours': _bucket(screenTimeHours, 1.0),
      'stress_level': stressLevel,
      'physical_activity_hours': _bucket(physicalActivityHours, 1.0),
      'social_hours': _bucket(socialHours, 1.0),
      'gpa': _bucket(gpa, 0.5),
      'emotion': _normalize(emotion),
    });
    final cached = await _getCached(cacheKey, _questCacheTtl);
    if (cached != null) {
      debugPrint('[AiService] Returning cached quest data');
      return cached;
    }
    debugPrint('[AiService] Sending quest request to $uri');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'player_name': playerName,
              'schedule': schedule,
              'problem_title': problemTitle,
              'problem_subtitle': problemSubtitle,
              'selected_causes': selectedCauses,
              'quiz_answers': quizAnswers,
              'sleep_hours': sleepHours,
              'study_hours': studyHours,
              'screen_time_hours': screenTimeHours,
              'stress_level': stressLevel,
              'physical_activity_hours': physicalActivityHours,
              'social_hours': socialHours,
              'gpa': gpa,
              'emotion': emotion,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (payload.containsKey('daily') && payload.containsKey('weekly')) {
          debugPrint('[AiService] Backend quest generation succeeded.');
          await _setCached(cacheKey, payload);
          return payload;
        } else {
          debugPrint(
              '[AiService] Backend response missing daily/weekly fields.');
        }
      } else {
        debugPrint('[AiService] /analyze returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[AiService] /analyze request failed: $e');
    }
    // fallback
    debugPrint('[AiService] Falling back to static quest data.');
    return {
      "primary_problem": "⚔️ Chrono‑Drain & Screen‑Curse Debuff",
      "root_cause": "Nocturnal Screen Exposure & Low Sleep Mana",
      "reasoning":
          "Your energy core is experiencing high screen‑radiation drain before sleep, lowering your focus aura during daylight raids. Executing these tactical quests will cleanse digital toxins and boost your daily XP multiplier.",
      "daily": [
        {
          "title": "⚡ Operation Midnight Blackout: Sever Screen Signal",
          "xp": 25,
          "category": "health",
          "why":
              "Cleanses blue‑light poison 1hr before sleep to fully recharge Mana and HP."
        },
        {
          "title": "⚔️ Deep Work Crusade: 25‑Min Focus Sprint",
          "xp": 30,
          "category": "focus",
          "why":
              "Engages tactical focus mode to slay the Procrastination Specter without distraction."
        },
        {
          "title": "🧪 Elixir of Vitality: Hydrate & 10‑Min Outdoor Patrol",
          "xp": 20,
          "category": "health",
          "why": "Restores baseline stamina and clears midday mental fog."
        },
        {
          "title": "📜 Master Strategy: Map Tomorrow's 3 Boss Objectives",
          "xp": 20,
          "category": "discipline",
          "why":
              "Eliminates morning decision fatigue for an instant activation energy bonus."
        },
        {
          "title": "🛡️ Guild Connection: Phone‑Free Social Raid",
          "xp": 25,
          "category": "social",
          "why":
              "Replaces synthetic digital dopamine with real guildmate camaraderie."
        }
      ],
      "weekly": [
        {
          "title": "👑 Fortress of Sleep: 7+ Hours Sleep for 4 Nights",
          "xp": 80,
          "category": "health",
          "why":
              "Fortifies baseline focus aura and permanently boosts daily energy caps."
        },
        {
          "title": "🏆 Deep Work Paragon: Complete 5 Tactical Focus Raids",
          "xp": 100,
          "category": "focus",
          "why":
              "Conquers major academic dungeons and secures massive XP rewards."
        },
        {
          "title": "🔍 Time‑Crystal Audit: Review Screen‑Time Drain",
          "xp": 60,
          "category": "discipline",
          "why": "Grants high‑level meta‑awareness to seal time sinks."
        }
      ]
    };
  }

  // -----------------------------------------------------------------
  //   Cache helpers and fuzzy matching
  // -----------------------------------------------------------------
  static const double _fuzzyThreshold = 0.85;

  /// Generates a deterministic cache key from a prefix and parameters.
  String _cacheKey(String prefix, Map<String, dynamic> params) {
    final encoded = jsonEncode(params);
    return '${prefix}_<$encoded>';
  }

  /// Retrieves a cached payload for the exact key, honoring [ttl].
  /// Expired entries are deleted and treated as a miss.
  Future<Map<String, dynamic>?> _getCached(String key, Duration ttl) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;

    final envelope = jsonDecode(jsonString) as Map<String, dynamic>;
    final cachedAtRaw = envelope['_cachedAt'] as String?;
    final cachedAt =
        cachedAtRaw != null ? DateTime.tryParse(cachedAtRaw) : null;
    if (cachedAt == null || DateTime.now().difference(cachedAt) > ttl) {
      await prefs.remove(key);
      return null;
    }
    return envelope['payload'] as Map<String, dynamic>;
  }

  /// Stores a payload in the cache under the given key, timestamped for TTL checks.
  Future<void> _setCached(String key, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final envelope = {
      '_cachedAt': DateTime.now().toIso8601String(),
      'payload': payload,
    };
    await prefs.setString(key, jsonEncode(envelope));
  }

  /// Fuzzy cache lookup for `analyseProblem`: compares [normalizedQuery]
  /// against the normalized problem text embedded in every cached key under
  /// [prefix], and returns the first payload above [_fuzzyThreshold] that
  /// hasn't expired against [ttl].
  Future<Map<String, dynamic>?> _getCachedFuzzy(
    String prefix,
    String normalizedQuery,
    Duration ttl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('${prefix}_<'));

    for (final key in keys) {
      // Key shape: "prefix_<{"problem":"normalized text"}>"
      final start = key.indexOf('<');
      final end = key.lastIndexOf('>');
      if (start == -1 || end == -1 || end <= start) continue;
      final paramsJson = key.substring(start + 1, end);
      try {
        final storedParams = jsonDecode(paramsJson) as Map<String, dynamic>;
        final storedProblem = storedParams['problem'] as String?;
        if (storedProblem == null) continue;

        final similarity =
            StringSimilarity.compareTwoStrings(storedProblem, normalizedQuery);
        if (similarity >= _fuzzyThreshold) {
          final cached = await _getCached(key, ttl);
          if (cached != null) return cached;
        }
      } catch (_) {
        // ignore malformed keys
      }
    }
    return null;
  }
}
