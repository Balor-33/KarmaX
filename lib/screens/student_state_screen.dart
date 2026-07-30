import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import '../utils/student_state.dart';
import 'student_problem_screen.dart';
import 'student_quiz_screen.dart';

class StudentStateScreen extends StatefulWidget {
  final String playerName;
  final String schedule;
  final StudentProblem problem;
  final List<String> selectedCauses;

  const StudentStateScreen({
    super.key,
    required this.playerName,
    required this.schedule,
    required this.problem,
    required this.selectedCauses,
  });

  @override
  State<StudentStateScreen> createState() => _StudentStateScreenState();
}

class _StudentStateScreenState extends State<StudentStateScreen> {
  double _sleepHours = StudentState.instance.sleepHours;
  double _studyHours = StudentState.instance.studyHours;
  double _screenTimeHours = StudentState.instance.screenTimeHours;
  int _stressLevel = StudentState.instance.stressLevel;
  double _physicalActivityHours = StudentState.instance.physicalActivityHours;
  double _socialHours = StudentState.instance.socialHours;
  double _gpa = StudentState.instance.gpa;
  String _emotion = StudentState.instance.emotion;

  static const List<String> _emotionOptions = [
    'Happy',
    'Motivated',
    'Calm',
    'Neutral',
    'Tired',
    'Stressed',
    'Anxious',
    'Overwhelmed',
  ];

  void _proceed() {
    StudentState.instance.sleepHours = _sleepHours;
    StudentState.instance.studyHours = _studyHours;
    StudentState.instance.screenTimeHours = _screenTimeHours;
    StudentState.instance.stressLevel = _stressLevel;
    StudentState.instance.physicalActivityHours = _physicalActivityHours;
    StudentState.instance.socialHours = _socialHours;
    StudentState.instance.gpa = _gpa;
    StudentState.instance.emotion = _emotion;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StudentQuizScreen(
          playerName: widget.playerName,
          schedule: widget.schedule,
          problem: widget.problem,
          selectedCauses: widget.selectedCauses,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _slider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppTheme.monoFont(size: 12, color: AppTheme.text200)),
              Text(valueText,
                  style: AppTheme.monoFont(size: 12, color: AppTheme.mana)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.mana,
            inactiveColor: AppTheme.bg700,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios,
                              color: AppTheme.text400, size: 12),
                          const SizedBox(width: 4),
                          Text('BACK',
                              style: AppTheme.monoFont(
                                  size: 10, color: AppTheme.text400)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const GlitchText(
                      text: 'QUICK STATE\nCHECK',
                      fontSize: 26,
                      useDisplay: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Helps the AI reason from your actual routine,\nnot just the problem you described.',
                      style: AppTheme.monoFont(size: 12, color: AppTheme.text200),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _slider(
                      label: 'SLEEP (hrs/night)',
                      valueText: _sleepHours.toStringAsFixed(1),
                      value: _sleepHours,
                      min: 0,
                      max: 12,
                      divisions: 24,
                      onChanged: (v) => setState(() => _sleepHours = v),
                    ),
                    _slider(
                      label: 'STUDY (hrs/day)',
                      valueText: _studyHours.toStringAsFixed(1),
                      value: _studyHours,
                      min: 0,
                      max: 12,
                      divisions: 24,
                      onChanged: (v) => setState(() => _studyHours = v),
                    ),
                    _slider(
                      label: 'SCREEN TIME (hrs/day)',
                      valueText: _screenTimeHours.toStringAsFixed(1),
                      value: _screenTimeHours,
                      min: 0,
                      max: 12,
                      divisions: 24,
                      onChanged: (v) => setState(() => _screenTimeHours = v),
                    ),
                    _slider(
                      label: 'STRESS LEVEL (1-5)',
                      valueText: '$_stressLevel',
                      value: _stressLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (v) => setState(() => _stressLevel = v.round()),
                    ),
                    _slider(
                      label: 'PHYSICAL ACTIVITY (hrs/day)',
                      valueText: _physicalActivityHours.toStringAsFixed(1),
                      value: _physicalActivityHours,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      onChanged: (v) =>
                          setState(() => _physicalActivityHours = v),
                    ),
                    _slider(
                      label: 'SOCIAL TIME (hrs/day)',
                      valueText: _socialHours.toStringAsFixed(1),
                      value: _socialHours,
                      min: 0,
                      max: 8,
                      divisions: 16,
                      onChanged: (v) => setState(() => _socialHours = v),
                    ),
                    _slider(
                      label: 'GPA (0.0 - 4.0)',
                      valueText: _gpa.toStringAsFixed(1),
                      value: _gpa,
                      min: 0,
                      max: 4,
                      divisions: 40,
                      onChanged: (v) => setState(() => _gpa = v),
                    ),
                    const SizedBox(height: 4),
                    Text('CURRENT MOOD',
                        style: AppTheme.monoFont(
                            size: 12, color: AppTheme.text200)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _emotionOptions.map((e) {
                        final selected = _emotion == e;
                        return GestureDetector(
                          onTap: () => setState(() => _emotion = e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.mana.withValues(alpha: 0.15)
                                  : AppTheme.bg800,
                              border: Border.all(
                                color:
                                    selected ? AppTheme.mana : AppTheme.borderDim,
                              ),
                            ),
                            child: Text(
                              e,
                              style: AppTheme.monoFont(
                                size: 11,
                                color:
                                    selected ? AppTheme.mana : AppTheme.text400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: GestureDetector(
                  onTap: _proceed,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: const BoxDecoration(color: AppTheme.copper),
                    child: Center(
                      child: Text(
                        'PROCEED TO QUIZ  >',
                        style:
                            AppTheme.displayFont(size: 12, color: AppTheme.bg900),
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
}
