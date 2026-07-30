import 'api_config.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String _urlDefine =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _anonKeyDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String _projectRefDefine =
      String.fromEnvironment('SUPABASE_PROJECT_REF', defaultValue: '');

  static String get anonKey {
    final v = _anonKeyDefine.trim();
    if (v.isNotEmpty) return v;
    // Fall back to ApiConfig (which may also be populated via dart-define)
    return ApiConfig.supabaseAnonKey.trim();
  }

  static String get url {
    final v = _urlDefine.trim();
    if (v.isNotEmpty) return _normalizeUrl(v);
    final fromApi = ApiConfig.supabaseUrl.trim();
    if (fromApi.isNotEmpty) return _normalizeUrl(fromApi);
    return '';
  }

  static String get projectRef => _projectRefDefine.trim();

  static String get resolvedUrl {
    if (url.isNotEmpty) return url;
    if (projectRef.isNotEmpty) return 'https://$projectRef.supabase.co';
    return '';
  }

  static bool get isConfigured => resolvedUrl.isNotEmpty && anonKey.isNotEmpty;

  static String get missingConfigMessage =>
      'Supabase is not configured.\n'
      'Run with:\n'
      '  flutter run \\\n'
      '    --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
      '    --dart-define=SUPABASE_ANON_KEY=eyJ...\n'
      'Or set them in your CI/CD secrets and pass them at build time.';

  static String _normalizeUrl(String input) {
    final trimmed = input.trim();

    // Handle dashboard URL paste: https://supabase.com/dashboard/project/<ref>
    const marker = '/dashboard/project/';
    final idx = trimmed.indexOf(marker);
    if (idx != -1) {
      final ref = trimmed.substring(idx + marker.length).split('/').first;
      if (ref.isNotEmpty) return 'https://$ref.supabase.co';
    }

    // Handle bare project ref (20-char alphanumeric)
    if (RegExp(r'^[a-z0-9]{20}$').hasMatch(trimmed)) {
      return 'https://$trimmed.supabase.co';
    }

    return trimmed;
  }
}
