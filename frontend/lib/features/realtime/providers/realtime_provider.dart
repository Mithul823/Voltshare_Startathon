import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/auth_token_provider.dart';
import '../../admin_dashboard/providers/admin_dashboard_provider.dart';
import '../../ai/providers/ai_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../purchases/data/purchases_repository.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../data/realtime_repository.dart';
import '../domain/realtime_event.dart';

final realtimeRepositoryProvider = Provider<RealtimeRepository>((ref) {
  final repository = RealtimeRepository(
    config: ref.watch(appConfigProvider),
    tokenProvider: ref.watch(authTokenProvider),
  );
  ref.onDispose(repository.disconnect);
  return repository;
});

final webSocketProvider =
    StateNotifierProvider<RealtimeController, AsyncValue<RealtimeEvent?>>((
      ref,
    ) {
      return RealtimeController(ref, ref.read(realtimeRepositoryProvider))
        ..connect();
    });

class RealtimeController extends StateNotifier<AsyncValue<RealtimeEvent?>> {
  RealtimeController(this._ref, this._repository)
    : super(const AsyncValue.data(null));

  final Ref _ref;
  final RealtimeRepository _repository;
  StreamSubscription<RealtimeEvent>? _subscription;

  /// Deduplication: remember recent event IDs to prevent duplicate refreshes.
  final _recentEventIds = Queue<String>();
  static const _maxRecentEvents = 100;

  /// Debounce timer: avoid multiple rapid refreshes of the same provider.
  /// Waits 150ms after the last event before applying batch invalidations.
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 150);

  /// Track which domains have pending invalidations for debounced batch refresh.
  final _pendingRefresh = <String>{};

  Future<void> connect() async {
    state = const AsyncValue.loading();
    await _subscription?.cancel();
    _subscription = _repository.events.listen((event) {
      if (_isDuplicate(event)) return;
      _trackEvent(event);
      state = AsyncValue.data(event);
      _scheduleRefresh(event);
    });
    final connected = await _repository.connect(const [
      'dashboard',
      'marketplace',
      'wallet',
      'notifications',
    ]);
    if (!mounted) return;
    if (!connected) {
      state = const AsyncValue.data(null);
    }
  }

  /// Returns true if we've already seen this event ID recently.
  bool _isDuplicate(RealtimeEvent event) {
    return _recentEventIds.contains(event.id);
  }

  /// Track event ID for deduplication, evicting old entries.
  void _trackEvent(RealtimeEvent event) {
    _recentEventIds.add(event.id);
    while (_recentEventIds.length > _maxRecentEvents) {
      _recentEventIds.removeFirst();
    }
  }

  /// Schedule a debounced refresh for the domains affected by this event type.
  void _scheduleRefresh(RealtimeEvent event) {
    final type = event.type;
    final affected = <String>{};

    // --- Dashboard / energy readings ---
    if (type == 'dashboard.updated' ||
        type == 'energy_reading.created' ||
        type == 'balance.changed' ||
        type.startsWith('wallet.') ||
        type.startsWith('deposit.') ||
        type.startsWith('withdrawal.') ||
        type.startsWith('settlement.') ||
        type.startsWith('refund.') ||
        type.startsWith('purchase.') ||
        type.startsWith('escrow.')) {
      affected.add('dashboard');
    }

    // --- Marketplace listings ---
    if (type.startsWith('listing.')) {
      affected.add('marketplace_listings');
      affected.add('my_listings');
    }

    // --- Purchases ---
    if (type.startsWith('purchase.') ||
        type == 'purchase.refunded' ||
        type.startsWith('escrow.') ||
        type.startsWith('refund.')) {
      affected.add('purchases');
    }

    // --- Wallet & financial ---
    if (type.startsWith('wallet.') ||
        type == 'balance.changed' ||
        type.startsWith('deposit.') ||
        type.startsWith('withdrawal.') ||
        type.startsWith('settlement.') ||
        type.startsWith('refund.') ||
        type.startsWith('purchase.') ||
        type.startsWith('escrow.')) {
      affected.add('wallet');
    }

    // --- Notifications ---
    if (type.startsWith('notification.')) {
      affected.add('notifications');
    }

    // --- AI / insights ---
    if (type.startsWith('forecast.') ||
        type.startsWith('recommendation.') ||
        type == 'sustainability.updated' ||
        type == 'ai_response.completed') {
      affected.add('ai');
    }

    // --- Admin dashboard ---
    if (type.startsWith('user.') ||
        type == 'user.registered' ||
        type.startsWith('listing.') ||
        type.startsWith('purchase.') ||
        type.startsWith('settlement.') ||
        type.startsWith('dispute.') ||
        type.startsWith('refund.') ||
        type.startsWith('grid.') ||
        type.startsWith('anomaly.') ||
        type.startsWith('alert.') ||
        type == 'service_health.changed') {
      affected.add('admin');
    }

    if (affected.isEmpty) return;

    // Debounce: collect affected domains, then refresh after a quiet period
    _pendingRefresh.addAll(affected);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _applyRefresh);
  }

  /// Apply all pending invalidations in batch.
  void _applyRefresh() {
    final domains = Set<String>.from(_pendingRefresh);
    _pendingRefresh.clear();

    for (final domain in domains) {
      switch (domain) {
        case 'dashboard':
          _ref.invalidate(dashboardProvider);
        case 'marketplace_listings':
          _ref.invalidate(marketplaceListingsProvider);
        case 'my_listings':
          _ref.invalidate(myListingsProvider);
        case 'purchases':
          _ref.invalidate(purchasesListProvider);
        case 'wallet':
          _ref.read(walletControllerProvider.notifier).refresh();
        case 'admin':
          _ref.invalidate(adminDashboardProvider);
        case 'notifications':
          _ref.invalidate(notificationsProvider);
          _ref.invalidate(unreadNotificationsProvider);
        case 'ai':
          _ref.invalidate(aiRecommendationsProvider);
          _ref.invalidate(sustainabilityScoreProvider);
          _ref.invalidate(aiForecastProvider);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_repository.disconnect(keepControllerOpen: true));
    super.dispose();
  }
}
