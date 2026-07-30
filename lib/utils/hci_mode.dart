import 'dart:math';
import 'package:uuid/uuid.dart';
class HciMode {
  HciMode._();
  static final HciMode instance = HciMode._();

  final Random _random = Random();
  final Uuid _uuid = const Uuid();

  /// true  → Condition B (Gestalt)
  /// false → Condition A (baseline)
  bool useGestalt = false;

  /// When true, `startNewSession()` will not randomize `useGestalt` —
  /// it keeps whatever was last set (e.g. via the manual demo toggle).
  bool lockCondition = false;

  /// True from `startNewSession()` until `endSession()`. While true,
  /// `toggle()` is a no-op — the condition cannot change mid-attempt.
  bool sessionActive = false;

  /// Id of the current quiz attempt. Null until `startNewSession()` has
  /// been called at least once (i.e. before the very first quiz screen
  /// visit in this app run).
  String? currentSessionId;

  DateTime? sessionStartedAt;

  /// Manual dev/demo toggle. Returns true if the flip actually happened,
  /// false if it was ignored because a session is currently locked — the
  /// UI can use the return value to show a "locked" cue if it wants.
  bool toggle() {
    if (sessionActive) return false;
    useGestalt = !useGestalt;
    lockCondition = true;
    return true;
  }

  /// Call this once per quiz attempt (StudentQuizScreen.initState).
  /// Randomly assigns A/B (unless locked) and starts a fresh session id,
  /// then locks the toggle for the duration of the attempt.
  void startNewSession() {
    if (!lockCondition) {
      useGestalt = _random.nextBool();
    }
    currentSessionId = _uuid.v4();
    sessionStartedAt = DateTime.now();
    sessionActive = true;
  }

  /// Call this once the attempt's data is fully logged (SUS score AND
  /// quest rating both saved). Unlocks the toggle for the next attempt.
  void endSession() {
    sessionActive = false;
  }

  /// 'A' or 'B', matching the `condition` column in `hci_sessions`.
  String get conditionLabel => useGestalt ? 'B' : 'A';
}
