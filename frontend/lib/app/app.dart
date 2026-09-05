import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/ai/providers/ai_provider.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/dashboard/providers/dashboard_provider.dart';
import '../features/marketplace/providers/marketplace_provider.dart';
import '../features/realtime/providers/realtime_provider.dart';
import '../features/wallet/providers/wallet_provider.dart';
import 'router.dart';
import 'theme.dart';

class VoltShareApp extends ConsumerWidget {
  const VoltShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentSessionProvider, (previous, next) {
      if (previous?.user.id == next?.user.id &&
          previous?.accessToken == next?.accessToken) {
        return;
      }
      ref.invalidate(currentProfileProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(walletRoleProvider);
      ref.invalidate(walletControllerProvider);
      ref.invalidate(marketplaceRoleProvider);
      ref.invalidate(marketplacePermissionsProvider);
      ref.invalidate(marketplaceListingsProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(latestPurchaseProvider);
      ref.invalidate(aiRecommendationsProvider);
      ref.invalidate(sustainabilityScoreProvider);
      ref.invalidate(aiForecastProvider);
      ref.invalidate(pricingSuggestionProvider);
      ref.invalidate(assistantControllerProvider);
      ref.invalidate(webSocketProvider);
    });

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'VoltShare',
      theme: buildVoltShareTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
