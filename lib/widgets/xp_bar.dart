import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class XpBar extends StatefulWidget {
  final double current;
  final double max;
  final String label;
  final bool animate;

  const XpBar({
    super.key,
    required this.current,
    required this.max,
    this.label = 'XP',
    this.animate = true,
  });

  @override
  State<XpBar> createState() => _XpBarState();
}

class _XpBarState extends State<XpBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.current / widget.max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: AppTheme.uiFont(
                size: 12,
                weight: FontWeight.w700,
                color: AppTheme.text200,
              ),
            ),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Text(
                '${(widget.current * _anim.value).toInt()} / ${widget.max.toInt()}',
                style: AppTheme.uiFont(size: 12, color: AppTheme.text200),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 10,
          width: double.infinity,
          decoration: AppTheme.xpTrack(),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct * _anim.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.xpBlue,
                        AppTheme.mana,
                        AppTheme.copper,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mana.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StatBar extends StatefulWidget {
  final String statName;
  final String emoji;
  final double value;
  final Duration delay;

  const StatBar({
    super.key,
    required this.statName,
    required this.emoji,
    required this.value,
    this.delay = Duration.zero,
  });

  @override
  State<StatBar> createState() => _StatBarState();
}

class _StatBarState extends State<StatBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              widget.statName,
              style: AppTheme.uiFont(
                size: 12,
                weight: FontWeight.w700,
                color: AppTheme.text200,
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                final v = (widget.value / 100) * _anim.value;
                return Stack(
                  children: [
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.bg900.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.xpBlue, AppTheme.mana],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => SizedBox(
              width: 30,
              child: Text(
                '${(widget.value * _anim.value).toInt()}',
                style: AppTheme.uiFont(size: 11, color: AppTheme.text200),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
