enum AiInsightCategory {
  generation,
  battery,
  marketplace,
  consumption,
  sustainability,
}

enum AiInsightPriority { low, medium, high }

class AiInsight {
  const AiInsight({
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    this.actionLabel,
  });

  final String title;
  final String message;
  final AiInsightCategory category;
  final AiInsightPriority priority;
  final String? actionLabel;
}
