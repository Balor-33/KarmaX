import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg900 = Color(0xFF070818);
  static const Color bg800 = Color(0xFF10142A);
  static const Color bg700 = Color(0xFF171D3C);
  static const Color bg600 = Color(0xFF22305C);
  static const Color bg500 = Color(0xFF31487E);

  static const Color text100 = Color(0xFFF3F7FF);
  static const Color text200 = Color(0xFFB8C7F4);
  static const Color text400 = Color(0xFF7182B7);
  static const Color text600 = Color(0xFF3C4773);

  static const Color copper = Color(0xFFFFC857);
  static const Color copperDim = Color(0xFFE46FBD);
  static const Color copperFaint = Color(0xFF261739);
  static const Color mana = Color(0xFF36F1CD);
  static const Color danger = Color(0xFFFF5C7A);
  static const Color xpBlue = Color(0xFF5B7CFF);

  static const Color borderDim = Color(0x3331487E);
  static const Color borderBright = Color(0x8836F1CD);
  static const Color borderCopper = Color(0x99FFC857);

  static TextStyle displayFont({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = text100,
    double? letterSpacing,
  }) =>
      GoogleFonts.cinzel(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing ?? 2,
      );

  static TextStyle monoFont({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = text100,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.shareTechMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing ?? 0.5,
        height: height,
      );

  static TextStyle uiFont({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = text100,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle accentFont({double size = 20, Color color = copper}) =>
      GoogleFonts.cinzelDecorative(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 3,
      );

  static TextStyle copperLabel({double size = 9}) => GoogleFonts.shareTechMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: mana,
        letterSpacing: 2.5,
      );

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg900,
        colorScheme: const ColorScheme.dark(
          primary: copper,
          secondary: mana,
          tertiary: copperDim,
          surface: bg800,
          onPrimary: bg900,
          onSurface: text100,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg900,
          elevation: 0,
          titleTextStyle: displayFont(size: 16, color: text100),
          iconTheme: const IconThemeData(color: text100),
        ),
        textTheme: TextTheme(
          displayLarge: displayFont(size: 32),
          displayMedium: displayFont(size: 24),
          titleLarge: displayFont(size: 18),
          bodyLarge: uiFont(size: 14),
          bodyMedium: uiFont(size: 12),
          labelSmall: uiFont(size: 10, color: text400),
        ),
        dividerColor: bg500,
      );

  static BoxDecoration baseCard({
    Color? borderColor,
    double borderWidth = 1,
  }) =>
      BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF182041), Color(0xFF10162F)],
        ),
        border: Border.all(
          color: borderColor ?? borderDim,
          width: borderWidth,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      );

  static BoxDecoration questCard({bool completed = false}) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: completed
              ? [bg800.withValues(alpha: 0.64), bg900.withValues(alpha: 0.92)]
              : [const Color(0xFF172142), const Color(0xFF10172F)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: completed ? borderDim : bg500.withValues(alpha: 0.38),
          width: 1,
        ),
        boxShadow: completed
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
      );

  static BoxDecoration accentCard() => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF211C4D), bg700],
        ),
        border: Border.all(color: borderCopper, width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: copper.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration xpTrack() => BoxDecoration(
        color: bg900.withValues(alpha: 0.62),
        border: Border.all(color: borderBright, width: 0.8),
        borderRadius: BorderRadius.circular(999),
      );

  static BoxDecoration scaffoldBackground() => const BoxDecoration(
        color: bg900,
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.2,
          colors: [
            Color(0xFF203065),
            Color(0xFF101735),
            bg900,
          ],
          stops: [0.0, 0.38, 1.0],
        ),
      );
}
