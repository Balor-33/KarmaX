import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_theme.dart';
import '../models/avatar.dart';
import '../models/avatar_composition.dart';
import '../models/user_avatar_progress.dart';

class AvatarDisplay extends StatefulWidget {
  final Avatar avatar;
  final UserAvatarProgress progress;
  final double size;
  final bool showBadges;
  final AvatarAnimationState animationState;
  final VoidCallback? onTap;

  const AvatarDisplay({
    super.key,
    required this.avatar,
    required this.progress,
    this.size = 120,
    this.showBadges = true,
    this.animationState = AvatarAnimationState.idle,
    this.onTap,
  });

  @override
  State<AvatarDisplay> createState() => _AvatarDisplayState();
}

class _AvatarDisplayState extends State<AvatarDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _avatarCtrl;
  late Animation<double> _auraScale;

  @override
  void initState() {
    super.initState();
    _avatarCtrl = AnimationController(
      vsync: this,
      duration: _durationFor(widget.animationState),
    )..repeat(reverse: widget.animationState == AvatarAnimationState.levelUp);

    _auraScale = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _avatarCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant AvatarDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationState != widget.animationState) {
      _avatarCtrl
        ..duration = _durationFor(widget.animationState)
        ..reset()
        ..repeat(
            reverse: widget.animationState == AvatarAnimationState.levelUp);
    }
  }

  @override
  void dispose() {
    _avatarCtrl.dispose();
    super.dispose();
  }

  /// Flutter web nests declared assets under an extra `assets/` folder at
  /// build time, so a path declared in pubspec.yaml as e.g.
  /// 'assets/models/vegeta.glb' is actually served at
  /// 'assets/assets/models/vegeta.glb'. model_viewer_plus renders the model
  /// inside an embedded iframe/webview, so a wrong path fails silently
  /// (blank box, no Dart error) rather than throwing. This only applies on
  /// web — mobile/desktop asset bundling doesn't double the prefix.
  String _resolveModelPath(String path) {
    if (kIsWeb && path.startsWith('assets/')) {
      return 'assets/$path';
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final statColor = AvatarTheme.statColors[widget.progress.dominantStat] ??
        const Color(0xFFc8d8cc);

    final modelPath = _resolveModelPath(
      AvatarTheme.avatarModels[widget.avatar.archetype] ??
          'assets/models/default.glb',
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.size * 1.2,
          maxHeight: widget.size * 1.2,
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            ScaleTransition(
              scale: _auraScale,
              child: Container(
                width: widget.size * 1.1,
                height: widget.size * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: statColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: AppTheme.bg800,
                border: Border.all(color: AppTheme.copper, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: statColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: ModelViewer(
                        key: ValueKey(widget.avatar.archetype),
                        src: modelPath,
                        alt: widget.avatar.name,
                        autoRotate:
                            widget.animationState == AvatarAnimationState.idle,
                        autoRotateDelay: 0,
                        rotationPerSecond: '18deg',
                        cameraControls: true,
                        disableZoom: false,
                        backgroundColor: Colors.transparent,
                        cameraOrbit: '0deg 75deg auto',
                      ),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 5,
                      child: Text(
                        'LVL ${widget.progress.currentLevel}',
                        style: AppTheme.monoFont(
                          size: (widget.size * 0.09).clamp(7.0, 11.0),
                          color: AppTheme.text100,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.bg900.withValues(alpha: 0.85),
                          border: Border.all(color: statColor, width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          AvatarTheme
                                  .statEmojis[widget.progress.dominantStat] ??
                              '*',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showBadges && widget.progress.equippedBadges.isNotEmpty)
              Positioned(
                bottom: -4,
                right: -4,
                child: _buildBadgeStack(),
              ),
          ],
        ),
      ),
    );
  }

  Duration _durationFor(AvatarAnimationState state) {
    return switch (state) {
      AvatarAnimationState.levelUp => const Duration(milliseconds: 900),
      AvatarAnimationState.acting => const Duration(milliseconds: 650),
      AvatarAnimationState.resting => const Duration(seconds: 4),
      AvatarAnimationState.idle => const Duration(seconds: 3),
    };
  }

  Widget _buildBadgeStack() {
    final badges = widget.progress.equippedBadges.take(3).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i < badges.length; i++)
          Positioned(
            right: i * 12,
            bottom: -2,
            child: _buildBadge(badges[i]),
          ),
      ],
    );
  }

  Widget _buildBadge(String badgeId) {
    final badgeName = AvatarTheme.badgeNames[badgeId] ?? badgeId;
    final badgeEmoji = AvatarTheme.badgeEmojis[badgeId] ?? '*';

    return Tooltip(
      message: badgeName,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.copper,
          border: Border.all(color: AppTheme.text100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.copper.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Center(
          child: Text(badgeEmoji, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}
