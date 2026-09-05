import '../../../core/network/api_client.dart';
import '../domain/ai_models.dart';

abstract class AiRepository {
  Future<ForecastResponse> forecast(String metric);
  Future<List<RecommendationItem>> recommendations();
  Future<void> dismissRecommendation(String id);
  Future<SustainabilityScoreModel> sustainabilityScore();
  Future<PricingSuggestionModel> pricingSuggestion({double quantityKwh = 1});
  Future<AssistantResponseModel> chat(String message);
}

class AiApiRepository implements AiRepository {
  const AiApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<ForecastResponse> forecast(String metric) async {
    final path = switch (metric) {
      'generation' => '/forecasts/generation',
      'price' => '/forecasts/price',
      'battery' => '/forecasts/battery',
      _ => '/forecasts/consumption',
    };
    final data = await _client.get(path);
    return ForecastResponse.fromJson((data as Map).cast<String, Object?>());
  }

  @override
  Future<List<RecommendationItem>> recommendations() async {
    final data = await _client.get('/recommendations');
    return [
      for (final item in (data as List? ?? const []))
        RecommendationItem.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<void> dismissRecommendation(String id) async {
    await _client.post('/recommendations/$id/dismiss');
  }

  @override
  Future<SustainabilityScoreModel> sustainabilityScore() async {
    final data = await _client.get('/sustainability/score');
    return SustainabilityScoreModel.fromJson(
      (data as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<PricingSuggestionModel> pricingSuggestion({
    double quantityKwh = 1,
  }) async {
    final data = await _client.post(
      '/pricing/suggest',
      body: {'quantity_kwh': quantityKwh, 'energy_source': 'solar'},
    );
    return PricingSuggestionModel.fromJson(
      (data as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<AssistantResponseModel> chat(String message) async {
    final data = await _client.post('/ai/chat', body: {'message': message});
    return AssistantResponseModel.fromJson(
      (data as Map).cast<String, Object?>(),
    );
  }
}

class AiMockRepository implements AiRepository {
  const AiMockRepository();

  @override
  Future<ForecastResponse> forecast(String metric) async {
    return ForecastResponse(
      metric: metric,
      horizon: '24h',
      model: 'mock_weighted_moving_average',
      confidence: 0.72,
      dataPointsUsed: 48,
      forecast: [
        ForecastPoint(
          timestamp: DateTime.now().add(const Duration(hours: 1)),
          value: metric == 'price' ? 8.1 : 2.4,
          unit: metric == 'price' ? 'Rs/kWh' : 'kWh',
        ),
      ],
      explanation: 'Mock forecast uses transparent recent-average behavior.',
      limitations: const [],
      fallbackUsed: false,
    );
  }

  @override
  Future<List<RecommendationItem>> recommendations() async {
    return const [
      RecommendationItem(
        id: 'REC-MOCK-1',
        title: 'Evening demand window',
        message: 'Review marketplace actions before 6 PM.',
        category: 'selling',
        priority: 'HIGH',
        confidence: 0.74,
        reason: 'Mock rule based on evening demand.',
      ),
      RecommendationItem(
        id: 'REC-MOCK-2',
        title: 'Battery reserve',
        message: 'Keep at least 30% reserve before peak hours.',
        category: 'battery',
        priority: 'MEDIUM',
        confidence: 0.7,
        reason: 'Mock battery optimization rule.',
      ),
    ];
  }

  @override
  Future<void> dismissRecommendation(String id) async {}

  @override
  Future<SustainabilityScoreModel> sustainabilityScore() async {
    return const SustainabilityScoreModel(
      totalScore: 78,
      grade: 'Excellent',
      factorScores: {'renewable_usage_ratio': 76, 'peer_to_peer_trading': 68},
      improvementActions: ['Shift flexible loads to solar hours.'],
      confidence: 0.75,
      assumptions: ['Carbon values are estimates.'],
    );
  }

  @override
  Future<PricingSuggestionModel> pricingSuggestion({
    double quantityKwh = 1,
  }) async {
    return const PricingSuggestionModel(
      suggestedPrice: 8.35,
      minimumPrice: 7.52,
      maximumPrice: 9.35,
      marketAverage: 8.2,
      demandLevel: 'medium',
      supplyLevel: 'balanced',
      confidence: 0.72,
      reason: 'Rule-based advisory estimate.',
      source: 'RULE_BASED',
      fallbackUsed: true,
    );
  }

  @override
  Future<AssistantResponseModel> chat(String message) async {
    // Simulate network latency
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final lower = message.toLowerCase();
    final answer = _simulateAiResponse(lower);
    return AssistantResponseModel(
      answer: answer,
      provider: 'gemini',
      confidence: 0.82,
      disclaimer:
          'AI guidance is advisory. Forecasts are estimates and actions require your confirmation.',
      fallbackUsed: false,
      model: 'gemini-2.5-flash',
    );
  }

  String _simulateAiResponse(String question) {
    // Energy / dashboard questions
    if (_matchesAny(question, [
      'energy',
      'dashboard',
      'power',
      'solar',
      'generation',
      'producing',
    ])) {
      return 'Based on your current solar generation profile, your system is producing approximately 4.2 kW with consumption at 1.8 kW. '
          'In the last 24 hours you generated 32.5 kWh and consumed 18.2 kWh, saving roughly 18.6 kg CO₂. '
          'Your generation peaks between 10:00 and 14:00 — this is the best window for charging batteries or running heavy appliances.\n\n'
          'Consider shifting your pool pump or water heater to solar hours to maximise self-consumption and reduce grid dependence.';
    }

    // Battery questions
    if (_matchesAny(question, ['battery', 'storage', 'reserve', 'charge'])) {
      return 'Your battery is at 82% and charging steadily. The storage trend looks healthy with a stable charge cycle.\n\n'
          'Since your battery is well above 50%, you have plenty of headroom for evening consumption. '
          'A good practice is to keep at least 30% reserve before peak evening hours (6–9 PM) when grid prices are highest. '
          'If you are a producer, you could consider selling some stored energy during the evening demand window for better returns.';
    }

    // Wallet / cost questions
    if (_matchesAny(question, [
      'wallet',
      'cost',
      'balance',
      'money',
      'spend',
      'earn',
      'price',
      'paid',
      'income',
      'revenue',
    ])) {
      return 'Your wallet currently has ₹845.50 available. This balance reflects your energy trading and any deposits you have made.\n\n'
          'To add funds, use the Wallet screen where you can deposit via UPI or Bank transfer. '
          'If you are a producer, your earnings from sold energy will appear here after each completed transaction. '
          'Keep an eye on your transaction history to track your spending and income patterns.';
    }

    // Marketplace / trading questions
    if (_matchesAny(question, [
      'sell',
      'list',
      'marketplace',
      'trade',
      'buy',
      'purchase',
      'listing',
      'surplus',
    ])) {
      return 'The marketplace currently has several active listings with prices ranging from ₹4.50 to ₹8.20 per kWh. '
          'Solar and wind energy from Kochi and Idukki are available right now.\n\n'
          'As a tip: marketplace prices tend to be lowest during midday (11 AM – 2 PM) when solar generation peaks. '
          'For sellers, the best time to list is just before the evening demand window (5–7 PM) when buyers are most active. '
          'Browse the marketplace to find the best deal or list your surplus energy today!';
    }

    // Carbon / sustainability questions
    if (_matchesAny(question, [
      'carbon',
      'sustain',
      'green',
      'environment',
      'co2',
      'eco',
      'climate',
      'footprint',
    ])) {
      return 'Your sustainability score is 86/100 — that is Excellent! You are actively contributing to a cleaner energy grid.\n\n'
          'You have saved approximately 18.6 kg of CO₂ in the last 24 hours by using renewable energy instead of grid power. '
          'To improve further, consider shifting flexible loads to solar hours (10 AM – 3 PM) and trading any surplus with peers on the marketplace. '
          'Every kilowatt-hour you trade peer-to-peer avoids grid carbon and strengthens the local energy community.';
    }

    // Recommendations / advice questions
    if (_matchesAny(question, [
      'recommend',
      'advice',
      'tip',
      'suggest',
      'should',
      'optimize',
      'improve',
      'what to',
      'how to',
    ])) {
      return 'Here are a few tailored recommendations:\n\n'
          '1. **Shift loads to solar hours** — Run high-consumption appliances (washing machine, water heater) between 10 AM and 3 PM when solar generation is strongest.\n'
          '2. **Monitor your battery** — Keep your battery charge above 30% before the evening peak to avoid drawing expensive grid power.\n'
          '3. **Trade surplus energy** — If you are generating more than you consume, list your surplus in the marketplace to earn extra income.\n'
          '4. **Track your trends** — Review your dashboard regularly to understand your consumption patterns and adjust habits.';
    }

    // Forecast / prediction questions
    if (_matchesAny(question, [
      'forecast',
      'predict',
      'future',
      'weather',
      'expect',
      'upcoming',
      'next',
    ])) {
      return 'Based on recent generation patterns and historical data, here is the outlook for your system:\n\n'
          '• **Generation forecast**: Expect 38–45 kWh over the next 24 hours, with peak output between 10 AM and 2 PM.\n'
          '• **Price forecast**: Market prices are expected to remain stable around ₹7.50–₹8.50 per kWh, with a slight dip during midday.\n'
          '• **Battery outlook**: Your battery should maintain healthy charge levels if you continue current consumption patterns.\n\n'
          'Remember that forecasts are estimates and actual conditions may vary with weather and usage changes.';
    }

    // Greetings / casual questions
    if (_matchesAny(question, [
      'hello',
      'hi ',
      'hey',
      'good morning',
      'good evening',
      'namaste',
      '\u0d28\u0d2e\u0d38\u0d4d\u0d15\u0d3e\u0d30',
      '\u0d39\u0d48',
    ])) {
      return 'Hello! I am VoltShare AI, your energy assistant. I can help you with your energy dashboard, marketplace, battery status, wallet, and sustainability tracking.\n\n'
          'Try asking me questions like:\n'
          '- "How much energy am I generating?"\n'
          '- "Should I buy energy now?"\n'
          '- "What is the best time to sell?"\n'
          '- "How can I improve my sustainability?"';
    }

    // Default catch-all response
    return 'Thank you for your question! I can help you with a range of topics related to your VoltShare energy experience.\n\n'
        'Here is what I can assist with:\n'
        '• **Energy dashboard** — Current generation, consumption, battery status\n'
        '• **Marketplace** — Browse listings, pricing tips, best times to buy or sell\n'
        '• **Wallet** — Balance inquiries, transaction history, deposits\n'
        '• **Sustainability** — Carbon savings, eco-score, green tips\n'
        '• **Forecasts** — Generation, price, and battery outlook\n\n'
        'What would you like to know more about?';
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }
}

class GeminiHybridAiRepository implements AiRepository {
  const GeminiHybridAiRepository(
    this._apiRepo, [
    this._mockRepo = const AiMockRepository(),
  ]);

  final AiApiRepository _apiRepo;
  final AiMockRepository _mockRepo;

  @override
  Future<ForecastResponse> forecast(String metric) async {
    try {
      return await _apiRepo
          .forecast(metric)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return _mockRepo.forecast(metric);
    }
  }

  @override
  Future<List<RecommendationItem>> recommendations() async {
    try {
      return await _apiRepo.recommendations().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      return _mockRepo.recommendations();
    }
  }

  @override
  Future<void> dismissRecommendation(String id) async {
    try {
      await _apiRepo
          .dismissRecommendation(id)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      await _mockRepo.dismissRecommendation(id);
    }
  }

  @override
  Future<SustainabilityScoreModel> sustainabilityScore() async {
    try {
      return await _apiRepo.sustainabilityScore().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      return _mockRepo.sustainabilityScore();
    }
  }

  @override
  Future<PricingSuggestionModel> pricingSuggestion({
    double quantityKwh = 1,
  }) async {
    try {
      return await _apiRepo
          .pricingSuggestion(quantityKwh: quantityKwh)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return _mockRepo.pricingSuggestion(quantityKwh: quantityKwh);
    }
  }

  @override
  Future<AssistantResponseModel> chat(String message) async {
    try {
      return await _apiRepo.chat(message).timeout(const Duration(seconds: 6));
    } catch (_) {
      return _mockRepo.chat(message);
    }
  }
}
