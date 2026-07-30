import 'package:flutter/foundation.dart';
import 'api_config.dart';

/// Thin wrapper kept for backward-compatibility with existing call-sites.
/// New code should import [ApiConfig] directly.
class AiConfig {
  AiConfig._();

  /// Base URL of the FastAPI backend.
  /// Resolves to localhost variants during local development if the env var is unset.
  static String get backendUrl {
    // In production the backendBaseUrl constant is set to the Render URL.
    if (ApiConfig.backendBaseUrl.isNotEmpty &&
        !ApiConfig.backendBaseUrl.contains('localhost') &&
        !ApiConfig.backendBaseUrl.contains('127.0.0.1') &&
        !ApiConfig.backendBaseUrl.contains('10.0.2.2')) {
      return ApiConfig.backendBaseUrl;
    }
    // Local development fallback.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // Android emulator → host machine
    }
    return 'http://127.0.0.1:8000'; // iOS simulator / desktop / web
  }

  /// Always true – the backend (not Flutter) checks for the Gemini key.
  static bool get isConfigured => true;

}
