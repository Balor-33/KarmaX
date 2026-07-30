import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/player_profile_service.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import 'dashboard_screen.dart';

class GoalInputScreen extends StatefulWidget {
  final String playerName;
  final String profession;
  final String schedule;

  const GoalInputScreen({
    super.key,
    required this.playerName,
    required this.profession,
    required this.schedule,
  });

  @override
  State<GoalInputScreen> createState() => _GoalInputScreenState();
}

class _GoalInputScreenState extends State<GoalInputScreen>
    with SingleTickerProviderStateMixin {
  final _goalCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  String? _selectedGoalTag;
  bool _isAnalyzing = false;

  final List<Map<String, String>> _goalTags = [
    {'label': 'Get Fit', 'icon': '🏃'},
    {'label': 'Study Daily', 'icon': '📚'},
    {'label': 'Switch Careers', 'icon': '💼'},
    {'label': 'Build Habits', 'icon': '⚡'},
    {'label': 'Earn More', 'icon': '💰'},
    {'label': 'Improve Sleep', 'icon': '🌙'},
  ];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _problemCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_goalCtrl.text.isEmpty && _selectedGoalTag == null) return;
    setState(() => _isAnalyzing = true);

    await Future.delayed(const Duration(milliseconds: 2800));

    if (mounted) {
      final goal = _selectedGoalTag ?? _goalCtrl.text.trim();
      await PlayerProfileService().saveGoal(goal);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => DashboardScreen(
            playerName: widget.playerName,
            goal: goal,
            profession: widget.profession,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(width: 2, height: 40, color: AppTheme.text100),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WELCOME, ${widget.playerName}',
                          style: AppTheme.monoFont(
                            size: 11,
                            color: AppTheme.text200,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const GlitchText(
                          text: 'SET YOUR QUEST',
                          fontSize: 22,
                          useDisplay: true,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                Text(
                  '// SELECT GOAL OR TYPE BELOW',
                  style: AppTheme.monoFont(
                    size: 10,
                    color: AppTheme.text400,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _goalTags.map((tag) {
                    final selected = _selectedGoalTag == tag['label'];
                    return GestureDetector(
                      onTap: () => setState(
                        () => _selectedGoalTag = selected ? null : tag['label'],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.copper : AppTheme.bg800,
                          border: Border.all(
                            color: selected
                                ? AppTheme.text100
                                : AppTheme.borderDim,
                          ),
                        ),
                        child: Text(
                          '${tag['icon']} ${tag['label']}',
                          style: AppTheme.monoFont(
                            size: 12,
                            color: selected ? AppTheme.bg900 : AppTheme.text100,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                Text(
                  'DEFINE YOUR GOAL',
                  style: AppTheme.monoFont(
                    size: 10,
                    color: AppTheme.text400,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  _goalCtrl,
                  'e.g. I want to build muscle and stay consistent...',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                Text(
                  'WHAT STOPS YOU?',
                  style: AppTheme.monoFont(
                    size: 10,
                    color: AppTheme.text400,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  _problemCtrl,
                  'e.g. I procrastinate, I feel tired after work...',
                  maxLines: 2,
                ),
                const SizedBox(height: 40),

                _isAnalyzing ? _buildAnalyzing() : _buildAnalyzeButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderBright),
        color: AppTheme.bg800,
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: AppTheme.monoFont(size: 13, color: AppTheme.text100),
        cursorColor: AppTheme.text100,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.monoFont(size: 13, color: AppTheme.text400),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return GestureDetector(
      onTap: _analyze,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.copper,
          boxShadow: [
            BoxShadow(
              color: AppTheme.text100.withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'RUN AI ANALYSIS',
            style: AppTheme.displayFont(size: 13, color: AppTheme.bg900),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzing() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderBright),
        color: AppTheme.bg800,
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Opacity(
              opacity: _pulse.value,
              child: Text(
                '> ANALYZING YOUR KARMA PATTERN...',
                style: AppTheme.monoFont(
                  size: 11,
                  color: AppTheme.copper,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.bg700,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.text100),
            ),
          ),
        ],
      ),
    );
  }
}
