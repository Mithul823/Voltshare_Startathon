import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/meter_repository.dart';
import '../domain/meter_metrics.dart';

final producerMeterProvider =
    StateNotifierProvider.autoDispose<
      ProducerMeterNotifier,
      AsyncValue<MeterMetrics>
    >((ref) {
      final repository = ref.watch(meterRepositoryProvider);
      return ProducerMeterNotifier(repository: repository);
    });

class ProducerMeterNotifier extends StateNotifier<AsyncValue<MeterMetrics>> {
  ProducerMeterNotifier({
    required MeterRepository repository,
    Duration pollingInterval = const Duration(seconds: 3),
    bool autoStartPolling = true,
  }) : _repository = repository,
       _pollingInterval = pollingInterval,
       super(
         AsyncValue.data(
           MeterMetrics(
             timestamp: DateTime.now(),
             status: MeterConnectionStatus.connecting,
           ),
         ),
       ) {
    if (autoStartPolling) {
      _startPolling();
    }
  }

  final MeterRepository _repository;
  final Duration _pollingInterval;
  Timer? _pollingTimer;
  bool _isFetching = false;
  MeterMetrics? _lastKnownReading;

  void _startPolling() {
    // Initial fetch immediately
    _fetchMetrics();

    // Periodic background polling without overlapping requests
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _fetchMetrics();
    });
  }

  Future<void> refresh() async {
    await _fetchMetrics(force: true);
  }

  Future<void> _fetchMetrics({bool force = false}) async {
    if (_isFetching && !force) return;
    _isFetching = true;

    try {
      final metrics = await _repository.getProducerMetrics();
      if (!mounted) return;

      _lastKnownReading = metrics.copyWith(status: MeterConnectionStatus.live);
      state = AsyncValue.data(_lastKnownReading!);
    } catch (error, stackTrace) {
      if (!mounted) return;

      final errorMessage = error is ApiException
          ? error.message
          : 'Smart meter data is temporarily unavailable.';

      if (kDebugMode) {
        // ignore: avoid_print
        print('[ProducerMeterNotifier] Meter fetch error: $errorMessage');
      }

      if (_lastKnownReading != null) {
        // Maintain last known reading with STALE connection status
        final staleData = _lastKnownReading!.copyWith(
          status: MeterConnectionStatus.stale,
          errorMessage: errorMessage,
        );
        state = AsyncValue.data(staleData);
      } else {
        // No prior valid reading exists: transition to OFFLINE state
        state = AsyncValue.data(
          MeterMetrics(
            timestamp: DateTime.now(),
            status: MeterConnectionStatus.offline,
            errorMessage: errorMessage,
          ),
        );
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    super.dispose();
  }
}
