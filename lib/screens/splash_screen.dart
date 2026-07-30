import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/player_profile_service.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import 'auth_choice_screen.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  final List<_MatrixColumn> _columns = [];
  Timer? _matrixTimer;
  final _rand = Random();

  final List<String> _bootLines = [
    '> INITIALIZING KARMAX ENGINE v1.0.0',
    '> LOADING REALITY MODULES...',
    '> CALIBRATING KARMA MATRIX...',
    '> SYNCING LIFE SIMULATION DATA...',
    '> SYSTEM READY.',
  ];
  final List<bool> _visibleLines = [];

  @override
  void initState() {
    super.initState();
    _visibleLines.addAll(List.filled(_bootLines.length, false));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _buildColumns();
    _startMatrixRain();
    _runBootSequence();
  }

  void _buildColumns() {
    const screenW = 400.0;
    final cols = (screenW / 20).ceil();
    for (int i = 0; i < cols; i++) {
      _columns.add(
        _MatrixColumn(
          x: i * 20.0,
          speed: _rand.nextDouble() * 60 + 30,
          chars: List.generate(20, (_) => _randChar()),
          y: _rand.nextDouble() * -400,
        ),
      );
    }
  }

  String _randChar() {
    const pool = 'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEFX';
    return pool[_rand.nextInt(pool.length)];
  }

  void _startMatrixRain() {
    _matrixTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        for (final col in _columns) {
          col.y += col.speed / 12;
          if (col.y > 700) {
            col.y = _rand.nextDouble() * -200;
          }
          final idx = _rand.nextInt(col.chars.length);
          col.chars[idx] = _randChar();
        }
      });
    });
  }

  void _runBootSequence() async {
    for (int i = 0; i < _bootLines.length; i++) {
      await Future.delayed(Duration(milliseconds: 500 + i * 300));
      if (mounted) {
        setState(() => _visibleLines[i] = true);
      }
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Widget destination;
      try {
        destination = await _resolveDestination();
      } catch (e) {
        debugPrint('Splash: _resolveDestination failed: $e');
        destination = const AuthChoiceScreen();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  Future<Widget> _resolveDestination() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return const AuthChoiceScreen();

    final profile = await PlayerProfileService().load();

    if (profile != null && profile.isComplete) {
      return DashboardScreen(
        playerName: profile.playerName,
        goal: profile.goal,
        profession: profile.profession,
      );
    }

    final savedName = profile?.playerName;
    final metaName = user.userMetadata?['display_name']?.toString();
    final initialName =
        (savedName != null && savedName.isNotEmpty) ? savedName : metaName;

    return OnboardingScreen(initialName: initialName);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _matrixTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            children: [
              CustomPaint(
                painter: _MatrixPainter(_columns),
                size: Size.infinite,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      AppTheme.bg900.withValues(alpha: 0.7),
                      AppTheme.bg900.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 80),
                    const GlitchText(
                      text: 'KARMAX',
                      fontSize: 48,
                      useDisplay: true,
                      color: AppTheme.text100,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LIFE. SIMULATED.',
                      style: AppTheme.monoFont(
                        size: 12,
                        color: AppTheme.text200,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Container(width: 1, height: 40, color: AppTheme.bg600),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(_bootLines.length, (i) {
                          return AnimatedOpacity(
                            opacity: _visibleLines[i] ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                _bootLines[i],
                                style: AppTheme.monoFont(
                                  size: 11,
                                  color: i == _bootLines.length - 1
                                      ? AppTheme.text100
                                      : AppTheme.text200,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatrixColumn {
  double x;
  double y;
  double speed;
  List<String> chars;
  _MatrixColumn({
    required this.x,
    required this.y,
    required this.speed,
    required this.chars,
  });
}

class _MatrixPainter extends CustomPainter {
  final List<_MatrixColumn> columns;
  _MatrixPainter(this.columns);

  @override
  void paint(Canvas canvas, Size size) {
    for (final col in columns) {
      for (int i = 0; i < col.chars.length; i++) {
        final opacity = (1.0 - i / col.chars.length) * 0.3;
        final paint = TextPainter(
          text: TextSpan(
            text: col.chars[i],
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.white.withValues(alpha: opacity.clamp(0, 1)),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        paint.paint(canvas, Offset(col.x, col.y + i * 18));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter old) => true;
}
