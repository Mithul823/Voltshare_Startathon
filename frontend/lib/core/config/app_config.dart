import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.apiBaseUrl = 'http://10.0.2.2:8000/api/v1',
    this.useMockBackend = false,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000/api/v1',
      ),
      useMockBackend: bool.fromEnvironment(
        'USE_MOCK_BACKEND',
        defaultValue: false,
      ),
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String apiBaseUrl;
  final bool useMockBackend;

  bool get isSupabaseConfigured {
    return supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  }

  bool get isMockMode => useMockBackend;

  bool get isLiveMode => !useMockBackend;
}
