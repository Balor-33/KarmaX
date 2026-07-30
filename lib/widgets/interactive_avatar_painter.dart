import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/avatar_composition.dart';
import '../theme/app_theme.dart';

class InteractiveAvatarPainter extends CustomPainter {
  final AvatarComposition composition;
  final Color baseColor;
  final double animationValue; // 0.0 to 1.0
  final AvatarAnimationState animationState;

  InteractiveAvatarPainter({
    required this.composition,
    required this.baseColor,
    required this.animationValue,
    required this.animationState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseY = size.height * 0.6;

    Offset bodyOffset = _getAnimationOffset(center, baseY);


    _drawAura(canvas, size, bodyOffset);
    _drawShadow(canvas, size, bodyOffset);
    _drawBody(canvas, size, bodyOffset);
    _drawHead(canvas, size, bodyOffset);
    _drawHair(canvas, size, bodyOffset);
    _drawEquipment(canvas, size, bodyOffset);
    _drawLevelUpBurst(canvas, size, bodyOffset);
  }

  /// Calculate animation offset based on state
  Offset _getAnimationOffset(Offset center, double baseY) {
    switch (animationState) {
      case AvatarAnimationState.idle:
        final bobAmount = math.sin(animationValue * 2 * math.pi) * 3;
        return Offset(center.dx, baseY + bobAmount);

      case AvatarAnimationState.levelUp:
        final jumpHeight = _easeOutBounce(animationValue) * 40;
        final spin = animationValue * 2 * math.pi;
        return Offset(
          center.dx + math.sin(spin) * 5,
          baseY - jumpHeight,
        );

      case AvatarAnimationState.acting:
        final swing = math.sin(animationValue * 2 * math.pi) * 8;
        return Offset(center.dx + swing, baseY);

      case AvatarAnimationState.resting:
        return Offset(center.dx, baseY);
    }
  }

  /// Bouncy easing for level-up
  double _easeOutBounce(double t) {
    const c1 = 1.70158;
    return t < 0.5
        ? (math.pow(2 * t, 2) * ((c1 + 1) * 2 * t - c1)) / 2
        : (math.pow(2 * t - 2, 2) * ((c1 + 1) * (t * 2 - 2) + c1) + 2) / 2;
  }

  void _drawShadow(Canvas canvas, Size size, Offset bodyOffset) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyOffset.dx, size.height * 0.85),
        width: size.width * 0.4,
        height: 6,
      ),
      shadowPaint,
    );
  }

  void _drawBody(Canvas canvas, Size size, Offset bodyOffset) {
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(baseColor, Colors.white, 0.18)!,
          Color.lerp(baseColor, AppTheme.bg900, 0.22)!,
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(bodyOffset.dx, bodyOffset.dy - 5),
        width: size.width * 0.35,
        height: size.height * 0.4,
      ))
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = AppTheme.bg900.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final bodyScale = switch (composition.bodyType) {
      'slim' => 0.85,
      'muscular' => 1.15,
      _ => 1.0,
    };
    final bodyWidth = size.width * 0.25 * bodyScale;
    final bodyHeight = size.height * 0.35;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(bodyOffset.dx, bodyOffset.dy - 5),
        width: bodyWidth,
        height: bodyHeight,
      ),
      Radius.circular(bodyWidth * 0.3),
    );

    final armLength = bodyWidth * 0.8;
    final armX = bodyOffset.dx - bodyWidth * 0.2;
    final armY = bodyOffset.dy - bodyHeight * 0.15;

    final armPaint = Paint()
      ..color = skinTones[composition.skinTone] ?? skinTones['warm']!
      ..style = PaintingStyle.fill;
    final legPaint = Paint()
      ..color = Color.lerp(baseColor, AppTheme.bg900, 0.28)!
      ..style = PaintingStyle.fill;

    final legTop = bodyOffset.dy + bodyHeight * 0.18;
    for (final side in [-1, 1]) {
      final legRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bodyOffset.dx + side * bodyWidth * 0.18, legTop),
          width: bodyWidth * 0.22,
          height: bodyHeight * 0.55,
        ),
        Radius.circular(bodyWidth * 0.09),
      );
      canvas.drawRRect(legRect, legPaint);
      canvas.drawRRect(legRect, outlinePaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(armX - armLength * 0.5, armY),
          width: armLength * 0.15,
          height: armLength,
        ),
        Radius.circular(armLength * 0.1),
      ),
      armPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center:
              Offset(bodyOffset.dx + bodyWidth * 0.15 + armLength * 0.5, armY),
          width: armLength * 0.15,
          height: armLength,
        ),
        Radius.circular(armLength * 0.1),
      ),
      armPaint,
    );

    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, outlinePaint);

    final sashPaint = Paint()
      ..color = AppTheme.bg900.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(
          bodyOffset.dx - bodyWidth * 0.35, bodyOffset.dy - bodyHeight * 0.2),
      Offset(
          bodyOffset.dx + bodyWidth * 0.35, bodyOffset.dy + bodyHeight * 0.2),
      sashPaint,
    );
  }

  void _drawHead(Canvas canvas, Size size, Offset bodyOffset) {
    final headRadius = size.width * 0.15;
    final headPaint = Paint()
      ..color = skinTones[composition.skinTone] ?? skinTones['warm']!
      ..style = PaintingStyle.fill;

    final headCenter =
        Offset(bodyOffset.dx, bodyOffset.dy - size.height * 0.25);
    canvas.drawCircle(headCenter, headRadius, headPaint);
    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()
        ..color = AppTheme.bg900.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final eyePaint = Paint()
      ..color = AppTheme.bg900
      ..style = PaintingStyle.fill;

    final eyeY = headCenter.dy - headRadius * 0.2;
    final eyeOffset = headRadius * 0.25;

    canvas.drawCircle(
      Offset(headCenter.dx - eyeOffset, eyeY),
      headRadius * 0.1,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + eyeOffset, eyeY),
      headRadius * 0.1,
      eyePaint,
    );

    final browPaint = Paint()
      ..color = _hairColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final browTilt = animationState == AvatarAnimationState.acting ? 0.05 : 0.0;
    canvas.drawLine(
      Offset(
          headCenter.dx - eyeOffset - 3, eyeY - headRadius * (0.24 - browTilt)),
      Offset(headCenter.dx - eyeOffset + 4, eyeY - headRadius * 0.18),
      browPaint,
    );
    canvas.drawLine(
      Offset(headCenter.dx + eyeOffset - 4, eyeY - headRadius * 0.18),
      Offset(
          headCenter.dx + eyeOffset + 3, eyeY - headRadius * (0.24 - browTilt)),
      browPaint,
    );

    final pupilPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pupilOffset = _getPupilOffset(animationValue);
    canvas.drawCircle(
      Offset(headCenter.dx - eyeOffset + pupilOffset.dx, eyeY + pupilOffset.dy),
      headRadius * 0.04,
      pupilPaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + eyeOffset + pupilOffset.dx, eyeY + pupilOffset.dy),
      headRadius * 0.04,
      pupilPaint,
    );

    _drawMouth(canvas, headCenter, headRadius);
  }

  Offset _getPupilOffset(double animation) {
    final angle = animation * 2 * math.pi;
    return Offset(
      math.cos(angle) * 2,
      math.sin(angle) * 2,
    );
  }

  void _drawMouth(Canvas canvas, Offset headCenter, double headRadius) {
    final mouthPaint = Paint()
      ..color = AppTheme.bg900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final mouthSmile =
        animationState == AvatarAnimationState.levelUp ? 0.3 : 0.1;

    final mouthPath = Path()
      ..moveTo(
          headCenter.dx - headRadius * 0.1, headCenter.dy + headRadius * 0.1)
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy + headRadius * 0.15 + (mouthSmile * headRadius),
        headCenter.dx + headRadius * 0.1,
        headCenter.dy + headRadius * 0.1,
      );

    canvas.drawPath(mouthPath, mouthPaint);
  }

  void _drawHair(Canvas canvas, Size size, Offset bodyOffset) {
    final headRadius = size.width * 0.15;
    final headCenter =
        Offset(bodyOffset.dx, bodyOffset.dy - size.height * 0.25);

    final hairPaint = Paint()
      ..color = _hairColor()
      ..style = PaintingStyle.fill;

    switch (composition.hairStyle) {
      case 'spiky':
        for (int i = 0; i < 8; i++) {
          final angle = (i / 8) * 2 * math.pi;
          final spikeLength = headRadius * 0.6;
          final startX = headCenter.dx + math.cos(angle) * headRadius * 0.9;
          final startY = headCenter.dy + math.sin(angle) * headRadius * 0.9;
          final endX =
              headCenter.dx + math.cos(angle) * (headRadius + spikeLength);
          final endY =
              headCenter.dy + math.sin(angle) * (headRadius + spikeLength);

          canvas.drawLine(
            Offset(startX, startY),
            Offset(endX, endY),
            hairPaint
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      case 'wavy':
        final waveHeight = headRadius * 0.4;
        final path = Path()
          ..moveTo(headCenter.dx - headRadius * 0.8,
              headCenter.dy - headRadius * 0.9);

        for (int i = 0; i <= 20; i++) {
          final x =
              headCenter.dx - headRadius * 0.8 + (i / 20) * headRadius * 1.6;
          final wave = math.sin((i / 20) * 2 * math.pi) * waveHeight;
          final y = headCenter.dy - headRadius * 0.7 + wave;
          path.lineTo(x, y);
        }

        path.arcToPoint(
          Offset(headCenter.dx + headRadius * 0.8,
              headCenter.dy - headRadius * 0.9),
          radius: Radius.circular(headRadius),
        );
        path.close();

        canvas.drawPath(path, hairPaint);
        break;

      case 'long':
        final leftPath = Path()
          ..moveTo(headCenter.dx - headRadius * 0.6,
              headCenter.dy - headRadius * 0.8)
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 0.7,
            headCenter.dy + headRadius * 0.5,
            headCenter.dx - headRadius * 0.5,
            headCenter.dy + headRadius * 0.8,
          );

        final rightPath = Path()
          ..moveTo(headCenter.dx + headRadius * 0.6,
              headCenter.dy - headRadius * 0.8)
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 0.7,
            headCenter.dy + headRadius * 0.5,
            headCenter.dx + headRadius * 0.5,
            headCenter.dy + headRadius * 0.8,
          );

        canvas.drawPath(leftPath, hairPaint);
        canvas.drawPath(rightPath, hairPaint);
        break;

      case 'curly':
        for (int i = 0; i < 7; i++) {
          final x = headCenter.dx - headRadius * 0.75 + i * headRadius * 0.25;
          canvas.drawCircle(
            Offset(x, headCenter.dy - headRadius * 0.72),
            headRadius * 0.22,
            hairPaint,
          );
        }
        break;

      case 'braided':
        canvas.drawArc(
          Rect.fromCircle(center: headCenter, radius: headRadius),
          math.pi,
          math.pi,
          true,
          hairPaint,
        );
        for (int i = 0; i < 4; i++) {
          canvas.drawCircle(
            Offset(
              headCenter.dx + headRadius * 0.75,
              headCenter.dy - headRadius * 0.15 + i * headRadius * 0.28,
            ),
            headRadius * 0.16,
            hairPaint,
          );
        }
        break;

      case 'short':
      default:
        canvas.drawArc(
          Rect.fromCircle(center: headCenter, radius: headRadius),
          math.pi,
          math.pi,
          true,
          hairPaint,
        );
        break;
    }
  }

  void _drawEquipment(Canvas canvas, Size size, Offset bodyOffset) {
    final equipment = getEquipmentForLevel(composition.armorLevel);
    final bodyScale = switch (composition.bodyType) {
      'slim' => 0.85,
      'muscular' => 1.15,
      _ => 1.0,
    };
    final bodyWidth = size.width * 0.25 * bodyScale;
    final bodyHeight = size.height * 0.35;

    final equipmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.amber.shade600;

    if (equipment.level >= 5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(bodyOffset.dx, bodyOffset.dy - 5),
            width: bodyWidth * 1.15,
            height: bodyHeight * 0.7,
          ),
          Radius.circular(bodyWidth * 0.2),
        ),
        equipmentPaint,
      );
    }

    if (equipment.level >= 10) {
      canvas.drawCircle(
        Offset(bodyOffset.dx - bodyWidth * 0.35,
            bodyOffset.dy - bodyHeight * 0.15),
        bodyWidth * 0.12,
        equipmentPaint..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(bodyOffset.dx + bodyWidth * 0.35,
            bodyOffset.dy - bodyHeight * 0.15),
        bodyWidth * 0.12,
        equipmentPaint..style = PaintingStyle.fill,
      );
    }

    if (equipment.level >= 15) {
      final headRadius = size.width * 0.15;
      final headCenter =
          Offset(bodyOffset.dx, bodyOffset.dy - size.height * 0.25);

      canvas.drawArc(
        Rect.fromCircle(center: headCenter, radius: headRadius * 1.2),
        math.pi,
        math.pi,
        false,
        equipmentPaint..strokeWidth = 3,
      );
    }

    if (equipment.accessory == 'sword') {
      _drawSword(canvas, size, bodyOffset);
    } else if (equipment.accessory == 'shield') {
      _drawShield(canvas, size, bodyOffset);
    }
  }

  void _drawAura(Canvas canvas, Size size, Offset bodyOffset) {
    if (composition.armorLevel < 10 &&
        animationState != AvatarAnimationState.levelUp) {
      return;
    }

    final auraPaint = Paint()
      ..color = baseColor.withValues(
        alpha: animationState == AvatarAnimationState.levelUp ? 0.28 : 0.16,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = animationState == AvatarAnimationState.levelUp ? 4 : 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);

    final pulse = math.sin(animationValue * 2 * math.pi) * size.width * 0.03;
    final auraRadius = size.width * 0.34 + pulse;
    canvas.drawCircle(bodyOffset, auraRadius, auraPaint);
  }

  void _drawLevelUpBurst(Canvas canvas, Size size, Offset bodyOffset) {
    if (animationState != AvatarAnimationState.levelUp) return;

    final burstPaint = Paint()
      ..color = AppTheme.copper.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final progress = Curves.easeOut.transform(animationValue);
    final inner = size.width * (0.25 + progress * 0.05);
    final outer = size.width * (0.36 + progress * 0.1);

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi + progress * 0.6;
      final start = Offset(
        bodyOffset.dx + math.cos(angle) * inner,
        bodyOffset.dy - size.height * 0.16 + math.sin(angle) * inner,
      );
      final end = Offset(
        bodyOffset.dx + math.cos(angle) * outer,
        bodyOffset.dy - size.height * 0.16 + math.sin(angle) * outer,
      );
      canvas.drawLine(start, end, burstPaint);
    }
  }

  Color _hairColor() {
    return Color.lerp(AppTheme.bg900, baseColor, 0.45) ?? AppTheme.bg700;
  }

  void _drawSword(Canvas canvas, Size size, Offset bodyOffset) {
    final swing = animationState == AvatarAnimationState.acting
        ? math.sin(animationValue * 2 * math.pi) * 0.35
        : 0.0;

    canvas.save();
    canvas.translate(bodyOffset.dx + size.width * 0.2, bodyOffset.dy - 12);
    canvas.rotate(-0.65 + swing);

    final bladePaint = Paint()
      ..color = AppTheme.text100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final hiltPaint = Paint()
      ..color = AppTheme.copper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(0, -size.height * 0.25), bladePaint);
    canvas.drawLine(const Offset(-8, -6), const Offset(8, -6), hiltPaint);
    canvas.restore();
  }

  void _drawShield(Canvas canvas, Size size, Offset bodyOffset) {
    final shieldPaint = Paint()
      ..color = AppTheme.bg700
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = AppTheme.copper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final shieldCenter = Offset(
      bodyOffset.dx - size.width * 0.19,
      bodyOffset.dy - size.height * 0.03,
    );
    final path = Path()
      ..moveTo(shieldCenter.dx, shieldCenter.dy - size.height * 0.09)
      ..quadraticBezierTo(
        shieldCenter.dx + size.width * 0.09,
        shieldCenter.dy - size.height * 0.04,
        shieldCenter.dx,
        shieldCenter.dy + size.height * 0.11,
      )
      ..quadraticBezierTo(
        shieldCenter.dx - size.width * 0.09,
        shieldCenter.dy - size.height * 0.04,
        shieldCenter.dx,
        shieldCenter.dy - size.height * 0.09,
      );

    canvas.drawPath(path, shieldPaint);
    canvas.drawPath(path, rimPaint);
  }

  @override
  bool shouldRepaint(InteractiveAvatarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.animationState != animationState ||
        oldDelegate.composition != composition ||
        oldDelegate.baseColor != baseColor;
  }
}
