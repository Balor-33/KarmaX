import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_theme.dart';
import '../models/avatar.dart';
import '../models/user_avatar_progress.dart';
import '../services/avatar_service.dart';
import '../widgets/avatar_display.dart';
import 'student_problem_screen.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final String? playerName;
  final String? profession;
  final String? schedule;
  final VoidCallback? onComplete;

  const AvatarSelectionScreen({
    super.key,
    this.playerName,
    this.profession,
    this.schedule,
    this.onComplete,
  });

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  late Future<List<Avatar>> avatarsFuture;
  final PageController _pageController = PageController(viewportFraction: 1);
  String? selectedAvatarId;
  int currentPage = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadAvatars() {
    avatarsFuture = AvatarService().getAvailableAvatars();
  }

  void _navigateNext() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (widget.playerName != null &&
        widget.profession != null &&
        widget.schedule != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StudentProblemScreen(
            playerName: widget.playerName!,
            schedule: widget.schedule!,
          ),
        ),
      );
    }
  }

  Future<void> _selectAvatar() async {
    if (selectedAvatarId == null) {
      _navigateNext();
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await AvatarService().selectAvatar(user.id, selectedAvatarId!);
      }
      if (mounted) _navigateNext();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _goToPage(int page, int itemCount) {
    if (page < 0 || page >= itemCount) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      appBar: AppBar(
        backgroundColor: AppTheme.bg900,
        elevation: 0,
        title: Text(
          '// SELECT YOUR AVATAR',
          style: AppTheme.monoFont(
            size: 12,
            color: AppTheme.text100,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _navigateNext,
            child: Text(
              'SKIP',
              style: AppTheme.monoFont(
                size: 10,
                color: AppTheme.text400,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.scaffoldBackground(),
        child: FutureBuilder<List<Avatar>>(
          future: avatarsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.copper),
              );
            }

            final avatars = snapshot.data ?? [];
            final hasError = snapshot.hasError || avatars.isEmpty;

            if (hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppTheme.copper, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.hasError
                          ? 'Error loading avatars'
                          : 'No avatars found',
                      style: AppTheme.displayFont(
                        size: 16,
                        color: AppTheme.text100,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.hasError
                          ? '${snapshot.error}'
                          : 'The avatars table may be empty or not yet set up.',
                      style: AppTheme.monoFont(
                        size: 9,
                        color: AppTheme.text400,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(_loadAvatars),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.copper,
                          ),
                          child: Text(
                            'RETRY',
                            style: AppTheme.monoFont(
                              size: 11,
                              color: AppTheme.bg900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: _navigateNext,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderDim),
                          ),
                          child: Text(
                            'SKIP FOR NOW',
                            style: AppTheme.monoFont(
                              size: 11,
                              color: AppTheme.text400,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            selectedAvatarId ??=
                avatars[currentPage.clamp(0, avatars.length - 1)].id;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
                  child: Text(
                    'Choose your character archetype. Your avatar will grow stronger as you complete quests and level up.',
                    style: AppTheme.monoFont(
                      size: 10,
                      color: AppTheme.text200,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: avatars.length,
                        onPageChanged: (index) {
                          setState(() {
                            currentPage = index;
                            selectedAvatarId = avatars[index].id;
                          });
                        },
                        itemBuilder: (context, index) =>
                            _buildAvatarPage(avatars[index]),
                      ),
                      if (avatars.length > 1)
                        Positioned(
                          left: 4,
                          child: _NavArrow(
                            icon: Icons.chevron_left,
                            enabled: currentPage > 0,
                            onTap: () =>
                                _goToPage(currentPage - 1, avatars.length),
                          ),
                        ),
                      if (avatars.length > 1)
                        Positioned(
                          right: 4,
                          child: _NavArrow(
                            icon: Icons.chevron_right,
                            enabled: currentPage < avatars.length - 1,
                            onTap: () =>
                                _goToPage(currentPage + 1, avatars.length),
                          ),
                        ),
                    ],
                  ),
                ),
                if (avatars.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < avatars.length; i++)
                          GestureDetector(
                            onTap: () => _goToPage(i, avatars.length),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: i == currentPage ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == currentPage
                                    ? AppTheme.mana
                                    : AppTheme.borderDim,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bg900.withValues(alpha: 0.88),
                    border: const Border(
                      top: BorderSide(color: AppTheme.borderBright),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _selectAvatar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedAvatarId != null
                            ? AppTheme.copper
                            : AppTheme.bg700,
                        disabledBackgroundColor: AppTheme.bg700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: selectedAvatarId != null
                                ? AppTheme.borderCopper
                                : AppTheme.borderDim,
                          ),
                        ),
                      ),
                      child: Text(
                        isLoading
                            ? 'SAVING...'
                            : selectedAvatarId != null
                                ? 'CONFIRM SELECTION'
                                : 'SKIP FOR NOW',
                        style: AppTheme.monoFont(
                          size: 11,
                          color: selectedAvatarId != null
                              ? AppTheme.bg900
                              : AppTheme.text400,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarPage(Avatar avatar) {
    final previewProgress = UserAvatarProgress(
      id: 'preview-${avatar.id}',
      userId: 'preview',
      selectedAvatarId: avatar.id,
      currentLevel: 5,
      dominantStat: avatar.defaultStat,
      equippedBadges: const [],
      lastUpdated: DateTime.now(),
    );

    final statColor =
        AvatarTheme.statColors[avatar.defaultStat] ?? AppTheme.copper;

    return LayoutBuilder(
      builder: (context, constraints) {
        final modelSize =
            (constraints.maxWidth * 0.8).clamp(240.0, 460.0).toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              _RotatableModel(
                avatar: avatar,
                progress: previewProgress,
                size: modelSize,
              ),
              const SizedBox(height: 20),
              Text(
                '// ARCHETYPE PROFILE',
                style: AppTheme.monoFont(
                  size: 9,
                  color: AppTheme.copper,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                avatar.name.toUpperCase(),
                style: AppTheme.displayFont(
                  size: 24,
                  color: AppTheme.text100,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 2,
                color: statColor,
              ),
              const SizedBox(height: 14),
              Text(
                avatar.description,
                style: AppTheme.monoFont(
                  size: 11,
                  color: AppTheme.text200,
                  letterSpacing: 0.4,
                ).copyWith(height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.bg800,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DEFAULT AFFINITY  ',
                      style: AppTheme.monoFont(
                        size: 9,
                        color: AppTheme.text400,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      AvatarTheme.statEmojis[avatar.defaultStat] ?? '⭐',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      avatar.defaultStat.toUpperCase(),
                      style: AppTheme.monoFont(
                        size: 10,
                        color: statColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Wraps [AvatarDisplay] with a brief, self-dismissing "drag to rotate"
/// hint so people discover the model is interactive without needing a
/// permanent on-screen instruction competing with the model itself.
class _RotatableModel extends StatefulWidget {
  final Avatar avatar;
  final UserAvatarProgress progress;
  final double size;

  const _RotatableModel({
    required this.avatar,
    required this.progress,
    required this.size,
  });

  @override
  State<_RotatableModel> createState() => _RotatableModelState();
}

class _RotatableModelState extends State<_RotatableModel> {
  bool _hintVisible = true;

  void _dismissHint() {
    if (_hintVisible) setState(() => _hintVisible = false);
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _dismissHint);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Listener(
            onPointerDown: (_) => _dismissHint(),
            child: AvatarDisplay(
              avatar: widget.avatar,
              progress: widget.progress,
              size: widget.size,
              showBadges: false,
            ),
          ),
          AnimatedOpacity(
            opacity: _hintVisible ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bg900.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.threesixty_rounded,
                          size: 12, color: AppTheme.text400),
                      const SizedBox(width: 5),
                      Text(
                        'DRAG TO ROTATE',
                        style: AppTheme.monoFont(
                          size: 8,
                          color: AppTheme.text400,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circular chevron button used to page the carousel left/right.
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.25,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.bg800.withValues(alpha: 0.85),
            border: Border.all(color: AppTheme.borderDim),
          ),
          child: Icon(icon, color: AppTheme.text100, size: 22),
        ),
      ),
    );
  }
}
