import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  void _goTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'KARMAX',
                  style: AppTheme.displayFont(size: 14, color: AppTheme.text200),
                ),
                const SizedBox(height: 10),
                Text(
                  '// AUTH REQUIRED',
                  style: AppTheme.monoFont(
                    size: 10,
                    color: AppTheme.text400,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 18),
                const GlitchText(
                  text: 'CHOOSE\nACCESS',
                  fontSize: 34,
                  useDisplay: true,
                ),
                const SizedBox(height: 10),
                Text(
                  'Log in to continue, or create a new operator profile.',
                  style: AppTheme.monoFont(size: 13, color: AppTheme.text200),
                ),
                const SizedBox(height: 38),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bg800,
                    border: Border.all(color: AppTheme.borderBright),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '> CONNECTION: STANDBY',
                        style: AppTheme.monoFont(
                          size: 11,
                          color: AppTheme.text100,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '> SESSION: UNVERIFIED',
                        style: AppTheme.monoFont(
                          size: 11,
                          color: AppTheme.text200,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _PrimaryButton(
                  label: 'LOGIN',
                  onTap: () => _goTo(context, const LoginScreen()),
                ),
                const SizedBox(height: 12),
                _SecondaryButton(
                  label: 'SIGN UP',
                  onTap: () => _goTo(context, const SignupScreen()),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'BY CONTINUING YOU ACCEPT SYSTEM TERMS',
                    style: AppTheme.monoFont(
                      size: 9,
                      color: AppTheme.text400,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            label,
            style: AppTheme.displayFont(size: 13, color: AppTheme.bg900),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SecondaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.bg800,
          border: Border.all(color: AppTheme.borderBright),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.displayFont(size: 13, color: AppTheme.text100),
          ),
        ),
      ),
    );
  }
}
