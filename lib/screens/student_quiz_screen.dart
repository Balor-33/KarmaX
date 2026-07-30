import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/hci_mode.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import '../widgets/hci_condition_toggle.dart';
import '../services/ai_service.dart';
import '../services/hci_study_service.dart';
import 'student_problem_screen.dart';
import 'student_quest_screen.dart';
class QuizQuestion {
  final String question;
  final List<String> options;
  const QuizQuestion({required this.question, required this.options});

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class StudentQuizScreen extends StatefulWidget {
  final String playerName;
  final String schedule;
  final StudentProblem problem;
  final List<String> selectedCauses;

  const StudentQuizScreen({
    super.key,
    required this.playerName,
    required this.schedule,
    required this.problem,
    required this.selectedCauses,
  });

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────
  bool _loadingQuestions = true;
  String? _loadError;
  List<QuizQuestion> _questions = [];

  final Map<int, int> _answers = {}; // question index → option index
  int _current = 0;
  bool _quizComplete = false;

  // ── HCI study instrumentation ───────────────────────────────────────────
  // Per-question timing/revision/backtrack tracking, logged to Supabase so
  // the A/B comparison has real numbers behind it (see hci_study_service.dart).
  final Map<int, DateTime> _shownAt = {};
  final Map<int, DateTime> _answeredAt = {}; // time of FIRST answer
  final Map<int, DateTime> _lastModifiedAt = {}; // time of most recent answer change
  final Map<int, int> _revisions = {}; // answer changed while viewing this question
  final Map<int, int> _backtracks = {}; // times re-shown after navigating back via Previous

  // ── Loading animation ──────────────────────────────────────────────────
  int _loadStep = 0;
  final List<String> _loadLines = [
    '> READING YOUR PROBLEM...',
    '> GENERATING CUSTOM QUIZ...',
    '> CALIBRATING QUESTIONS...',
  ];

  // ── Animations ─────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // Start a fresh HCI study session: randomizes A/B (unless locked by a
    // manual demo toggle) and generates a session id used to group every
    // logged event for this quiz attempt.
    HciMode.instance.startNewSession();
    HciStudyService().startSession(problemTitle: widget.problem.title);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _progressAnim =
        Tween<double>(begin: 0, end: 0).animate(_progressCtrl);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(_pulseCtrl);

    _fetchQuestions();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Fetch AI quiz questions ────────────────────────────────────────────
  Future<void> _fetchQuestions() async {
    setState(() {
      _loadingQuestions = true;
      _loadError = null;
      _loadStep = 0;
    });
    _animateLoadSteps();

    try {
      final result = await AiService().generateQuizQuestions(
        problemTitle: widget.problem.title,
        causes: widget.selectedCauses, problemSummary: '',
      );

      final rawList = result['questions'] as List<dynamic>;
      final questions = rawList
          .map((e) =>
              QuizQuestion.fromJson(e as Map<String, dynamic>))
          .where((q) => q.question.isNotEmpty && q.options.length == 4)
          .toList();

      if (questions.isEmpty) throw Exception('No valid questions returned');

      if (mounted) {
        setState(() {
          _questions = questions;
          _loadingQuestions = false;
        });
        _updateProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingQuestions = false;
          _loadError = e.toString();
          // Use fallback questions if AI fails
          _questions = _fallbackQuestions();
        });
        _updateProgress();
      }
    }
  }

  void _animateLoadSteps() async {
    for (int i = 0; i < _loadLines.length; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted && _loadingQuestions) setState(() => _loadStep = i + 1);
    }
  }

  void _updateProgress() {
    if (_questions.isEmpty) return;
    _shownAt.putIfAbsent(_current, () => DateTime.now());
    _logCurrentQuestionEvent();
    final target = (_current + 1) / _questions.length;
    _progressAnim = Tween<double>(
      begin: _progressAnim.value,
      end: target,
    ).animate(
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic));
    _progressCtrl.forward(from: 0);
  }

  /// Sends the full known state of the current question (timing, chosen
  /// answer, revision/backtrack counts) to Supabase. Safe to call as often
  /// as needed — each call just refreshes the same row for this question.
  void _logCurrentQuestionEvent() {
    final idx = _current;
    final hasAnswer = _answers.containsKey(idx);
    HciStudyService().logQuestionEvent(
      questionIndex: idx,
      shownAt: _shownAt[idx] ?? DateTime.now(),
      answeredAt: _answeredAt[idx],
      lastModifiedAt: _lastModifiedAt[idx],
      revisionCount: _revisions[idx] ?? 0,
      backtrackCount: _backtracks[idx] ?? 0,
      selectedOptionIndex: hasAnswer ? _answers[idx] : null,
      answerText: hasAnswer ? _questions[idx].options[_answers[idx]!] : null,
    );
  }

  // ── Quiz navigation ────────────────────────────────────────────────────
  void _selectAnswer(int optionIndex) {
    final alreadyAnswered = _answers.containsKey(_current);
    final now = DateTime.now();
    setState(() => _answers[_current] = optionIndex);

    _lastModifiedAt[_current] = now;
    if (alreadyAnswered) {
      _revisions[_current] = (_revisions[_current] ?? 0) + 1;
    } else {
      _answeredAt[_current] = now;
    }

    _logCurrentQuestionEvent();
  }

  void _next() {
    if (_answers[_current] == null) return;
    if (_current < _questions.length - 1) {
      setState(() {
        _current++;
        _updateProgress();
      });
      _fadeCtrl
        ..reset()
        ..forward();
      _slideCtrl
        ..reset()
        ..forward();
    } else {
      setState(() => _quizComplete = true);
      HciStudyService().markQuizFinished();
    }
  }

  void _previous() {
    if (_current > 0) {
      setState(() {
        _current--;
        // Returning to an earlier question after having moved past it —
        // this is a "backtrack", tracked separately from answer revisions.
        _backtracks[_current] = (_backtracks[_current] ?? 0) + 1;
        _updateProgress();
      });
      _fadeCtrl
        ..reset()
        ..forward();
      _slideCtrl
        ..reset()
        ..forward();
    }
  }

  void _generateQuests() {
    final answerTexts = List.generate(
      _questions.length,
      (i) => _answers.containsKey(i)
          ? _questions[i].options[_answers[i]!]
          : '',
    ).where((s) => s.isNotEmpty).toList();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StudentQuestScreen(
          playerName: widget.playerName,
          schedule: widget.schedule,
          problem: widget.problem,
          selectedCauses: widget.selectedCauses,
          quizAnswers: answerTexts,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  List<QuizQuestion> _fallbackQuestions() => [
        QuizQuestion(
          question:
              'How long have you been dealing with this challenge?',
          options: [
            'Just started recently',
            'A few weeks',
            'A few months',
            'Over a year — it\'s chronic',
          ],
        ),
        QuizQuestion(
          question: 'How much is it affecting your academic performance?',
          options: [
            'Slightly — I still manage',
            'Moderately — grades are slipping',
            'A lot — I\'m struggling to keep up',
            'Completely — I\'m failing or close to it',
          ],
        ),
        QuizQuestion(
          question: 'What time of day is this problem worst?',
          options: [
            'Mornings — hard to get started',
            'Afternoons — energy crash hits',
            'Evenings — when I should be studying',
            'All day — no good hours',
          ],
        ),
        QuizQuestion(
          question:
              'Have you tried to solve this before? What happened?',
          options: [
            'Never really tried systematically',
            'Tried but gave up after a few days',
            'Made progress then relapsed',
            'Nothing I tried worked at all',
          ],
        ),
        QuizQuestion(
          question:
              'What would solving this problem change for you most?',
          options: [
            'My grades and academic performance',
            'My mental health and stress levels',
            'My daily energy and motivation',
            'My relationships and social life',
          ],
        ),
      ];

  // ─────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HciMode.instance.useGestalt ? _buildGestalt() : _buildBaseline(),
        Positioned(
          top: 76,
          right: 12,
          child: SafeArea(child: HciConditionToggle()),
        ),
      ],
    );
  }

  Widget _buildBaseline() {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: SafeArea(
          child: _loadingQuestions
              ? _buildLoading()
              : Column(
                  children: [
                    // ── TOP BAR ──
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '// AI QUIZ — ${widget.problem.title.toUpperCase()}',
                                  style: AppTheme.monoFont(
                                      size: 10,
                                      color: AppTheme.mana,
                                      letterSpacing: 2),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_quizComplete)
                                Text(
                                  '${_current + 1} / ${_questions.length}',
                                  style: AppTheme.monoFont(
                                      size: 11, color: AppTheme.text400),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Progress bar
                          if (!_quizComplete)
                            Container(
                              height: 3,
                              width: double.infinity,
                              color: AppTheme.bg600,
                              child: AnimatedBuilder(
                                animation: _progressAnim,
                                builder: (_, __) =>
                                    FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progressAnim.value,
                                  child: Container(
                                      color: AppTheme.copper),
                                ),
                              ),
                            ),
                          // AI quiz badge
                          if (!_quizComplete) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: AppTheme.mana
                                            .withValues(alpha: 0.5)),
                                    color: AppTheme.mana
                                        .withValues(alpha: 0.06),
                                  ),
                                  child: Text(
                                    '✦ AI-GENERATED FOR YOUR PROBLEM',
                                    style: AppTheme.monoFont(
                                        size: 9,
                                        color: AppTheme.mana),
                                  ),
                                ),
                                if (_loadError != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: AppTheme.copper
                                              .withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      'FALLBACK MODE',
                                      style: AppTheme.monoFont(
                                          size: 9,
                                          color: AppTheme.copper),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // ── QUESTION / COMPLETE VIEW ──
                    Expanded(
                      child: _quizComplete
                          ? _buildCompleteView()
                          : FadeTransition(
                              opacity: _fade,
                              child: _buildQuestion(),
                            ),
                    ),

                    // ── NAV BUTTONS ──
                    if (!_quizComplete)
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Row(
                          children: [
                            if (_current > 0)
                              Expanded(
                                flex: 1,
                                child: GestureDetector(
                                  onTap: _previous,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color:
                                              AppTheme.borderBright),
                                      color: AppTheme.bg800,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '<  BACK',
                                        style: AppTheme.monoFont(
                                            size: 12,
                                            color: AppTheme.text200),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_current > 0) const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: _answers[_current] != null
                                    ? _next
                                    : null,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _answers[_current] != null
                                        ? AppTheme.copper
                                        : AppTheme.bg700,
                                    border: Border.all(
                                      color: _answers[_current] != null
                                          ? AppTheme.copper
                                          : AppTheme.borderDim,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _current ==
                                              _questions.length - 1
                                          ? 'FINISH QUIZ  >'
                                          : 'NEXT  >',
                                      style: AppTheme.displayFont(
                                        size: 12,
                                        color: _answers[_current] !=
                                                null
                                            ? AppTheme.bg900
                                            : AppTheme.text400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_quizComplete)
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: GestureDetector(
                          onTap: _generateQuests,
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            decoration:
                                const BoxDecoration(color: AppTheme.copper),
                            child: Center(
                              child: Text(
                                'GENERATE MY LIFE QUESTS  ⚡',
                                style: AppTheme.displayFont(
                                    size: 13, color: AppTheme.bg900),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }


  // ══════════════════════════════════════════════════════════════════
  //  CONDITION B — GESTALT REDESIGN
  //  • Closure      — 5 progress dots show complete journey from Q1
  //  • Proximity    — question + options in ONE bounded card unit
  //  • Similarity   — all unselected options IDENTICAL style
  //  • Figure/Ground — selected option glows/rises; nav fully separated
  // ══════════════════════════════════════════════════════════════════
  Widget _buildGestalt() {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: Container(
        decoration: AppTheme.scaffoldBackground(),
        child: ScanlineOverlay(
          child: SafeArea(
            child: _loadingQuestions
                ? _buildLoading()
                : Column(children: [
                    if (!_quizComplete) _gestaltProgressDots(),
                    Expanded(
                      child: _quizComplete
                          ? _gestaltCompleteView()
                          : FadeTransition(
                              opacity: _fade,
                              child: SlideTransition(position: _slideAnim, child: _gestaltQuestion()),
                            ),
                    ),
                    if (!_quizComplete) _gestaltNavBar(),
                    if (_quizComplete)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: _gestaltCtaButton('GENERATE MY LIFE QUESTS  ⚡', _generateQuests),
                      ),
                  ]),
          ),
        ),
      ),
    );
  }

  // CLOSURE — dots show the whole journey even on Q1
  Widget _gestaltProgressDots() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderDim, width: 1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('AI QUIZ  ·  ${widget.problem.title.toUpperCase()}',
              style: AppTheme.monoFont(size: 9, color: AppTheme.mana, letterSpacing: 1),
              overflow: TextOverflow.ellipsis)),
          if (_loadError != null)
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(border: Border.all(color: AppTheme.copper.withValues(alpha: 0.5))),
              child: Text('FALLBACK', style: AppTheme.monoFont(size: 8, color: AppTheme.copper))),
        ]),
        const SizedBox(height: 14),
        Row(
          children: List.generate(_questions.isEmpty ? 5 : _questions.length, (i) {
            final isDone = i < _current;
            final isActive = i == _current;
            return Expanded(child: Row(children: [
              Expanded(child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: isActive ? 10 : 8, width: isActive ? 10 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppTheme.mana : isActive ? AppTheme.copper : AppTheme.bg500,
                  boxShadow: isActive ? [BoxShadow(color: AppTheme.copper.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)] :
                             isDone  ? [BoxShadow(color: AppTheme.mana.withValues(alpha: 0.3), blurRadius: 4)] : null,
                ),
              )),
              if (i < (_questions.isEmpty ? 4 : _questions.length - 1))
                Expanded(flex: 3, child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350), height: 2,
                  color: isDone ? AppTheme.mana.withValues(alpha: 0.5) : AppTheme.bg500,
                )),
            ]));
          }),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Q.${_current + 1} of ${_questions.length}', style: AppTheme.monoFont(size: 9, color: AppTheme.text400)),
          Text('${_questions.length - _current - 1} remaining', style: AppTheme.monoFont(size: 9, color: AppTheme.text600)),
        ]),
      ]),
    );
  }

  // PROXIMITY: question + options = ONE card | SIMILARITY: options identical | FIGURE/GROUND: selected rises
  Widget _gestaltQuestion() {
    if (_questions.isEmpty) return const SizedBox.shrink();
    final q = _questions[_current];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // FIGURE — question is the clear visual figure
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppTheme.bg700, AppTheme.bg800]),
            border: Border.all(color: AppTheme.bg500),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('QUESTION ${_current + 1}', style: AppTheme.monoFont(size: 9, color: AppTheme.mana, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text(q.question, style: AppTheme.displayFont(size: 16, color: AppTheme.text100)),
          ]),
        ),
        // PROXIMITY — options in same card, zero gap from question
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bg800,
            border: Border(
              left: BorderSide(color: AppTheme.bg500),
              right: BorderSide(color: AppTheme.bg500),
              bottom: BorderSide(color: AppTheme.bg500),
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
          ),
          child: Column(
            children: q.options.asMap().entries.map((e) {
              final selected = _answers[_current] == e.key;
              final isLast = e.key == q.options.length - 1;
              return GestureDetector(
                onTap: () => _selectAnswer(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    // FIGURE/GROUND — selected rises with bg + glow
                    color: selected ? AppTheme.copper.withValues(alpha: 0.10) : Colors.transparent,
                    border: Border(
                      top: const BorderSide(color: AppTheme.borderDim, width: 1),
                      // strong left accent on selected = unmistakable figure
                      left: BorderSide(color: selected ? AppTheme.copper : Colors.transparent, width: 3),
                    ),
                    borderRadius: isLast
                        ? const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))
                        : BorderRadius.zero,
                  ),
                  child: Row(children: [
                    // SIMILARITY — all radio circles IDENTICAL until tapped
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200), width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppTheme.copper : Colors.transparent,
                        border: Border.all(color: selected ? AppTheme.copper : AppTheme.bg500, width: 2),
                        boxShadow: selected ? [BoxShadow(color: AppTheme.copper.withValues(alpha: 0.4), blurRadius: 8)] : null,
                      ),
                      child: selected ? const Icon(Icons.check, size: 11, color: Color(0xFF070818)) : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(e.value, style: AppTheme.monoFont(size: 13,
                        color: selected ? AppTheme.text100 : AppTheme.text400))),
                    if (selected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.copper.withValues(alpha: 0.15),
                          border: Border.all(color: AppTheme.copper.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('SELECTED', style: AppTheme.monoFont(size: 8, color: AppTheme.copper)),
                      ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
        if (_answers[_current] == null) ...[
          const SizedBox(height: 12),
          Text('tap an option to continue', style: AppTheme.monoFont(size: 10, color: AppTheme.text600)),
        ],
      ]),
    );
  }

  // FIGURE/GROUND — nav fully separated; CTA is the sole active figure
  Widget _gestaltNavBar() {
    final answered = _answers[_current] != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.bg900.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: AppTheme.borderDim, width: 1)),
      ),
      child: Row(children: [
        if (_current > 0) ...[
          GestureDetector(
            onTap: _previous,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.bg800, border: Border.all(color: AppTheme.bg500),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: AppTheme.text400, size: 16),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: GestureDetector(
            onTap: answered ? _next : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: answered ? AppTheme.copper : AppTheme.bg700,
                borderRadius: BorderRadius.circular(4),
                boxShadow: answered ? [BoxShadow(color: AppTheme.copper.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))] : null,
              ),
              child: Center(child: Text(
                _current == _questions.length - 1 ? 'FINISH QUIZ  ›' : 'NEXT  ›',
                style: AppTheme.displayFont(size: 12, color: answered ? AppTheme.bg900 : AppTheme.text600),
              )),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _gestaltCtaButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.copper, borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: AppTheme.copper.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Center(child: Text(label, style: AppTheme.displayFont(size: 13, color: AppTheme.bg900))),
      ),
    );
  }

  Widget _gestaltCompleteView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: List.generate(_questions.length, (i) => Expanded(child: Row(children: [
            Expanded(child: Container(width: 12, height: 12,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.mana))),
            if (i < _questions.length - 1)
              Expanded(flex: 3, child: Container(height: 2, color: AppTheme.mana.withValues(alpha: 0.5))),
          ])))),
          const SizedBox(height: 32),
          const GlitchText(text: 'ANALYSIS\nCOMPLETE', fontSize: 30, useDisplay: true),
          const SizedBox(height: 16),
          Text('All ${_questions.length} questions answered.\nYour behaviour pattern has been mapped.',
              textAlign: TextAlign.center, style: AppTheme.monoFont(size: 13, color: AppTheme.text200)),
          const SizedBox(height: 28),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.bg800,
              border: Border.all(color: AppTheme.mana.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _summaryRow('PROBLEM', widget.problem.title, AppTheme.mana),
              const SizedBox(height: 8),
              _summaryRow('CAUSES', '${widget.selectedCauses.length} identified', AppTheme.mana),
              const SizedBox(height: 8),
              _summaryRow('QUIZ', '${_questions.length}/${_questions.length} complete', AppTheme.mana),
              const SizedBox(height: 8),
              _summaryRow('ENGINE', 'GEMINI AI', AppTheme.copper),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Row(children: [
      SizedBox(width: 72, child: Text('> $label', style: AppTheme.monoFont(size: 10, color: AppTheme.text400))),
      Text(' : ', style: AppTheme.monoFont(size: 10, color: AppTheme.text600)),
      Expanded(child: Text(value, style: AppTheme.monoFont(size: 11, color: color))),
    ]);
  }

  // ── Shared loading view ─────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Opacity(
                opacity: _pulse.value,
                child:
                    const Text('🧠', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 28),
            const GlitchText(
              text: 'BUILDING YOUR\nQUIZ',
              fontSize: 26,
              useDisplay: true,
            ),
            const SizedBox(height: 10),
            Text(
              'Gemini AI is creating questions specific\nto your exact problem.',
              textAlign: TextAlign.center,
              style:
                  AppTheme.monoFont(size: 12, color: AppTheme.text400),
            ),
            const SizedBox(height: 28),
            ..._loadLines.asMap().entries.map((e) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _loadStep > e.key ? 1.0 : 0.2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      e.value,
                      style: AppTheme.monoFont(
                          size: 11, color: AppTheme.mana),
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.bg700,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.copper),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Question view ─────────────────────────────────────────────────────
  Widget _buildQuestion() {
    if (_questions.isEmpty) return const SizedBox.shrink();
    final q = _questions[_current];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q.${_current + 1}',
            style: AppTheme.monoFont(
                size: 11, color: AppTheme.text400, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Text(
            q.question,
            style: AppTheme.displayFont(size: 17, color: AppTheme.text100),
          ),
          const SizedBox(height: 28),
          ...q.options.asMap().entries.map((e) {
            final selected = _answers[_current] == e.key;
            return GestureDetector(
              onTap: () => _selectAnswer(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.copperFaint
                      : AppTheme.bg800,
                  border: Border.all(
                    color: selected
                        ? AppTheme.copper
                        : AppTheme.borderDim,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppTheme.copper
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AppTheme.copper
                              : AppTheme.borderBright,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        e.value,
                        style: AppTheme.monoFont(
                          size: 12,
                          color: selected
                              ? AppTheme.text100
                              : AppTheme.text200,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Complete view ─────────────────────────────────────────────────────
  Widget _buildCompleteView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            const GlitchText(
              text: 'ANALYSIS\nCOMPLETE',
              fontSize: 30,
              useDisplay: true,
            ),
            const SizedBox(height: 16),
            Text(
              'All ${_questions.length} AI-generated questions answered.\nYour behaviour pattern has been mapped.',
              textAlign: TextAlign.center,
              style:
                  AppTheme.monoFont(size: 13, color: AppTheme.text200),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderBright),
                color: AppTheme.bg800,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '> PROBLEM : ${widget.problem.title}',
                    style: AppTheme.monoFont(
                        size: 11, color: AppTheme.mana),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '> CAUSES  : ${widget.selectedCauses.length} identified',
                    style: AppTheme.monoFont(
                        size: 11, color: AppTheme.mana),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '> QUIZ    : ${_questions.length}/${_questions.length} complete',
                    style: AppTheme.monoFont(
                        size: 11, color: AppTheme.mana),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '> ENGINE  : GEMINI AI (FREE)',
                    style: AppTheme.monoFont(
                        size: 11, color: AppTheme.copper),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}