import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/xp_bar.dart';
import '../widgets/quest_card.dart';
import '../widgets/scanline_overlay.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/avatar_display.dart';
import '../models/avatar.dart';
import '../models/avatar_composition.dart';
import '../models/user_avatar_progress.dart';
import '../services/avatar_service.dart';
import '../utils/avatar_affinity.dart';
import 'profile_screen.dart';
import 'student_problem_screen.dart';
import '../widgets/hci_condition_toggle.dart';
import '../utils/hci_mode.dart';
import 'splash_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String playerName;
  final String goal;
  final String profession;
  final List<Map<String, dynamic>>? dailyQuestsOverride;
  final List<Map<String, dynamic>>? weeklyQuestsOverride;

  const DashboardScreen({
    super.key,
    required this.playerName,
    required this.goal,
    required this.profession,
    this.dailyQuestsOverride,
    this.weeklyQuestsOverride,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentXP = 0;
  final int _maxXP = 500;
  int _level = 1;
  int _completedQuests = 0;
  bool _showLevelUp = false;
  int _selectedTab = 0;
  bool _loggingOut = false;

  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  Avatar? _currentAvatar;
  UserAvatarProgress? _avatarProgress;
  bool _avatarLoading = true;
  AvatarAnimationState _avatarAnimationState = AvatarAnimationState.idle;

  final Map<String, int> _stats = {
    'health': 0,
    'knowledge': 0,
    'discipline': 0,
    'social': 0,
    'focus': 0,
  };
  static const _statsPrefsKey = 'player_growth_stats';

  List<Map<String, dynamic>> _dailyQuests = [];
  List<Map<String, dynamic>> _weeklyQuests = [];

  @override
  void initState() {
    super.initState();

    HciMode.instance.endSession();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerCtrl.forward();

    if (widget.dailyQuestsOverride != null) {
      _dailyQuests =
          List<Map<String, dynamic>>.from(widget.dailyQuestsOverride!);
    }
    if (widget.weeklyQuestsOverride != null) {
      _weeklyQuests =
          List<Map<String, dynamic>>.from(widget.weeklyQuestsOverride!);
    }

    if (widget.dailyQuestsOverride == null &&
        widget.weeklyQuestsOverride == null) {
      _loadQuestsFromSupabase();
    }

    _loadAvatarData();

    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var changed = false;
      for (final key in _stats.keys) {
        final saved = prefs.getInt('$_statsPrefsKey.$key');
        if (saved != null) {
          _stats[key] = saved;
          changed = true;
        }
      }
      if (changed && mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading growth stats: $e');
    }
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _stats.entries) {
        await prefs.setInt('$_statsPrefsKey.${entry.key}', entry.value);
      }
    } catch (e) {
      debugPrint('Error saving growth stats: $e');
    }
  }

  Map<String, dynamic> _mapQuestRow(Map<String, dynamic> row) => {
        'id': row['id'],
        'title': row['title'] as String,
        'xp': (row['xp_reward'] ?? 10).toString(),
        'category': row['category'] as String,
        'completed': row['completed'] as bool? ?? false,
        'why': row['why'] as String?,
      };

  Future<void> _loadQuestsFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('quests')
          .select()
          .eq('user_id', user.id)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at');

      final daily = <Map<String, dynamic>>[];
      final weekly = <Map<String, dynamic>>[];
      for (final row in (rows as List<dynamic>)) {
        final map = row as Map<String, dynamic>;
        if (map['quest_type'] == 'daily') {
          daily.add(_mapQuestRow(map));
        } else if (map['quest_type'] == 'weekly') {
          weekly.add(_mapQuestRow(map));
        }
      }

      if (mounted) {
        setState(() {
          _dailyQuests = daily;
          _weeklyQuests = weekly;
        });
      }
    } catch (e) {
      debugPrint('Error loading quests from Supabase: $e');
    }
  }

  Future<void> _loadAvatarData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final progress = await AvatarService().getUserAvatarProgress(user.id);
        if (progress != null && mounted) {
          final avatar = await AvatarService().getAvatarById(
            progress.selectedAvatarId,
          );
          setState(() {
            _avatarProgress = progress;
            _currentAvatar = avatar;
            _level = progress.currentLevel;
            _avatarLoading = false;
          });

          // Update dominant stat based on current stats
          await AvatarService().updateDominantStat(user.id, _stats);
        } else {
          if (mounted) {
            setState(() => _avatarLoading = false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading avatar data: $e');
      if (mounted) {
        setState(() => _avatarLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  void _onQuestComplete(Map<String, dynamic> quest, {required bool isWeekly}) {
    if (quest['completed'] == true) return; // already done, ignore double-taps

    final baseXp = int.tryParse(quest['xp'] as String? ?? '0') ?? 0;
    final category = quest['category'] as String? ?? '';
    final avatarStat = _currentAvatar?.defaultStat;
    final hasAffinity = AvatarAffinity.isAffinity(avatarStat, category);
    final xp = AvatarAffinity.computeXp(baseXp, avatarStat, category);
    final bonusXp = AvatarAffinity.bonusAmount(baseXp);
    var leveledUp = false;

    setState(() {
      quest['completed'] = true;

      _currentXP += xp;
      _completedQuests++;

      final key = category.toLowerCase();
      if (_stats.containsKey(key)) {
        _stats[key] = ((_stats[key] ?? 0) + 5).clamp(0, 100).toInt();
        _saveStats();
      }

      if (_currentXP >= _maxXP) {
        _currentXP = _currentXP - _maxXP;
        _level++;
        _showLevelUp = true;
        _avatarAnimationState = AvatarAnimationState.levelUp;
        leveledUp = true;
      } else {
        _avatarAnimationState = AvatarAnimationState.acting;
        leveledUp = false;
      }
    });

    // Show affinity bonus snackbar
    if (hasAffinity && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.bg700,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _categoryColor(category).withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _categoryColor(category).withValues(alpha: 0.2),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded,
                    color: _categoryColor(category), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'AFFINITY BONUS  ',
                          style: AppTheme.monoFont(
                            size: 10,
                            color: _categoryColor(category),
                            letterSpacing: 1.5,
                          ),
                        ),
                        TextSpan(
                          text: '+$bonusXp XP earned',
                          style: AppTheme.uiFont(
                            size: 12,
                            weight: FontWeight.w700,
                            color: AppTheme.text100,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final questId = quest['id'];
    if (questId != null) {
      Supabase.instance.client
          .from('quests')
          .update({'completed': true})
          .eq('id', questId)
          .then((_) {},
              onError: (e) => debugPrint('Error saving quest completion: $e'));
    }

    _syncAvatarProgress();

    Future.delayed(Duration(milliseconds: leveledUp ? 1800 : 700), () {
      if (mounted && !_showLevelUp) {
        setState(() => _avatarAnimationState = AvatarAnimationState.idle);
      }
    });
  }

  Future<void> _syncAvatarProgress() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await AvatarService().updateLevel(user.id, _level);
        await AvatarService().updateDominantStat(user.id, _stats);

        // Check for new badges
        final newBadges = AvatarService().checkBadgesUnlocked(
          _level,
          _completedQuests,
        );
        await AvatarService().updateBadges(user.id, newBadges);

        // Reload avatar progress
        await _loadAvatarData();
      }
    } catch (e) {
      debugPrint('Error syncing avatar progress: $e');
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.borderDim),
        ),
        title: Text(
          'Log out?',
          style: AppTheme.uiFont(
            size: 16,
            weight: FontWeight.w800,
            color: AppTheme.text100,
          ),
        ),
        content: Text(
          'You can log back in anytime with your account.',
          style: AppTheme.uiFont(size: 13, color: AppTheme.text400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTheme.uiFont(size: 13, color: AppTheme.text400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log out',
                style: AppTheme.uiFont(
                  size: 13,
                  weight: FontWeight.w800,
                  color: AppTheme.copper,
                )),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }

    if (!mounted) return;
    setState(() => _loggingOut = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  void _showAvatarStatsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.only(top: 60),
          decoration: BoxDecoration(
            color: AppTheme.bg800,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: AppTheme.borderDim),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppTheme.borderDim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Avatar
                  _avatarLoading ||
                          _currentAvatar == null ||
                          _avatarProgress == null
                      ? Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderDim),
                            color: AppTheme.bg700,
                          ),
                          child: Center(
                            child: Text(
                              widget.playerName.isNotEmpty
                                  ? widget.playerName[0]
                                  : 'P',
                              style: AppTheme.displayFont(
                                size: 32,
                                color: AppTheme.text100,
                              ),
                            ),
                          ),
                        )
                      : AvatarDisplay(
                          avatar: _currentAvatar!,
                          progress: _avatarProgress!,
                          size: 96,
                          showBadges: true,
                          animationState: AvatarAnimationState.idle,
                        ),

                  const SizedBox(height: 14),
                  Text(
                    widget.playerName.isEmpty ? 'Player' : widget.playerName,
                    style:
                        AppTheme.displayFont(size: 18, color: AppTheme.text100),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level $_level  |  ${widget.profession}',
                    style: AppTheme.uiFont(size: 12, color: AppTheme.text400),
                  ),
                  const SizedBox(height: 18),

                  XpBar(
                    current: _currentXP.toDouble(),
                    max: _maxXP.toDouble(),
                    label: 'Karma progress',
                  ),
                  const SizedBox(height: 20),

                  // Growth stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration:
                        AppTheme.baseCard(borderColor: AppTheme.borderDim),
                    child: Column(
                      children: [
                        StatBar(
                          statName: 'Health',
                          emoji: '🏃',
                          value: (_stats['health'] ?? 0).toDouble(),
                          delay: Duration.zero,
                        ),
                        StatBar(
                          statName: 'Knowledge',
                          emoji: '📚',
                          value: (_stats['knowledge'] ?? 0).toDouble(),
                          delay: Duration.zero,
                        ),
                        StatBar(
                          statName: 'Discipline',
                          emoji: '⚡',
                          value: (_stats['discipline'] ?? 0).toDouble(),
                          delay: Duration.zero,
                        ),
                        StatBar(
                          statName: 'Social',
                          emoji: '🧍',
                          value: (_stats['social'] ?? 0).toDouble(),
                          delay: Duration.zero,
                        ),
                        StatBar(
                          statName: 'Focus',
                          emoji: '🎯',
                          value: (_stats['focus'] ?? 0).toDouble(),
                          delay: Duration.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Full profile button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            playerName: widget.playerName,
                            level: _level,
                            completedQuests: _completedQuests,
                            stats: _stats,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.copper,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'VIEW FULL PROFILE  ›',
                        textAlign: TextAlign.center,
                        style: AppTheme.displayFont(
                            size: 13, color: AppTheme.bg900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: Container(
        decoration: AppTheme.scaffoldBackground(),
        child: Stack(
          children: [
            Column(
              children: [
                // ── TOP HEADER ──
                _buildHeader(),
                // ── TABS ──
                _buildTabs(),
                // ── CONTENT ──
                Expanded(
                  child: _selectedTab == 0
                      ? _buildQuestView()
                      : _buildStatsView(),
                ),
              ],
            ),
            // ── BOTTOM NAV ──
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
            const IgnorePointer(
              child: Opacity(
                opacity: 0.14,
                child: ScanlineOverlay(child: SizedBox.expand()),
              ),
            ),
            // ── LEVEL UP OVERLAY ──
            if (_showLevelUp)
              LevelUpOverlay(
                newLevel: _level,
                avatar: _currentAvatar,
                progress: _avatarProgress?.copyWith(currentLevel: _level),
                onDismiss: () => setState(() {
                  _showLevelUp = false;
                  _avatarAnimationState = AvatarAnimationState.idle;
                }),
              ),
            // ── LOGOUT LOADING VEIL ──
            if (_loggingOut)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.mana),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 14,
            20,
            18,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111936), Color(0xFF090B1D)],
            ),
            border: const Border(
              bottom: BorderSide(color: AppTheme.borderDim, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: AppTheme.uiFont(
                          size: 13,
                          color: AppTheme.text400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.playerName.isEmpty
                            ? 'Player'
                            : widget.playerName,
                        style: AppTheme.uiFont(
                          size: 24,
                          weight: FontWeight.w800,
                          color: AppTheme.text100,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Level $_level  |  ${widget.profession}',
                        style: AppTheme.uiFont(
                          size: 12,
                          color: AppTheme.text200,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showAvatarStatsSheet,
                        child: _avatarLoading ||
                                _currentAvatar == null ||
                                _avatarProgress == null
                            ? Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderDim),
                                  color: AppTheme.bg700,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.playerName.isNotEmpty
                                        ? widget.playerName[0]
                                        : 'P',
                                    style: AppTheme.displayFont(
                                      size: 18,
                                      color: AppTheme.text100,
                                    ),
                                  ),
                                ),
                              )
                            : AvatarDisplay(
                                avatar: _currentAvatar!,
                                progress: _avatarProgress!,
                                size: 44,
                                showBadges: false,
                                animationState: _avatarAnimationState,
                              ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _handleLogout,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.bg700.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderDim),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.text200,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildGoalCard(),
              const SizedBox(height: 16),
              XpBar(
                current: _currentXP.toDouble(),
                max: _maxXP.toDouble(),
                label: 'Karma progress',
              ),
              const SizedBox(height: 14),
              _buildHciToggle(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your steady path',
                    style: AppTheme.uiFont(
                      size: 11,
                      color: AppTheme.text400,
                    ),
                  ),
                  Text(
                    '$_completedQuests quests done',
                    style: AppTheme.uiFont(
                      size: 11,
                      color: AppTheme.text400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg800.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDim),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.mana.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppTheme.mana,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Main goal',
                  style: AppTheme.uiFont(size: 11, color: AppTheme.text400),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.goal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.uiFont(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppTheme.text100,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Today', 'Growth'];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppTheme.bg900.withValues(alpha: 0.4),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderDim, width: 1),
        ),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final sel = e.key == _selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: EdgeInsets.only(
                  right: e.key == tabs.length - 1 ? 0 : 8,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.mana.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel
                        ? AppTheme.mana.withValues(alpha: 0.48)
                        : AppTheme.borderDim,
                  ),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: AppTheme.uiFont(
                    size: 13,
                    weight: sel ? FontWeight.w800 : FontWeight.w600,
                    color: sel ? AppTheme.text100 : AppTheme.text400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuestView() {
    if (_dailyQuests.isEmpty && _weeklyQuests.isEmpty) {
      return _buildEmptyQuestState();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 108),
      children: [
        // ── DAILY QUESTS ──
        _sectionTitle(
          title: 'Today',
          subtitle: 'Small wins that keep the bigger goal moving.',
        ),
        const SizedBox(height: 12),
        if (_dailyQuests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('No daily quests yet.',
                style: AppTheme.monoFont(size: 12, color: AppTheme.text600)),
          )
        else
          ..._dailyQuests.asMap().entries.map((e) {
            return QuestCard(
              title: e.value['title'] as String,
              xpReward: e.value['xp'] as String,
              category: e.value['category'] as String,
              completed: e.value['completed'] as bool,
              index: e.key,
              description: e.value['why'] as String?,
              avatarAffinityStat: _currentAvatar?.defaultStat,
              onComplete: () => _onQuestComplete(e.value, isWeekly: false),
            );
          }),
        const SizedBox(height: 24),
        // ── WEEKLY QUESTS ──
        _sectionTitle(
          title: 'This week',
          subtitle: 'Larger pushes for when you have breathing room.',
        ),
        const SizedBox(height: 12),
        if (_weeklyQuests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('No weekly quests yet.',
                style: AppTheme.monoFont(size: 12, color: AppTheme.text600)),
          )
        else
          ..._weeklyQuests.asMap().entries.map((e) {
            return QuestCard(
              title: e.value['title'] as String,
              xpReward: e.value['xp'] as String,
              category: e.value['category'] as String,
              completed: e.value['completed'] as bool,
              index: e.key,
              description: e.value['why'] as String?,
              avatarAffinityStat: _currentAvatar?.defaultStat,
              onComplete: () => _onQuestComplete(e.value, isWeekly: true),
            );
          }),
      ],
    );
  }

  Widget _buildHciToggle() => const HciConditionToggle();


  Widget _buildEmptyQuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text('NO ACTIVE QUESTS',
                style: AppTheme.displayFont(size: 18, color: AppTheme.mana)),
            const SizedBox(height: 10),
            Text(
              'Type your problem to generate\npersonalised quests with AI.',
              textAlign: TextAlign.center,
              style: AppTheme.monoFont(size: 13, color: AppTheme.text400),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StudentProblemScreen(
                  playerName: widget.playerName,
                  schedule: widget.profession,
                ),
              )),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.copper,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.copper.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text('START HERE  ›',
                    style:
                        AppTheme.displayFont(size: 13, color: AppTheme.bg900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.uiFont(
            size: 18,
            weight: FontWeight.w800,
            color: AppTheme.text100,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTheme.uiFont(
            size: 12,
            color: AppTheme.text400,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 108),
      children: [
        _sectionTitle(
          title: 'Growth areas',
          subtitle: 'A simple read on where your effort has been landing.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.baseCard(borderColor: AppTheme.borderDim),
          child: Column(
            children: [
              StatBar(
                statName: 'Health',
                emoji: '🏃',
                value: (_stats['health'] ?? 0).toDouble(),
                delay: const Duration(milliseconds: 100),
              ),
              StatBar(
                statName: 'Knowledge',
                emoji: '📚',
                value: (_stats['knowledge'] ?? 0).toDouble(),
                delay: const Duration(milliseconds: 200),
              ),
              StatBar(
                statName: 'Discipline',
                emoji: '⚡',
                value: (_stats['discipline'] ?? 0).toDouble(),
                delay: const Duration(milliseconds: 300),
              ),
              StatBar(
                statName: 'Social',
                emoji: '🧍',
                value: (_stats['social'] ?? 0).toDouble(),
                delay: const Duration(milliseconds: 400),
              ),
              StatBar(
                statName: 'Focus',
                emoji: '🎯',
                value: (_stats['focus'] ?? 0).toDouble(),
                delay: const Duration(milliseconds: 500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle(
          title: 'Progress notes',
          subtitle: 'Numbers that make the streak feel real.',
        ),
        const SizedBox(height: 12),
        ...() {
          final streakDays =
              _completedQuests == 0 ? 0 : (_completedQuests / 2).ceil() + 1;
          return [
            {'label': 'Quests Completed', 'value': '$_completedQuests'},
            {'label': 'Current Level', 'value': 'LVL $_level'},
            {'label': 'Total XP', 'value': '${(_level - 1) * 500 + _currentXP}'},
            {
              'label': 'Streak',
              'value': '$streakDays ${streakDays == 1 ? 'DAY' : 'DAYS'}'
            },
          ];
        }().map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: AppTheme.baseCard(borderColor: AppTheme.borderDim),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['label']!,
                  style: AppTheme.uiFont(size: 13, color: AppTheme.text200),
                ),
                Text(
                  item['value']!,
                  style: AppTheme.uiFont(
                    size: 14,
                    weight: FontWeight.w800,
                    color: AppTheme.text100,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Maps a quest category string to its theme colour.
  /// Kept in sync with the same helper in QuestCard so the affinity
  /// SnackBar uses the correct category colour.
  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'health':
        return AppTheme.danger;
      case 'knowledge':
        return AppTheme.xpBlue;
      case 'discipline':
        return AppTheme.copper;
      case 'social':
        return AppTheme.mana;
      case 'focus':
        return const Color(0xFF9B6DFF); // violet/purple
      default:
        return AppTheme.text200;
    }
  }

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bg900.withValues(alpha: 0.94),
        border: const Border(
          top: BorderSide(color: AppTheme.borderDim, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.check_circle_outline_rounded, 'Today', 0),
          _navItem(Icons.trending_up_rounded, 'Growth', 1),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final sel = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppTheme.bg700.withValues(alpha: 0.78) : null,
          border: sel ? Border.all(color: AppTheme.borderDim) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: sel ? AppTheme.mana : AppTheme.text400,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.uiFont(
                size: 10,
                weight: FontWeight.w700,
                color: sel ? AppTheme.text100 : AppTheme.text400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
