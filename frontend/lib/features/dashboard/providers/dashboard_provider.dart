import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/dashboard_api_repository.dart';
import '../data/dashboard_mock_repository.dart';
import '../domain/dashboard_snapshot.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return DashboardApiRepository(ref.watch(apiClientProvider));
  }
  return DashboardMockRepository();
});

final dashboardProvider =
    StateNotifierProvider.autoDispose<
      DashboardNotifier,
      AsyncValue<DashboardSnapshot?>
    >((ref) {
      final isMockMode = ref.watch(appConfigProvider).isMockMode;
      final notifier = DashboardNotifier(
        ref.watch(dashboardRepositoryProvider),
        updateInterval: isMockMode
            ? const Duration(seconds: 4)
            : const Duration(seconds: 30),
      );
      notifier.load();
      return notifier;
    });

/// Distinguishes dashboard errors so the UI can show specific messages.
sealed class DashboardError {
  const DashboardError();
  String get userMessage;
}

class AuthError extends DashboardError {
  const AuthError();
  @override
  String get userMessage => 'Your session expired. Please sign in again.';
}

class AccessDeniedError extends DashboardError {
  const AccessDeniedError();
  @override
  String get userMessage => 'You do not have permission to view this dashboard.';
}

class NetworkError extends DashboardError {
  const NetworkError();
  @override
  String get userMessage => 'No internet connection';
}

class ServiceError extends DashboardError {
  const ServiceError();
  @override
  String get userMessage => 'VoltShare services are temporarily unavailable';
}

class MalformedResponseError extends DashboardError {
  const MalformedResponseError();
  @override
  String get userMessage => 'Could not read the dashboard response';
}

class UnknownDashboardError extends DashboardError {
  const UnknownDashboardError();
  @override
  String get userMessage => 'Energy readings are unavailable right now.';
}

/// Maps exceptions from the API client to user-facing dashboard errors.
DashboardError _mapError(Object error) {
  if (error is ApiException) {
    return switch (error.code) {
      'AUTH_REQUIRED' || 'AUTH_INVALID_TOKEN' => const AuthError(),
      'ACCESS_DENIED' => const AccessDeniedError(),
      'NETWORK_ERROR' => const NetworkError(),
      'TIMEOUT' => const NetworkError(),
      'MALFORMED_RESPONSE' => const MalformedResponseError(),
      'HTTP_500' || 'HTTP_502' || 'HTTP_503' => const ServiceError(),
      _ => const UnknownDashboardError(),
    };
  }
  return const UnknownDashboardError();
}

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardSnapshot?>> {
  DashboardNotifier(
    this._repository, {
    Duration updateInterval = const Duration(seconds: 4),
    bool autoStartTimer = true,
  }) : _updateInterval = updateInterval,
       _autoStartTimer = autoStartTimer,
       super(const AsyncValue.loading());

  final DashboardRepository _repository;
  final Duration _updateInterval;
  final bool _autoStartTimer;
  Timer? _timer;

  Future<void> load() async {
    state = const AsyncValue.loading();
    await _read(() => _repository.fetchInitialSnapshot());
  }

  Future<void> refresh() async {
    await _read(() => _repository.refreshSnapshot(), keepPrevious: true);
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    await _read(() => _repository.fetchInitialSnapshot());
  }

  void simulateTick() {
    if (_repository is DashboardApiRepository) {
      unawaited(refresh());
      return;
    }
    final snapshot = state.valueOrNull;
    if (snapshot == null) {
      return;
    }
    state = AsyncValue.data(_repository.simulateNextSnapshot(snapshot));
  }

  Future<void> _read(
    Future<DashboardSnapshot?> Function() reader, {
    bool keepPrevious = false,
  }) async {
    if (keepPrevious && state.hasValue) {
      state = AsyncValue<DashboardSnapshot?>.loading().copyWithPrevious(state);
    }
    try {
      final snapshot = await reader();
      state = AsyncValue.data(snapshot);
      _configureTimer(snapshot);
    } catch (error, stackTrace) {
      state = AsyncValue.error(_mapError(error), stackTrace);
      _timer?.cancel();
    }
  }

  void _configureTimer(DashboardSnapshot? snapshot) {
    _timer?.cancel();
    if (!_autoStartTimer || snapshot == null) {
      return;
    }
    _timer = Timer.periodic(_updateInterval, (_) => simulateTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
