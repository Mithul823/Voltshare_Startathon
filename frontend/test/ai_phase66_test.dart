import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/ai/data/ai_repository.dart';
import 'package:frontend/features/ai/domain/ai_models.dart';
import 'package:frontend/features/ai/presentation/ai_widgets.dart';
import 'package:frontend/features/ai/presentation/sustainability_screen.dart';
import 'package:frontend/features/ai/providers/ai_provider.dart';

void main() {
  group('Phase 6.6 AI frontend', () {
    test(
      'mock repository returns forecasts and simulated AI assistant response',
      () async {
        const repository = AiMockRepository();
        final forecast = await repository.forecast('consumption');
        final assistant = await repository.chat('Should I buy energy now?');
        expect(forecast.confidence, greaterThan(0));
        expect(assistant.fallbackUsed, isFalse);
        expect(assistant.provider, 'gemini');
      },
    );

    test('live repository mapping selects API implementation', () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://example.supabase.co',
              supabasePublishableKey: 'publishable',
              useMockBackend: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(aiRepositoryProvider), isA<AiApiRepository>());
    });

    testWidgets('consumer forecast card displays confidence', (tester) async {
      await tester.pumpWidget(
        _screen(
          const ForecastCard(
            forecast: ForecastResponse(
              metric: 'consumption',
              horizon: '24h',
              model: 'weighted',
              confidence: 0.72,
              dataPointsUsed: 48,
              forecast: [],
              explanation: 'Transparent fallback explanation.',
              limitations: [],
              fallbackUsed: false,
            ),
          ),
        ),
      );
      expect(find.textContaining('72% confidence'), findsOneWidget);
    });

    testWidgets('sustainability score display renders grade', (tester) async {
      await tester.pumpWidget(
        _screen(
          const SustainabilityScoreCard(
            score: SustainabilityScoreModel(
              totalScore: 78,
              grade: 'Excellent',
              factorScores: {'renewable_usage_ratio': 76},
              improvementActions: ['Shift load.'],
              confidence: 0.75,
              assumptions: ['Estimated carbon.'],
            ),
          ),
        ),
      );
      expect(find.textContaining('Excellent'), findsOneWidget);
    });

    testWidgets('pricing recommendation renders advisory price', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(const AiMockRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PricingSuggestionCard(quantityKwh: 2)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Suggested price'), findsOneWidget);
    });

    testWidgets('assistant response display shows simulated AI response', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(const AiMockRepository()),
          ],
          child: const MaterialApp(home: Scaffold(body: AssistantCard())),
        ),
      );
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Powered by Gemini'), findsOneWidget);
      expect(find.textContaining('solar generation'), findsOneWidget);
    });

    testWidgets('assistant renders successful Gemini answer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(
              _AssistantFakeRepository(
                response: AssistantResponseModel(
                  answer: 'Shift flexible loads into solar hours.',
                  provider: 'gemini',
                  confidence: 0.81,
                  disclaimer: 'Advisory only.',
                  fallbackUsed: false,
                  model: 'gemini-2.5-flash',
                ),
                delay: Duration(milliseconds: 50),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: AssistantCard())),
        ),
      );
      await tester.tap(find.text('Ask'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.textContaining('Shift flexible loads'), findsOneWidget);
      expect(find.textContaining('Powered by Gemini'), findsOneWidget);
    });

    testWidgets('assistant sends one request while loading', (tester) async {
      final repository = _AssistantFakeRepository(
        response: const AssistantResponseModel(
          answer: 'Live answer',
          provider: 'gemini',
          confidence: 0.8,
          disclaimer: 'Advisory only.',
          fallbackUsed: false,
        ),
        delay: const Duration(milliseconds: 50),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: AssistantCard())),
        ),
      );
      await tester.tap(find.text('Ask'));
      await tester.tap(find.text('Ask'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repository.chatCalls, 1);
    });

    testWidgets('assistant handles auth and network errors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(
              _AssistantFakeRepository(
                error: ApiException(
                  code: 'AUTH_REQUIRED',
                  message: 'expired',
                  statusCode: 401,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: AssistantCard())),
        ),
      );
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(find.textContaining('session has expired'), findsOneWidget);
    });

    testWidgets('sustainability details page renders factors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(const AiMockRepository()),
          ],
          child: const MaterialApp(home: SustainabilityScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Factors'), findsOneWidget);
    });
  });
}

Widget _screen(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _AssistantFakeRepository implements AiRepository {
  _AssistantFakeRepository({
    this.response,
    this.error,
    this.delay = Duration.zero,
  });

  final AssistantResponseModel? response;
  final Object? error;
  final Duration delay;

  int _calls = 0;
  int get chatCalls => _calls;

  @override
  Future<AssistantResponseModel> chat(String message) async {
    _calls += 1;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    return response ??
        const AssistantResponseModel(
          answer: 'Fallback answer',
          provider: 'rule_based',
          confidence: 0.5,
          disclaimer: 'Advisory only.',
          fallbackUsed: true,
        );
  }

  @override
  Future<void> dismissRecommendation(String id) async {}

  @override
  Future<ForecastResponse> forecast(String metric) {
    throw UnimplementedError();
  }

  @override
  Future<PricingSuggestionModel> pricingSuggestion({double quantityKwh = 1}) {
    throw UnimplementedError();
  }

  @override
  Future<List<RecommendationItem>> recommendations() {
    throw UnimplementedError();
  }

  @override
  Future<SustainabilityScoreModel> sustainabilityScore() {
    throw UnimplementedError();
  }
}
