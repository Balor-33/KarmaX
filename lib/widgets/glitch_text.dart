import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlitchText extends StatefulWidget {
  final String text;
  final double fontSize;
  final bool useDisplay;
  final bool usePixel;
  final Color color;

  const GlitchText({
    super.key,
    required this.text,
    this.fontSize = 24,
    this.useDisplay = false,
    this.usePixel = false,
    this.color = AppTheme.text100,
  });

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  String _displayed = '';
  Timer? _glitchTimer;
  Timer? _revealTimer;
  final _rand = Random();
  final _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@!%&';
  int _revealIndex = 0;

  @override
  void initState() {
    super.initState();
    _startReveal();
  }

  void _startReveal() {
    _displayed = List.filled(widget.text.length, '·').join();
    _revealIndex = 0;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (_revealIndex >= widget.text.length) {
        t.cancel();
        _displayed = widget.text;
        if (mounted) setState(() {});
        return;
      }
      _displayed = widget.text.substring(0, _revealIndex) +
          _chars[_rand.nextInt(_chars.length)] +
          (widget.text.length > _revealIndex + 1
              ? List.filled(widget.text.length - _revealIndex - 1, '·').join()
              : '');
      _revealIndex++;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.useDisplay
        ? AppTheme.displayFont(size: widget.fontSize, color: widget.color)
        : AppTheme.monoFont(size: widget.fontSize, color: widget.color);

    return Stack(
      children: [
        Text(
          _displayed,
          style: style.copyWith(color: AppTheme.copperDim.withValues(alpha: 0.4)),
        ),
        Text(_displayed, style: style),
      ],
    );
  }
}