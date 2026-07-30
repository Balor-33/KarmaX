import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../config/supabase_config.dart';
import '../services/player_profile_service.dart';
import '../widgets/glitch_text.dart';
import '../widgets/scanline_overlay.dart';
import 'onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  bool _verifying = false;
  bool _resending = false;

  bool _showVerify = false;
  String _pendingEmail = '';
  String _pendingDisplayName = '';

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  bool get _canSubmit {
    final pass = _passCtrl.text;
    return _nameCtrl.text.trim().isNotEmpty &&
        _emailCtrl.text.trim().isNotEmpty &&
        pass.isNotEmpty &&
        _confirmCtrl.text.isNotEmpty &&
        pass == _confirmCtrl.text;
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _nameCtrl.addListener(_onChanged);
    _emailCtrl.addListener(_onChanged);
    _passCtrl.addListener(_onChanged);
    _confirmCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _emailCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _passCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _confirmCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _codeCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    if (!SupabaseConfig.isConfigured) {
      _showToast(SupabaseConfig.missingConfigMessage);
      return;
    }

    final displayName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      if (!mounted) return;

      final user = res.user;

      if (user == null) {
        _showToast('Signup failed. Please try again.');
        return;
      }

      final identities = user.identities;
      final isNewUser = identities != null && identities.isNotEmpty;

      if (!isNewUser) {
        _showToast(
            'An account with this email already exists. Try logging in.');
        return;
      }

      await PlayerProfileService().clear();
      if (!mounted) return;
      setState(() {
        _pendingEmail = email;
        _pendingDisplayName = displayName;
        _showVerify = true;
      });
    } on AuthRetryableFetchException catch (_) {
      _showToast('Connection timed out. Check your internet and try again.');
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('already been registered') ||
          msg.contains('user already exists')) {
        _showToast(
            'An account with this email already exists. Try logging in.');
      } else if (msg.contains('confirmation email') ||
          msg.contains('sending email')) {
        if (!mounted) return;
        _showToast(
            'Account created, but sending the code failed. Try resending it.');
        setState(() {
          _pendingEmail = email;
          _pendingDisplayName = displayName;
          _showVerify = true;
        });
      } else {
        _showToast(e.message);
      }
    } catch (e) {
      _showToast('Signup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _verifying) return;

    setState(() => _verifying = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _pendingEmail,
        token: code,
        type: OtpType.email,
      );

      if (!mounted) return;
      _goToOnboarding(_pendingDisplayName);
    } on AuthException catch (e) {
      _showToast(e.message);
    } catch (e) {
      _showToast('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _pendingEmail,
      );
      _showToast('Code resent.');
    } on AuthException catch (e) {
      _showToast(e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _goToOnboarding(String displayName) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OnboardingScreen(initialName: displayName),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
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
    final passwordsMatch = _passCtrl.text.isEmpty && _confirmCtrl.text.isEmpty
        ? true
        : _passCtrl.text == _confirmCtrl.text;

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
                        onTap: () {
                          if (_showVerify) {
                            setState(() => _showVerify = false);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
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
                        _showVerify ? 'VERIFY EMAIL' : 'SIGN UP',
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
                    child: _showVerify
                        ? _buildVerifyForm()
                        : _buildSignupForm(passwordsMatch),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: _showVerify
                      ? _SubmitButton(
                          label: _verifying ? 'VERIFYING...' : 'VERIFY',
                          enabled: !_verifying,
                          onTap: _verifyCode,
                        )
                      : _SubmitButton(
                          label: _loading ? 'REGISTERING...' : 'REGISTER',
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

  Widget _buildSignupForm(bool passwordsMatch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const GlitchText(
          text: 'CREATE\nOPERATOR',
          fontSize: 30,
          useDisplay: true,
        ),
        const SizedBox(height: 10),
        Text(
          'Register a new profile to enter the KarmaX system.',
          style: AppTheme.monoFont(
            size: 13,
            color: AppTheme.text200,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'DISPLAY NAME',
          style: AppTheme.monoFont(
            size: 10,
            color: AppTheme.text400,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        _InputField(
          controller: _nameCtrl,
          hint: 'e.g. ALEX_99',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
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
          controller: _emailCtrl,
          hint: 'e.g. alex@email.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
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
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 18),
        Text(
          'CONFIRM PASSWORD',
          style: AppTheme.monoFont(
            size: 10,
            color: AppTheme.text400,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        _InputField(
          controller: _confirmCtrl,
          hint: '••••••••',
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 14),
        if (!passwordsMatch)
          Text(
            '> PASSWORDS DO NOT MATCH',
            style: AppTheme.monoFont(
              size: 11,
              color: AppTheme.copper,
              letterSpacing: 1,
            ),
          ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bg800,
            border: Border.all(color: AppTheme.borderDim),
          ),
          child: Text(
            '> STATUS: ${_loading ? 'CREATING PROFILE...' : _canSubmit ? 'READY' : 'INCOMPLETE'}',
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
    );
  }

  Widget _buildVerifyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const GlitchText(
          text: 'VERIFY\nEMAIL',
          fontSize: 30,
          useDisplay: true,
        ),
        const SizedBox(height: 10),
        Text(
          'Enter the code sent to $_pendingEmail',
          style: AppTheme.monoFont(size: 13, color: AppTheme.text200),
        ),
        const SizedBox(height: 30),
        Text(
          'VERIFICATION CODE',
          style: AppTheme.monoFont(
            size: 10,
            color: AppTheme.text400,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderBright),
            color: AppTheme.bg800,
          ),
          child: TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: AppTheme.monoFont(
                size: 22, color: AppTheme.text100, letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: '000000',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 18),
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: _resending ? null : _resendCode,
            child: Text(
              _resending ? 'RESENDING...' : 'RESEND CODE',
              style: AppTheme.monoFont(
                  size: 11, color: AppTheme.text400, letterSpacing: 2),
            ),
          ),
        ),
      ],
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
