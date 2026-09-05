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
    this.eventServerUrl = '',
    this.aiMode = 'gemini',
    this.smartMeterBaseUrl =
        'https://startathon-voltshare-smartmeter.onrender.com',
    this.smartMeterProducerPath = '/meter-metrics/producer',
    this.meterProvider = 'external_api',
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      eventServerUrl: String.fromEnvironment('EVENT_SERVER_URL'),
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
      aiMode: String.fromEnvironment('AI_MODE', defaultValue: 'gemini'),
      smartMeterBaseUrl: String.fromEnvironment(
        'SMART_METER_BASE_URL',
        defaultValue: 'https://startathon-voltshare-smartmeter.onrender.com',
      ),
      smartMeterProducerPath: String.fromEnvironment(
        'SMART_METER_PRODUCER_PATH',
        defaultValue: '/meter-metrics/producer',
      ),
      meterProvider: String.fromEnvironment(
        'METER_PROVIDER',
        defaultValue: 'external_api',
      ),
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String apiBaseUrl;
  final bool useMockBackend;
  final String eventServerUrl;
  final String aiMode;
  final String smartMeterBaseUrl;
  final String smartMeterProducerPath;
  final String meterProvider;

  bool get isSupabaseConfigured {
    return supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  }

  bool get isMockMode => useMockBackend;

  bool get isLiveMode => !useMockBackend;

  bool get isAiEnabled => aiMode.toLowerCase() != 'disabled';

  bool get isGeminiAiMode => aiMode.toLowerCase() == 'gemini';

  bool get isExternalMeterProvider =>
      meterProvider.toLowerCase() == 'external_api';
}
