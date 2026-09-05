import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/emergency_models.dart';
import '../data/emergency_repository.dart';

/// Emergency assistance state.
sealed class EmergencyState {
  const EmergencyState();
}

class EmergencyLoading extends EmergencyState {
  const EmergencyLoading();
}

class EmergencySuccess extends EmergencyState {
  const EmergencySuccess(this.requests);
  final List<EmergencyRequest> requests;
}

class EmergencyError extends EmergencyState {
  const EmergencyError(this.message, this.onRetry);
  final String message;
  final VoidCallback onRetry;
}

/// Provider for emergency requests (consumer view).
final emergencyProvider = StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  final repository = ref.watch(emergencyRepositoryProvider);
  return EmergencyNotifier(repository)..load();
});

class EmergencyNotifier extends StateNotifier<EmergencyState> {
  EmergencyNotifier(this._repository) : super(const EmergencyLoading());

  final EmergencyRepository _repository;

  Future<void> load() async {
    state = const EmergencyLoading();
    try {
      final requests = await _repository.getMyRequests();
      state = EmergencySuccess(requests);
    } catch (error) {
      state = EmergencyError(_mapError(error), () => load());
    }
  }

  Future<EmergencyRequest?> createRequest(Map<String, dynamic> data) async {
    try {
      final request = await _repository.createRequest(data);
      // Reload to refresh list
      await load();
      return request;
    } catch (error) {
      return null;
    }
  }

  String _mapError(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'AUTH_REQUIRED' || 'AUTH_INVALID_TOKEN' =>
          'Your session expired. Please sign in again.',
        'NETWORK_ERROR' || 'TIMEOUT' =>
          'No internet connection. Please check your network.',
        _ => 'Could not load emergency requests.',
      };
    }
    return 'Could not load emergency requests.';
  }
}

/// Provider for admin emergency view.
final adminEmergencyProvider = StateNotifierProvider<AdminEmergencyNotifier, EmergencyState>((ref) {
  final repository = ref.watch(emergencyRepositoryProvider);
  return AdminEmergencyNotifier(repository)..load();
});

class AdminEmergencyNotifier extends StateNotifier<EmergencyState> {
  AdminEmergencyNotifier(this._repository) : super(const EmergencyLoading());

  final EmergencyRepository _repository;

  Future<void> load() async {
    state = const EmergencyLoading();
    try {
      final requests = await _repository.getAllRequests();
      state = EmergencySuccess(requests);
    } catch (error) {
      state = EmergencyError(_mapError(error), () => load());
    }
  }

  Future<EmergencyRequest?> updateRequest(String requestId, Map<String, dynamic> data) async {
    try {
      final updated = await _repository.updateRequest(requestId, data);
      await load();
      return updated;
    } catch (error) {
      return null;
    }
  }

  Future<EmergencyAllocation?> createAllocation(Map<String, dynamic> data) async {
    try {
      return await _repository.createAllocation(data);
    } catch (error) {
      return null;
    }
  }

  Future<EmergencySummary?> getSummary() async {
    try {
      return await _repository.getSummary();
    } catch (error) {
      return null;
    }
  }

  String _mapError(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'ACCESS_DENIED' => 'Administrator access is required.',
        'NETWORK_ERROR' || 'TIMEOUT' =>
          'No internet connection.',
        _ => 'Could not load emergency requests.',
      };
    }
    return 'Could not load emergency requests.';
  }
}
