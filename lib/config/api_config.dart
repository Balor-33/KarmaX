/// Central configuration for the KarmaX Flutter app.
///
/// Flutter's responsibility:
///   • Talk to the FastAPI backend (Render)  → [backendBaseUrl]
///   • Talk to Supabase (auth / database)    → [supabaseUrl] + [supabaseAnonKey]
///
/// Flutter's NON-responsibility:
///   • Calling Gemini directly (backend handles that)
///   • Storing any secret keys
class ApiConfig {
  ApiConfig._(); // Prevent instantiation – all members are static.

  /// Production URL of the FastAPI backend deployed on Render.
  /// All AI/Gemini work is delegated here – Flutter never calls Gemini directly.
  ///
  /// ⚠️  Update this to your real Render deployment URL before release.
  ///     Example: "https://karmax-backend.onrender.com"
  static const String backendBaseUrl =
      'https://karmax-backend.onrender.com'; // ← replace with your Render URL

  /// Supabase project URL.
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ufpebjplmbgtlgrfzauw.supabase.co');

  /// Supabase anonymous / publishable key.
  /// This key is intentionally public (row-level security enforces access).
  /// NEVER put the SERVICE ROLE key here.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmcGVianBsbWJndGxncmZ6YXV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwMzkyNTcsImV4cCI6MjA5NzYxNTI1N30.V-wyFNA08Y0vu_Y2Nal5lGUmNPQvOHK1QXmWBSDPWDA');

  static bool get isBackendConfigured => backendBaseUrl.isNotEmpty;
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
