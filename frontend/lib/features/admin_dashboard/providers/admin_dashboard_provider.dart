import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/admin_dashboard_models.dart';
import '../data/admin_dashboard_repository.dart';

/// Filtered states for the admin dashboard.
sealed class AdminDashboardState {
  const AdminDashboardState();
}

class AdminDashboardLoading extends AdminDashboardState {
  const AdminDashboardLoading();
}

class AdminDashboardSuccess extends AdminDashboardState {
  const AdminDashboardSuccess(this.data);
  final AdminDashboardData data;
}

class AdminDashboardError extends AdminDashboardState {
  const AdminDashboardError(this.message, this.onRetry);
  final String message;
  final VoidCallback onRetry;
}

/// Provider for the admin dashboard data.
final adminDashboardProvider =
    StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>((ref) {
  final repository = ref.watch(adminDashboardRepositoryProvider);
  return AdminDashboardNotifier(repository)..load();
});

class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  AdminDashboardNotifier(this._repository) : super(const AdminDashboardLoading());

  final AdminDashboardRepository _repository;

  Future<void> load({int rangeDays = 30}) async {
    state = const AdminDashboardLoading();
    await _fetch(rangeDays);
  }

  Future<void> refresh({int rangeDays = 30}) async {
    await _fetch(rangeDays);
  }

  void retry() {
    load();
  }

  Future<void> _fetch(int rangeDays) async {
    try {
      final data = await _repository.fetchDashboard(rangeDays: rangeDays);
      state = AdminDashboardSuccess(data);
    } catch (error) {
      state = AdminDashboardError(
        _mapErrorMessage(error),
        retry,
      );
    }
  }

  String _mapErrorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'AUTH_REQUIRED' || 'AUTH_INVALID_TOKEN' =>
          'Your session expired. Please sign in again.',
        'ACCESS_DENIED' =>
          'Administrator access is required.',
        'NETWORK_ERROR' || 'TIMEOUT' =>
          'No internet connection',
        'HTTP_500' || 'HTTP_502' || 'HTTP_503' =>
          'Admin services are temporarily unavailable.',
        _ => 'Could not load admin dashboard.',
      };
    }
    return 'Could not load admin dashboard.';
  }
}
