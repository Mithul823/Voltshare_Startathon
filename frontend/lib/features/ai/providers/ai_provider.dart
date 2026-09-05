import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../realtime/providers/realtime_provider.dart';
import '../data/ai_repository.dart';
import '../domain/ai_models.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  if (ref.watch(appConfigProvider).isMockMode) {
    return const AiMockRepository();
  }
  return AiApiRepository(ref.watch(apiClientProvider));
});

final aiRecommendationsProvider = FutureProvider<List<RecommendationItem>>((
  ref,
) {
  ref.listen(webSocketProvider, (_, next) {
    final type = next.valueOrNull?.type;
    if (type == 'recommendation.created' || type == 'recommendation.updated') {
      ref.invalidateSelf();
    }
  });
  return ref.watch(aiRepositoryProvider).recommendations();
});

final sustainabilityScoreProvider = FutureProvider<SustainabilityScoreModel>((
  ref,
) {
  ref.listen(webSocketProvider, (_, next) {
    if (next.valueOrNull?.type == 'sustainability.updated') {
      ref.invalidateSelf();
    }
  });
  return ref.watch(aiRepositoryProvider).sustainabilityScore();
});

final aiForecastProvider = FutureProvider.family<ForecastResponse, String>((
  ref,
  metric,
) {
  ref.listen(webSocketProvider, (_, next) {
    if (next.valueOrNull?.type == 'forecast.updated') {
      ref.invalidateSelf();
    }
  });
  return ref.watch(aiRepositoryProvider).forecast(metric);
});

final pricingSuggestionProvider =
    FutureProvider.family<PricingSuggestionModel, double>((ref, quantityKwh) {
      return ref
          .watch(aiRepositoryProvider)
          .pricingSuggestion(quantityKwh: quantityKwh);
    });

final assistantControllerProvider =
    StateNotifierProvider<
      AssistantController,
      AsyncValue<AssistantResponseModel?>
    >((ref) {
      return AssistantController(ref);
    });

class AssistantController
    extends StateNotifier<AsyncValue<AssistantResponseModel?>> {
  AssistantController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> ask(String message) async {
    if (state.isLoading) {
      return;
    }
    final question = message.trim();
    if (question.isEmpty) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _ref.read(aiRepositoryProvider).chat(question),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
