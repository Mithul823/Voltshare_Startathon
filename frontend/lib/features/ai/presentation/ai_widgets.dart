import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../domain/ai_models.dart';
import '../providers/ai_provider.dart';

class RoleAiPanel extends ConsumerWidget {
  const RoleAiPanel({required this.roleName, super.key});

  final String roleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = switch (roleName) {
      'producer' => 'generation',
      'prosumer' => 'generation',
      _ => 'consumption',
    };
    final forecast = ref.watch(aiForecastProvider(metric));
    final recommendations = ref.watch(aiRecommendationsProvider);
    final score = ref.watch(sustainabilityScoreProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart guidance',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        forecast.when(
          loading: () => const _AiLoadingCard(label: 'Forecast loading'),
          error: (_, _) => const _AiEmptyCard(
            title: 'Forecast unavailable',
            message:
                'Forecasts will use fallback estimates when enough data is available.',
          ),
          data: (item) => ForecastCard(forecast: item),
        ),
        const SizedBox(height: 10),
        score.when(
          loading: () => const _AiLoadingCard(label: 'Sustainability loading'),
          error: (_, _) => const _AiEmptyCard(
            title: 'Sustainability unavailable',
            message: 'Score could not be loaded right now.',
          ),
          data: (item) => SustainabilityScoreCard(score: item),
        ),
        const SizedBox(height: 10),
        recommendations.when(
          loading: () => const _AiLoadingCard(label: 'Recommendations loading'),
          error: (_, _) => const _AiEmptyCard(
            title: 'Recommendations unavailable',
            message: 'VoltShare could not load AI recommendations.',
          ),
          data: (items) => RecommendationList(items: items.take(2).toList()),
        ),
        const SizedBox(height: 10),
        const AssistantCard(),
      ],
    );
  }
}

class ForecastCard extends StatelessWidget {
  const ForecastCard({required this.forecast, super.key});

  final ForecastResponse forecast;

  @override
  Widget build(BuildContext context) {
    final first = forecast.forecast.isEmpty ? null : forecast.forecast.first;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insights_outlined),
        title: Text('${forecast.metric} forecast'),
        subtitle: Text(
          '${first?.value.toStringAsFixed(2) ?? '--'} ${first?.unit ?? ''} - ${(forecast.confidence * 100).round()}% confidence\n${forecast.explanation}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class SustainabilityScoreCard extends StatelessWidget {
  const SustainabilityScoreCard({required this.score, super.key});

  final SustainabilityScoreModel score;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${score.totalScore}')),
        title: Text('Sustainability: ${score.grade}'),
        subtitle: Text(
          score.improvementActions.isEmpty
              ? 'Keep current energy habits.'
              : score.improvementActions.first,
        ),
      ),
    );
  }
}

class RecommendationList extends ConsumerWidget {
  const RecommendationList({required this.items, super.key});

  final List<RecommendationItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _AiEmptyCard(
        title: 'No recommendations',
        message: 'Recommendations appear when enough context is available.',
      );
    }
    return Column(
      children: [
        for (final item in items)
          Card(
            child: ListTile(
              leading: const Icon(Icons.tips_and_updates_outlined),
              title: Text(item.title),
              subtitle: Text(
                '${item.message}\n${(item.confidence * 100).round()}% confidence',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.check),
                onPressed: () async {
                  await ref
                      .read(aiRepositoryProvider)
                      .dismissRecommendation(item.id);
                  ref.invalidate(aiRecommendationsProvider);
                },
              ),
              onTap: item.actionRoute == null
                  ? null
                  : () => context.push(item.actionRoute!),
            ),
          ),
      ],
    );
  }
}

class AssistantCard extends ConsumerStatefulWidget {
  const AssistantCard({super.key});

  @override
  ConsumerState<AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends ConsumerState<AssistantCard> {
  final _controller = TextEditingController(
    text: 'How can I optimize energy today?',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assistant',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Ask VoltShare AI'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(assistantControllerProvider.notifier)
                        .ask(_controller.text),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Ask'),
            ),
            const SizedBox(height: 8),
            state.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(_assistantErrorMessage(error)),
              data: (response) => response == null
                  ? const Text(
                      'AI guidance is advisory and requires your confirmation.',
                    )
                  : Text('${response.answer}\n${_assistantSourceLabel(response)}'),
            ),
          ],
        ),
      ),
    );
  }

  String _assistantErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return 'Your session has expired. Please sign in again.';
      }
      if (error.statusCode == 403) {
        return 'You do not have permission to use the assistant.';
      }
      if (error.statusCode == 408 || error.code == 'TIMEOUT') {
        return 'The assistant took too long to respond. Please try again.';
      }
      if (error.statusCode == 429) {
        return 'AI request limit reached. Please try again later.';
      }
      if (error.code == 'NETWORK_ERROR') {
        return 'Could not reach the AI service.';
      }
      if (error.code == 'MALFORMED_RESPONSE') {
        return 'The AI service returned an unreadable response.';
      }
      return error.message;
    }
    return 'Could not reach the AI service.';
  }

  String _assistantSourceLabel(AssistantResponseModel response) {
    if (response.fallbackUsed) {
      return 'Rule-based fallback used';
    }
    return response.provider == 'gemini' ? 'Powered by Gemini' : 'AI response';
  }
}

class PricingSuggestionCard extends ConsumerWidget {
  const PricingSuggestionCard({required this.quantityKwh, super.key});

  final double quantityKwh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(pricingSuggestionProvider(quantityKwh));
    return suggestion.when(
      loading: () => const _AiLoadingCard(label: 'Pricing suggestion loading'),
      error: (_, _) => const _AiEmptyCard(
        title: 'Pricing suggestion unavailable',
        message: 'Use current market price and confirm manually.',
      ),
      data: (item) => Card(
        child: ListTile(
          leading: const Icon(Icons.price_check_outlined),
          title: Text(
            'Suggested price Rs ${item.suggestedPrice.toStringAsFixed(2)}/kWh',
          ),
          subtitle: Text(
            '${item.reason}\nRange Rs ${item.minimumPrice.toStringAsFixed(2)} - Rs ${item.maximumPrice.toStringAsFixed(2)}',
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}

class _AiLoadingCard extends StatelessWidget {
  const _AiLoadingCard({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircularProgressIndicator(),
      title: Text(label),
    ),
  );
}

class _AiEmptyCard extends StatelessWidget {
  const _AiEmptyCard({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(title),
      subtitle: Text(message),
    ),
  );
}
