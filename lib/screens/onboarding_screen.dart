import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/player_profile_service.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import 'avatar_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final String? initialName;

  const OnboardingScreen({super.key, this.initialName});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final _nameCtrl = TextEditingController();
  int _selectedAge = 20;
  final String _selectedProfession = 'Student';
  String _selectedSchedule = 'Balanced';

  final List<String> _schedules = [
    'Busy (classes + part-time job)',
    'Balanced (standard student schedule)',
    'Flexible (self-paced / online study)',
    'Night Owl (study late, wake late)',
  ];

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final initialName = widget.initialName;
    if (initialName != null && initialName.trim().isNotEmpty) {
      _nameCtrl.text = initialName.trim().toUpperCase();
    }

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_currentPage < 2) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentPage++);
    } else {
      final playerName = _nameCtrl.text.isEmpty
          ? 'PLAYER_01'
          : _nameCtrl.text.trim().toUpperCase();
      await PlayerProfileService().saveComplete(
        playerName: playerName,
        profession: _selectedProfession,
        schedule: _selectedSchedule,
        goal: _selectedSchedule,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => AvatarSelectionScreen(
            playerName: playerName,
            profession: _selectedProfession,
            schedule: _selectedSchedule,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KARMAX',
                      style: AppTheme.displayFont(
                        size: 14,
                        color: AppTheme.text200,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        3,
                        (i) => Container(
                          width: i == _currentPage ? 20 : 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 4),
                          color: i == _currentPage
                              ? AppTheme.text100
                              : AppTheme.bg600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_buildPage1(), _buildPage2(), _buildPage3()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: _buildNextButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return SlideTransition(
      position: _slideAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Text(
              '// STEP 01',
              style: AppTheme.monoFont(
                size: 10,
                color: AppTheme.text400,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),
            const GlitchText(
              text: 'IDENTIFY\nYOURSELF',
              fontSize: 34,
              useDisplay: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your player identity in the KarmaX system.',
              style: AppTheme.monoFont(size: 13, color: AppTheme.text200),
            ),
            const SizedBox(height: 48),
            Text(
              'PLAYER NAME',
              style: AppTheme.monoFont(
                size: 10,
                color: AppTheme.text400,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(_nameCtrl, 'e.g. ALEX_99'),
            const SizedBox(height: 32),
            Text(
              'AGE',
              style: AppTheme.monoFont(
                size: 10,
                color: AppTheme.text400,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('$_selectedAge', style: AppTheme.displayFont(size: 32)),
                const SizedBox(width: 24),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: AppTheme.copper,
                      inactiveTrackColor: AppTheme.bg600,
                      thumbColor: AppTheme.copper,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      min: 13,
                      max: 60,
                      value: _selectedAge.toDouble(),
                      onChanged: (v) =>
                          setState(() => _selectedAge = v.round()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Text(
            '// STEP 02',
            style: AppTheme.monoFont(
              size: 10,
              color: AppTheme.text400,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          const GlitchText(
            text: 'STUDENT\nMODE',
            fontSize: 34,
            useDisplay: true,
          ),
          const SizedBox(height: 8),
          Text(
            'KarmaX is built exclusively for students.\nYour quests are tuned to academic life.',
            style: AppTheme.monoFont(size: 13, color: AppTheme.text200),
          ),
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bg800,
              border: Border.all(color: AppTheme.mana, width: 1.5),
            ),
            child: Column(
              children: [
                const Text('🎓', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(
                  'STUDENT',
                  style: AppTheme.displayFont(
                    size: 22,
                    color: AppTheme.mana,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Access: Student Problem Bank\nAccess: Root Cause Inspector\nAccess: Psych Quiz Engine\nAccess: Life Quest Generator',
                  textAlign: TextAlign.center,
                  style: AppTheme.monoFont(
                    size: 11,
                    color: AppTheme.text200,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '> SYSTEM LOCKED TO STUDENT MODE',
            style: AppTheme.monoFont(
                size: 10, color: AppTheme.copper, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Text(
            '// STEP 03',
            style: AppTheme.monoFont(
              size: 10,
              color: AppTheme.text400,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          const GlitchText(
            text: 'DAILY\nSCHEDULE',
            fontSize: 34,
            useDisplay: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Your availability determines quest timing.',
            style: AppTheme.monoFont(size: 13, color: AppTheme.text200),
          ),
          const SizedBox(height: 40),
          ..._schedules.asMap().entries.map(
            (e) => _buildSelectTile(
              label: e.value,
              selected: _selectedSchedule == e.value,
              onTap: () => setState(() => _selectedSchedule = e.value),
              index: e.key,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderBright),
        color: AppTheme.bg800,
      ),
      child: TextField(
        controller: ctrl,
        style: AppTheme.monoFont(size: 14, color: AppTheme.text100),
        cursorColor: AppTheme.text100,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.monoFont(size: 14, color: AppTheme.text400),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSelectTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required int index,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.copper : AppTheme.bg800,
          border: Border.all(
            color: selected ? AppTheme.text100 : AppTheme.borderDim,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTheme.monoFont(
                size: 13,
                color: selected ? AppTheme.bg900 : AppTheme.text100,
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 16, color: AppTheme.bg900),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: _nextPage,
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
            _currentPage == 2 ? 'ENTER THE SYSTEM' : 'CONTINUE',
            style: AppTheme.displayFont(size: 13, color: AppTheme.bg900),
          ),
        ),
      ),
    );
  }
}
