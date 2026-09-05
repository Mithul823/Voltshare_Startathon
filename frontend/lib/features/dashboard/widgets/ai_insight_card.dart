import 'package:flutter/material.dart';

import '../domain/ai_insight.dart';

class AiInsightCard extends StatelessWidget {
  const AiInsightCard({
    required this.insights,
    required this.onAction,
    super.key,
  });

  final List<AiInsight> insights;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final insight in insights.take(3)) ...[
              _InsightRow(insight: insight, onAction: onAction),
              if (insight != insights.take(3).last) const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight, required this.onAction});

  final AiInsight insight;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${insight.title}. ${insight.message}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(insight.message),
          if (insight.actionLabel != null) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: onAction, child: Text(insight.actionLabel!)),
          ],
        ],
      ),
    );
  }

  IconData get _icon {
    return switch (insight.category) {
      AiInsightCategory.generation => Icons.wb_sunny_outlined,
      AiInsightCategory.battery => Icons.battery_charging_full_outlined,
      AiInsightCategory.marketplace => Icons.storefront_outlined,
      AiInsightCategory.consumption => Icons.home_outlined,
      AiInsightCategory.sustainability => Icons.eco_outlined,
    };
  }
}
