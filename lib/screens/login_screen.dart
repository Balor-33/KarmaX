import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../config/supabase_config.dart';
import '../services/player_profile_service.dart';
import '../services/avatar_service.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import 'avatar_selection_screen.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  bool get _canSubmit =>
      _userCtrl.text.trim().isNotEmpty && _passCtrl.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _userCtrl.addListener(_onChanged);
    _passCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _userCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _passCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    if (!SupabaseConfig.isConfigured) {
      _showToast(SupabaseConfig.missingConfigMessage);
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _userCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;

      final destination = await _nextScreenAfterLogin();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } on AuthRetryableFetchException catch (_) {
      _showToast(
        'Connection timed out. Check your internet and try again.',
      );
    } on AuthException catch (e) {
      _showToast(e.message);
    } catch (e) {
      _showToast('Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Widget> _nextScreenAfterLogin() async {
    final profile = await PlayerProfileService().load();

    final user = Supabase.instance.client.auth.currentUser;

    if (profile != null && profile.isComplete) {
      final dashboard = DashboardScreen(
        playerName: profile.playerName,
        goal: profile.goal,
        profession: profile.profession,
      );

      if (user != null) {
        try {
          final progress = await AvatarService().getUserAvatarProgress(user.id);
          final hasAvatar = progress?.selectedAvatarId != null;

          if (!hasAvatar) {
            return _AvatarGate(
              playerName: profile.playerName,
              profession: profile.profession,
              next: dashboard,
            );
          }
        } catch (_) {
        }
      }

      return dashboard;
    }

    final metaName = user?.userMetadata?['display_name']?.toString() ?? '';
    final savedName = profile?.playerName ?? '';
    final initialName = savedName.isNotEmpty ? savedName : metaName;

    return OnboardingScreen(initialName: initialName);
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTheme.monoFont(size: 12)),
        backgroundColor: AppTheme.bg800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg900,
      body: ScanlineOverlay(
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderDim),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 14,
                            color: AppTheme.text100,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'LOGIN',
                        style: AppTheme.displayFont(
                          size: 16,
                          color: AppTheme.text100,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        const GlitchText(
                          text: 'VERIFY\nOPERATOR',
                          fontSize: 30,
                          useDisplay: true,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Provide your credentials to access the KarmaX system.',
                          style: AppTheme.monoFont(
                            size: 13,
                            color: AppTheme.text200,
                          ),
                        ),
                        const SizedBox(height: 34),
                        Text(
                          'EMAIL',
                          style: AppTheme.monoFont(
                            size: 10,
                            color: AppTheme.text400,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _userCtrl,
                          hint: 'e.g. operator@email.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'PASSWORD',
                          style: AppTheme.monoFont(
                            size: 10,
                            color: AppTheme.text400,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _passCtrl,
                          hint: '••••••••',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.bg800,
                            border: Border.all(color: AppTheme.borderDim),
                          ),
                          child: Text(
                            '> STATUS: ${_loading ? 'AUTHENTICATING...' : _canSubmit ? 'READY' : 'INCOMPLETE'}',
                            style: AppTheme.monoFont(
                              size: 11,
                              color: _loading
                                  ? AppTheme.copper
                                  : _canSubmit
                                      ? AppTheme.text100
                                      : AppTheme.text200,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: _SubmitButton(
                    label: _loading ? 'AUTHENTICATING...' : 'ENTER SYSTEM',
                    enabled: _canSubmit && !_loading,
                    onTap: _submit,
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

class _AvatarGate extends StatelessWidget {
  final String playerName;
  final String profession;
  final Widget next;

  const _AvatarGate({
    required this.playerName,
    required this.profession,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarSelectionScreen(
      playerName: playerName,
      profession: profession,
      schedule: '',
      onComplete: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => next,
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      },
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderBright),
        color: AppTheme.bg800,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: AppTheme.monoFont(size: 14, color: AppTheme.text100),
        cursorColor: AppTheme.text100,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.monoFont(size: 14, color: AppTheme.text400),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.copper : AppTheme.bg700,
          border: Border.all(
            color: enabled ? AppTheme.copper : AppTheme.borderDim,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.displayFont(
              size: 13,
              color: enabled ? AppTheme.bg900 : AppTheme.text400,
            ),
          ),
        ),
      ),
    );
  }
}
