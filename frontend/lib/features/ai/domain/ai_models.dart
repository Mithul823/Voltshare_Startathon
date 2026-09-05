class ForecastPoint {
  const ForecastPoint({
    required this.timestamp,
    required this.value,
    required this.unit,
  });

  final DateTime timestamp;
  final double value;
  final String unit;

  factory ForecastPoint.fromJson(Map<String, Object?> json) {
    return ForecastPoint(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      value: ((json['value'] as num?) ?? 0).toDouble(),
      unit: json['unit']?.toString() ?? '',
    );
  }
}

class ForecastResponse {
  const ForecastResponse({
    required this.metric,
    required this.horizon,
    required this.model,
    required this.confidence,
    required this.dataPointsUsed,
    required this.forecast,
    required this.explanation,
    required this.limitations,
    required this.fallbackUsed,
  });

  final String metric;
  final String horizon;
  final String model;
  final double confidence;
  final int dataPointsUsed;
  final List<ForecastPoint> forecast;
  final String explanation;
  final List<String> limitations;
  final bool fallbackUsed;

  factory ForecastResponse.fromJson(Map<String, Object?> json) {
    return ForecastResponse(
      metric: json['metric']?.toString() ?? '',
      horizon: json['horizon']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      dataPointsUsed:
          ((json['data_points_used'] ?? json['dataPointsUsed']) as num?)
              ?.toInt() ??
          0,
      forecast: [
        for (final item in (json['forecast'] as List? ?? const []))
          ForecastPoint.fromJson((item as Map).cast<String, Object?>()),
      ],
      explanation: json['explanation']?.toString() ?? '',
      limitations: [
        for (final item in (json['limitations'] as List? ?? const []))
          item.toString(),
      ],
      fallbackUsed:
          json['fallback_used'] == true || json['fallbackUsed'] == true,
    );
  }
}

class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.confidence,
    required this.reason,
    this.actionRoute,
    this.dismissed = false,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final String priority;
  final double confidence;
  final String reason;
  final String? actionRoute;
  final bool dismissed;

  factory RecommendationItem.fromJson(Map<String, Object?> json) {
    return RecommendationItem(
      id: json['recommendation_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      reason: json['reason']?.toString() ?? '',
      actionRoute:
          json['action_route']?.toString() ?? json['actionRoute']?.toString(),
      dismissed: json['dismissed'] == true,
    );
  }
}

class SustainabilityScoreModel {
  const SustainabilityScoreModel({
    required this.totalScore,
    required this.grade,
    required this.factorScores,
    required this.improvementActions,
    required this.confidence,
    required this.assumptions,
  });

  final int totalScore;
  final String grade;
  final Map<String, double> factorScores;
  final List<String> improvementActions;
  final double confidence;
  final List<String> assumptions;

  factory SustainabilityScoreModel.fromJson(Map<String, Object?> json) {
    final factors = (json['factor_scores'] ?? json['factorScores']) as Map?;
    return SustainabilityScoreModel(
      totalScore:
          ((json['total_score'] ?? json['totalScore']) as num?)?.toInt() ?? 0,
      grade: json['grade']?.toString() ?? 'Developing',
      factorScores: {
        for (final entry in (factors ?? {}).entries)
          entry.key.toString(): ((entry.value as num?) ?? 0).toDouble(),
      },
      improvementActions: [
        for (final item
            in ((json['improvement_actions'] ?? json['improvementActions'])
                    as List? ??
                const []))
          item.toString(),
      ],
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      assumptions: [
        for (final item in (json['assumptions'] as List? ?? const []))
          item.toString(),
      ],
    );
  }
}

class PricingSuggestionModel {
  const PricingSuggestionModel({
    required this.suggestedPrice,
    required this.minimumPrice,
    required this.maximumPrice,
    required this.marketAverage,
    required this.demandLevel,
    required this.supplyLevel,
    required this.confidence,
    required this.reason,
  });

  final double suggestedPrice;
  final double minimumPrice;
  final double maximumPrice;
  final double marketAverage;
  final String demandLevel;
  final String supplyLevel;
  final double confidence;
  final String reason;

  factory PricingSuggestionModel.fromJson(Map<String, Object?> json) {
    return PricingSuggestionModel(
      suggestedPrice:
          ((json['suggested_price'] ?? json['suggestedPrice']) as num?)
              ?.toDouble() ??
          0,
      minimumPrice:
          ((json['minimum_recommended_price'] ??
                      json['minimumRecommendedPrice'])
                  as num?)
              ?.toDouble() ??
          0,
      maximumPrice:
          ((json['maximum_recommended_price'] ??
                      json['maximumRecommendedPrice'])
                  as num?)
              ?.toDouble() ??
          0,
      marketAverage:
          ((json['current_market_average'] ?? json['currentMarketAverage'])
                  as num?)
              ?.toDouble() ??
          0,
      demandLevel:
          json['demand_level']?.toString() ??
          json['demandLevel']?.toString() ??
          '',
      supplyLevel:
          json['supply_level']?.toString() ??
          json['supplyLevel']?.toString() ??
          '',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class AssistantResponseModel {
  const AssistantResponseModel({
    required this.answer,
    required this.provider,
    required this.confidence,
    required this.disclaimer,
    required this.fallbackUsed,
    this.model,
    this.fallbackReason,
  });

  final String answer;
  final String provider;
  final double confidence;
  final String disclaimer;
  final bool fallbackUsed;
  final String? model;
  final String? fallbackReason;

  factory AssistantResponseModel.fromJson(Map<String, Object?> json) {
    return AssistantResponseModel(
      answer: json['answer']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'fallback',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      disclaimer: json['disclaimer']?.toString() ?? '',
      fallbackUsed:
          json['fallback_used'] == true || json['fallbackUsed'] == true,
      model: json['model']?.toString(),
      fallbackReason:
          json['fallback_reason']?.toString() ?? json['fallbackReason']?.toString(),
    );
  }
}
