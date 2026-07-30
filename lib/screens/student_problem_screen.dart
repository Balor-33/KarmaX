import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/hci_mode.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import '../widgets/hci_condition_toggle.dart';
import '../services/ai_service.dart';
import 'student_cause_screen.dart';

class StudentProblem {
  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final List<String> causes;
  final String summary;

  const StudentProblem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.causes,
    this.summary = '',
  });

  factory StudentProblem.fromAi(Map<String, dynamic> json) {
    return StudentProblem(
      id: json['id'] as String? ?? 'custom_problem',
      icon: json['icon'] as String? ?? '⚡',
      title: json['title'] as String? ?? 'My Challenge',
      subtitle: json['subtitle'] as String? ?? '',
      causes: (json['causes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      summary: json['summary'] as String? ?? '',
    );
  }
}

class StudentProblemScreen extends StatefulWidget {
  final String playerName;
  final String schedule;

  const StudentProblemScreen({super.key, required this.playerName, required this.schedule});

  @override
  State<StudentProblemScreen> createState() => _StudentProblemScreenState();
}

class _StudentProblemScreenState extends State<StudentProblemScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  bool _isAnalysing = false;
  String? _errorMsg;
  StudentProblem? _analysedProblem;
  int _loadStep = 0;

  final List<String> _loadLines = [
    '> SCANNING YOUR INPUT...',
    '> RUNNING AI DIAGNOSIS...',
    '> MAPPING ROOT CAUSES...',
  ];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _focusNode.addListener(() => setState(() {}));
    _inputCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    final text = _inputCtrl.text.trim();
    if (text.length < 20) {
      setState(() => _errorMsg = 'Please describe your problem in at least a few words.');
      return;
    }
    _focusNode.unfocus();
    setState(() { _isAnalysing = true; _errorMsg = null; _analysedProblem = null; _loadStep = 0; });
    _animateLoadSteps();
    try {
      final result = await AiService().analyseProblem(text);
      final problem = StudentProblem.fromAi(result);
      if (mounted) setState(() { _analysedProblem = problem; _isAnalysing = false; });
    } catch (e) {
      if (mounted) setState(() { _isAnalysing = false; _errorMsg = 'Analysis failed. Check your connection.\n$e'; });
    }
  }

  void _animateLoadSteps() async {
    for (int i = 0; i < _loadLines.length; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted && _isAnalysing) setState(() => _loadStep = i + 1);
    }
  }

  void _proceed() {
    if (_analysedProblem == null) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => StudentCauseScreen(
        playerName: widget.playerName,
        schedule: widget.schedule,
        problem: _analysedProblem!,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HciMode.instance.useGestalt ? _buildGestalt() : _buildBaseline(),
        const Positioned(
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
      resizeToAvoidBottomInset: true,
      body: ScanlineOverlay(
        child: SafeArea(
          child: Column(children: [
            FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('// STUDENT MODE ACTIVATED',
                      style: AppTheme.monoFont(size: 10, color: AppTheme.mana, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  const GlitchText(text: 'DESCRIBE\nYOUR BATTLE', fontSize: 28, useDisplay: true),
                  const SizedBox(height: 8),
                  Text('Type your main struggle as a student in your own words.\nKarmaX AI will analyse it and build your quest path.',
                      style: AppTheme.monoFont(size: 12, color: AppTheme.text200)),
                  const SizedBox(height: 20),
                  Container(height: 1, color: AppTheme.borderDim),
                ]),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('> WHAT IS YOUR BIGGEST STUDENT PROBLEM RIGHT NOW?',
                      style: AppTheme.monoFont(size: 10, color: AppTheme.mana, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bg800,
                      border: Border.all(color: _focusNode.hasFocus ? AppTheme.mana : AppTheme.borderDim,
                          width: _focusNode.hasFocus ? 1.5 : 1),
                    ),
                    child: TextField(
                      controller: _inputCtrl, focusNode: _focusNode,
                      maxLines: 6, minLines: 4,
                      style: AppTheme.monoFont(size: 13, color: AppTheme.text100),
                      cursorColor: AppTheme.mana,
                      decoration: InputDecoration(
                        hintText: 'e.g. "I keep procrastinating on assignments until the last night..."',
                        hintStyle: AppTheme.monoFont(size: 12, color: AppTheme.text600),
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight,
                      child: Text('${_inputCtrl.text.length} chars',
                          style: AppTheme.monoFont(size: 10, color: AppTheme.text600))),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.bg800, border: Border.all(color: AppTheme.danger)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMsg!, style: AppTheme.monoFont(size: 11, color: AppTheme.danger))),
                      ]),
                    ),
                  ],
                  if (_isAnalysing) ...[const SizedBox(height: 24), _baselineLoadingCard()],
                  if (_analysedProblem != null && !_isAnalysing) ...[
                    const SizedBox(height: 24), _buildResultCard(_analysedProblem!),
                  ],
                  const SizedBox(height: 100),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(children: [
                if (_analysedProblem == null && !_isAnalysing)
                  GestureDetector(
                    onTap: _inputCtrl.text.trim().length >= 20 ? _analyse : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: _inputCtrl.text.trim().length >= 20 ? AppTheme.mana : AppTheme.bg700,
                        border: Border.all(color: _inputCtrl.text.trim().length >= 20 ? AppTheme.mana : AppTheme.borderDim),
                      ),
                      child: Center(child: Text('⚡  ANALYSE WITH AI',
                          style: AppTheme.displayFont(size: 12,
                              color: _inputCtrl.text.trim().length >= 20 ? AppTheme.bg900 : AppTheme.text400))),
                    ),
                  ),
                if (_analysedProblem != null && !_isAnalysing) ...[
                  GestureDetector(
                    onTap: _proceed,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(color: AppTheme.copper),
                      child: Center(child: Text('INSPECT ROOT CAUSES  >', style: AppTheme.displayFont(size: 12, color: AppTheme.bg900))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() { _analysedProblem = null; _errorMsg = null; }),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(border: Border.all(color: AppTheme.borderBright), color: AppTheme.bg800),
                      child: Center(child: Text('RE-ANALYSE  ↺', style: AppTheme.monoFont(size: 12, color: AppTheme.text200))),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _baselineLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bg800, border: Border.all(color: AppTheme.borderBright)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.mana))),
          const SizedBox(width: 12),
          Text('GEMINI AI ANALYSING...', style: AppTheme.monoFont(size: 11, color: AppTheme.mana)),
        ]),
        const SizedBox(height: 16),
        ..._loadLines.asMap().entries.map((e) => AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: _loadStep > e.key ? 1.0 : 0.2,
          child: Padding(padding: const EdgeInsets.only(bottom: 6),
              child: Text(e.value, style: AppTheme.monoFont(size: 11, color: AppTheme.mana))),
        )),
      ]),
    );
  }

  Widget _buildResultCard(StudentProblem p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppTheme.bg800, border: Border.all(color: AppTheme.mana, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(p.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title.toUpperCase(), style: AppTheme.displayFont(size: 14, color: AppTheme.mana)),
            if (p.subtitle.isNotEmpty) ...[const SizedBox(height: 3),
              Text(p.subtitle, style: AppTheme.monoFont(size: 11, color: AppTheme.text400))],
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.mana), color: AppTheme.mana.withValues(alpha: 0.08)),
            child: Text('AI SCAN', style: AppTheme.monoFont(size: 9, color: AppTheme.mana))),
        ]),
        if (p.summary.isNotEmpty) ...[
          const SizedBox(height: 14), Container(height: 1, color: AppTheme.borderDim), const SizedBox(height: 12),
          Text('> AI ANALYSIS', style: AppTheme.monoFont(size: 9, color: AppTheme.text400, letterSpacing: 2)),
          const SizedBox(height: 6),
          Text(p.summary, style: AppTheme.monoFont(size: 12, color: AppTheme.text200)),
        ],
        if (p.causes.isNotEmpty) ...[
          const SizedBox(height: 14), Container(height: 1, color: AppTheme.borderDim), const SizedBox(height: 12),
          Text('> DETECTED ROOT CAUSES (${p.causes.length})', style: AppTheme.monoFont(size: 9, color: AppTheme.text400, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...p.causes.map((c) => Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('◆ ', style: AppTheme.monoFont(size: 10, color: AppTheme.copper)),
              Expanded(child: Text(c, style: AppTheme.monoFont(size: 12, color: AppTheme.text100))),
            ]))),
        ],
      ]),
    );
  }

  Widget _buildGestalt() {
    final hasEnough = _inputCtrl.text.trim().length >= 20;
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      resizeToAvoidBottomInset: true,
      body: ScanlineOverlay(
        child: SafeArea(
          child: Column(children: [
            _gestaltStepStrip(activeStep: 0),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FadeTransition(
                    opacity: _headerFade,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('STEP 01  ·  IDENTIFY YOUR BATTLE',
                          style: AppTheme.monoFont(size: 9, color: AppTheme.mana, letterSpacing: 2)),
                      const SizedBox(height: 10),
                      const GlitchText(text: 'WHAT IS YOUR\nBIGGEST STRUGGLE?', fontSize: 26, useDisplay: true),
                      const SizedBox(height: 8),
                      Text('Be specific — the more detail you give, the more personalised your quests will be.',
                          style: AppTheme.monoFont(size: 12, color: AppTheme.text400)),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: AppTheme.bg800,
                      border: Border.all(
                        color: _focusNode.hasFocus ? AppTheme.mana : AppTheme.bg500,
                        width: _focusNode.hasFocus ? 2.0 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: _focusNode.hasFocus ? [
                        BoxShadow(color: AppTheme.mana.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: 0),
                      ] : null,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Text('YOUR PROBLEM',
                            style: AppTheme.monoFont(size: 9,
                                color: _focusNode.hasFocus ? AppTheme.mana : AppTheme.text400, letterSpacing: 2)),
                      ),
                      TextField(
                        controller: _inputCtrl, focusNode: _focusNode,
                        maxLines: 6, minLines: 4,
                        style: AppTheme.monoFont(size: 13, color: AppTheme.text100),
                        cursorColor: AppTheme.mana,
                        decoration: InputDecoration(
                          hintText: 'e.g. "I keep procrastinating on assignments until the last night and then panic. I also can\'t focus because I keep checking my phone..."',
                          hintStyle: AppTheme.monoFont(size: 12, color: AppTheme.text600),
                          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          border: InputBorder.none,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          AnimatedOpacity(
                            opacity: hasEnough ? 0 : 1, duration: const Duration(milliseconds: 300),
                            child: Text('minimum 20 characters',
                                style: AppTheme.monoFont(size: 9, color: AppTheme.text600)),
                          ),
                          Text('${_inputCtrl.text.length}',
                              style: AppTheme.monoFont(size: 10,
                                  color: hasEnough ? AppTheme.mana : AppTheme.text600)),
                        ]),
                      ),
                    ]),
                  ),
                  if (_analysedProblem == null && !_isAnalysing) ...[
                    const SizedBox(height: 20),
                    Text('COMMON EXAMPLES', style: AppTheme.monoFont(size: 9, color: AppTheme.text600, letterSpacing: 2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: ['Procrastination', 'Phone addiction', 'Poor sleep',
                        'Exam anxiety', 'No motivation', 'Can\'t focus',
                      ].map((e) => GestureDetector(
                        onTap: () {
                          _inputCtrl.text = 'I struggle with $e as a student. ';
                          _inputCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _inputCtrl.text.length));
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.bg700,
                            border: Border.all(color: AppTheme.bg500),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(e, style: AppTheme.monoFont(size: 11, color: AppTheme.text200)),
                        ),
                      )).toList(),
                    ),
                  ],
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.08),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 14),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_errorMsg!, style: AppTheme.monoFont(size: 11, color: AppTheme.danger))),
                      ]),
                    ),
                  ],
                  if (_isAnalysing) ...[const SizedBox(height: 28), _gestaltLoadingCard()],
                  if (_analysedProblem != null && !_isAnalysing) ...[
                    const SizedBox(height: 28), _gestaltResultCard(_analysedProblem!),
                  ],
                  const SizedBox(height: 120),
                ]),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: AppTheme.bg900.withValues(alpha: 0.96),
                border: const Border(top: BorderSide(color: AppTheme.borderDim, width: 1)),
              ),
              child: Column(children: [
                if (_analysedProblem == null && !_isAnalysing)
                  _gestaltPrimaryButton(label: '⚡  ANALYSE WITH AI', enabled: hasEnough, onTap: _analyse),
                if (_analysedProblem != null && !_isAnalysing) ...[
                  _gestaltPrimaryButton(label: 'INSPECT ROOT CAUSES  ›', enabled: true, onTap: _proceed),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() { _analysedProblem = null; _errorMsg = null; }),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.bg800,
                        border: Border.all(color: AppTheme.bg500),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(child: Text('RE-ANALYSE  ↺',
                          style: AppTheme.monoFont(size: 12, color: AppTheme.text400))),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _gestaltStepStrip({required int activeStep}) {
    final steps = ['DESCRIBE', 'ROOT CAUSE', 'QUIZ', 'QUESTS'];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderDim, width: 1))),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final filledStep = i ~/ 2;
            return Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 400), height: 1.5,
              color: activeStep > filledStep ? AppTheme.mana : AppTheme.bg500,
            ));
          }
          final stepIdx = i ~/ 2;
          final isDone = activeStep > stepIdx;
          final isActive = activeStep == stepIdx;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppTheme.mana : AppTheme.bg700,
                border: Border.all(color: isDone || isActive ? AppTheme.mana : AppTheme.bg500, width: isActive ? 2 : 1),
              ),
              child: Center(child: isDone
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF070818))
                  : Text('${stepIdx + 1}', style: AppTheme.monoFont(size: 10,
                      color: isActive ? AppTheme.mana : AppTheme.text600))),
            ),
            const SizedBox(height: 4),
            Text(steps[stepIdx], style: AppTheme.monoFont(size: 8,
                color: isActive ? AppTheme.mana : isDone ? AppTheme.mana.withValues(alpha: 0.6) : AppTheme.text600, letterSpacing: 1)),
          ]);
        }),
      ),
    );
  }

  Widget _gestaltLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bg800,
        border: Border.all(color: AppTheme.mana.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: AppTheme.mana.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.mana))),
          const SizedBox(width: 12),
          Text('GEMINI AI ANALYSING...', style: AppTheme.monoFont(size: 11, color: AppTheme.mana)),
        ]),
        const SizedBox(height: 16),
        Row(children: List.generate(_loadLines.length, (i) => Row(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 300),
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _loadStep > i ? AppTheme.mana : AppTheme.bg500)),
          if (i < _loadLines.length - 1)
            AnimatedContainer(duration: const Duration(milliseconds: 300),
              width: 40, height: 2, margin: const EdgeInsets.symmetric(horizontal: 4),
              color: _loadStep > i + 1 ? AppTheme.mana : AppTheme.bg500),
        ]))),
        const SizedBox(height: 14),
        ..._loadLines.asMap().entries.map((e) => AnimatedOpacity(
          duration: const Duration(milliseconds: 400), opacity: _loadStep > e.key ? 1.0 : 0.15,
          child: Padding(padding: const EdgeInsets.only(bottom: 5),
              child: Text(e.value, style: AppTheme.monoFont(size: 11, color: AppTheme.mana))),
        )),
      ]),
    );
  }

  Widget _gestaltResultCard(StudentProblem p) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.mana.withValues(alpha: 0.08), AppTheme.bg800]),
        border: Border.all(color: AppTheme.mana, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: AppTheme.mana.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Text(p.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title.toUpperCase(), style: AppTheme.displayFont(size: 14, color: AppTheme.mana)),
              if (p.subtitle.isNotEmpty) ...[const SizedBox(height: 3),
                Text(p.subtitle, style: AppTheme.monoFont(size: 11, color: AppTheme.text400))],
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.mana.withValues(alpha: 0.12),
                border: Border.all(color: AppTheme.mana.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('AI SCAN', style: AppTheme.monoFont(size: 9, color: AppTheme.mana)),
            ),
          ]),
        ),
        if (p.summary.isNotEmpty) ...[
          Container(height: 1, color: AppTheme.borderDim),
          Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('> AI ANALYSIS', style: AppTheme.monoFont(size: 9, color: AppTheme.text400, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(p.summary, style: AppTheme.monoFont(size: 12, color: AppTheme.text200)),
          ])),
        ],
        if (p.causes.isNotEmpty) ...[
          Container(height: 1, color: AppTheme.borderDim),
          Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('> DETECTED ROOT CAUSES (${p.causes.length})',
                style: AppTheme.monoFont(size: 9, color: AppTheme.text400, letterSpacing: 2)),
            const SizedBox(height: 10),
            ...p.causes.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bg700, border: Border.all(color: AppTheme.bg500),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('◆ ', style: AppTheme.monoFont(size: 10, color: AppTheme.copper)),
                Expanded(child: Text(c, style: AppTheme.monoFont(size: 12, color: AppTheme.text100))),
              ]),
            )),
          ])),
        ],
      ]),
    );
  }

  Widget _gestaltPrimaryButton({required String label, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.mana : AppTheme.bg700,
          borderRadius: BorderRadius.circular(4),
          boxShadow: enabled ? [BoxShadow(color: AppTheme.mana.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 6))] : null,
        ),
        child: Center(child: Text(label,
            style: AppTheme.displayFont(size: 12, color: enabled ? AppTheme.bg900 : AppTheme.text400))),
      ),
    );
  }
}
