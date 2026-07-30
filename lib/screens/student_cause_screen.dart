import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import 'student_problem_screen.dart';
import 'student_state_screen.dart';

class StudentCauseScreen extends StatefulWidget {
  final String playerName;
  final String schedule;
  final StudentProblem problem;

  const StudentCauseScreen({
    super.key,
    required this.playerName,
    required this.schedule,
    required this.problem,
  });

  @override
  State<StudentCauseScreen> createState() => _StudentCauseScreenState();
}

class _StudentCauseScreenState extends State<StudentCauseScreen>
    with SingleTickerProviderStateMixin {
  final Set<int> _selectedCauses = {};
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_selectedCauses.isEmpty) return;
    final causes = _selectedCauses
        .map((i) => widget.problem.causes[i])
        .toList();

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StudentStateScreen(
          playerName: widget.playerName,
          schedule: widget.schedule,
          problem: widget.problem,
          selectedCauses: causes,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;

    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
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
                            Text(
                              'BACK',
                              style: AppTheme.monoFont(
                                  size: 10, color: AppTheme.text400),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: AppTheme.borderBright),
                              color: AppTheme.bg800,
                            ),
                            child: Text(
                              '${p.icon}  ${p.title.toUpperCase()}',
                              style: AppTheme.monoFont(
                                  size: 11, color: AppTheme.mana),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const GlitchText(
                        text: 'ROOT CAUSE\nINSPECTION',
                        fontSize: 26,
                        useDisplay: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select ALL causes that resonate with you.\nMore precision = better quests.',
                        style: AppTheme.monoFont(
                            size: 12, color: AppTheme.text200),
                      ),
                      const SizedBox(height: 20),
                      Container(height: 1, color: AppTheme.borderDim),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    itemCount: p.causes.length,
                    itemBuilder: (ctx, i) {
                      final selected = _selectedCauses.contains(i);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedCauses.remove(i);
                          } else {
                            _selectedCauses.add(i);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.only(top: 1),
                                decoration: BoxDecoration(
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
                                child: selected
                                    ? const Icon(Icons.check,
                                        size: 12,
                                        color: AppTheme.bg900)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  p.causes[i],
                                  style: AppTheme.monoFont(
                                    size: 13,
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
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedCauses.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '> ${_selectedCauses.length} CAUSE${_selectedCauses.length > 1 ? 'S' : ''} IDENTIFIED',
                            style: AppTheme.monoFont(
                                size: 10, color: AppTheme.mana),
                          ),
                        ),
                      GestureDetector(
                        onTap: _selectedCauses.isNotEmpty ? _proceed : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: _selectedCauses.isNotEmpty
                                ? AppTheme.copper
                                : AppTheme.bg700,
                            border: Border.all(
                              color: _selectedCauses.isNotEmpty
                                  ? AppTheme.copper
                                  : AppTheme.borderDim,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _selectedCauses.isNotEmpty
                                  ? 'PROCEED TO QUIZ  >'
                                  : 'SELECT AT LEAST ONE CAUSE',
                              style: AppTheme.displayFont(
                                size: 12,
                                color: _selectedCauses.isNotEmpty
                                    ? AppTheme.bg900
                                    : AppTheme.text400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
