import 'dart:math';
import 'package:flutter/material.dart';
import '../models/avatar.dart';
import '../models/avatar_composition.dart';
import '../models/user_avatar_progress.dart';
import '../theme/app_theme.dart';
import 'avatar_display.dart';
import 'glitch_text.dart';

class LevelUpOverlay extends StatefulWidget {
  final int newLevel;
  final Avatar? avatar;
  final UserAvatarProgress? progress;
  final VoidCallback onDismiss;

  const LevelUpOverlay({
    super.key,
    required this.newLevel,
    this.avatar,
    this.progress,
    required this.onDismiss,
  });

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _textCtrl;
  late AnimationController _particleCtrl;
  late Animation<double> _bgFade;
  late Animation<double> _scale;

  final List<_Particle> _particles = [];
  final _rand = Random();

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 36; i++) {
      _particles.add(_Particle(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        size: _rand.nextDouble() * 3 + 1,
        speed: _rand.nextDouble() * 0.4 + 0.1,
      ));
    }

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut),
    );

    _bgCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _textCtrl.forward();
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _bgCtrl.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _textCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _bgFade,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          color: AppTheme.bg900.withValues(alpha: 0.97),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _particleCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ParticlePainter(_particles, _particleCtrl.value),
                  size: Size.infinite,
                ),
              ),
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '// KARMA THRESHOLD REACHED //',
                        style: AppTheme.monoFont(
                          size: 10,
                          color: AppTheme.text400,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const GlitchText(
                        text: 'LEVEL UP',
                        fontSize: 52,
                        useDisplay: true,
                        color: AppTheme.copper,
                      ),
                      const SizedBox(height: 20),
                      _buildLevelAvatar(),
                      const SizedBox(height: 16),
                      Text(
                        'LEVEL ${widget.newLevel}',
                        style: AppTheme.displayFont(
                          size: 24,
                          color: AppTheme.text100,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NEW GEAR SYNCED',
                        style: AppTheme.monoFont(
                          size: 9,
                          color: AppTheme.copper,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TAP TO CONTINUE',
                        style: AppTheme.monoFont(
                          size: 9,
                          color: AppTheme.text400,
                          letterSpacing: 4,
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

  Widget _buildLevelAvatar() {
    final avatar = widget.avatar;
    final progress = widget.progress;

    if (avatar != null && progress != null) {
      return AvatarDisplay(
        avatar: avatar,
        progress: progress.copyWith(currentLevel: widget.newLevel),
        size: 152,
        showBadges: true,
        animationState: AvatarAnimationState.levelUp,
      );
    }

    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: AppTheme.bg800,
        border: Border.all(color: AppTheme.copper, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.copper.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${widget.newLevel}',
          style: AppTheme.displayFont(
            size: 56,
            color: AppTheme.copper,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFc07840).withValues(alpha: 0.25);

    for (final p in particles) {
      final dy = (p.y + t * p.speed) % 1.0;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(p.x * size.width, dy * size.height),
          width: p.size,
          height: p.size,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}
