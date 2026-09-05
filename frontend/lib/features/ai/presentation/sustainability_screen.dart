import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../providers/ai_provider.dart';
import 'ai_widgets.dart';

class SustainabilityScreen extends ConsumerWidget {
  const SustainabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(sustainabilityScoreProvider);
    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Sustainability',
              fallbackRoute: AppRoutes.dashboard,
            ),
            const SizedBox(height: 16),
            score.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Sustainability unavailable'),
                  subtitle: Text(
                    'Carbon and score estimates will appear when backend data is available.',
                  ),
                ),
              ),
              data: (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SustainabilityScoreCard(score: item),
                  const SizedBox(height: 12),
                  Text(
                    'Factors',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in item.factorScores.entries)
                    ListTile(
                      leading: const Icon(Icons.eco_outlined),
                      title: Text(entry.key.replaceAll('_', ' ')),
                      trailing: Text(entry.value.toStringAsFixed(0)),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Assumptions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final assumption in item.assumptions) Text(assumption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
