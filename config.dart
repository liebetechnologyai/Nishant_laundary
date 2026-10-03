// Provide at build time:
// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=API_URL=...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiUrl = String.fromEnvironment('API_URL');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && apiUrl.isNotEmpty;
}
