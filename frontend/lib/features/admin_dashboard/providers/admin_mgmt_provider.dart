import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/admin_models.dart';
import '../data/admin_mgmt_repository.dart';

/// States for admin users list.
sealed class AdminUsersState {
  const AdminUsersState();
}
class AdminUsersLoading extends AdminUsersState {
  const AdminUsersLoading();
}
class AdminUsersSuccess extends AdminUsersState {
  const AdminUsersSuccess(this.data);
  final PaginatedAdminUsers data;
}
class AdminUsersError extends AdminUsersState {
  const AdminUsersError(this.message);
  final String message;
}

/// States for admin disputes list.
sealed class AdminDisputesState {
  const AdminDisputesState();
}
class AdminDisputesLoading extends AdminDisputesState {
  const AdminDisputesLoading();
}
class AdminDisputesSuccess extends AdminDisputesState {
  const AdminDisputesSuccess(this.data);
  final PaginatedAdminDisputes data;
}
class AdminDisputesError extends AdminDisputesState {
  const AdminDisputesError(this.message);
  final String message;
}

/// States for admin audit logs list.
sealed class AdminAuditState {
  const AdminAuditState();
}
class AdminAuditLoading extends AdminAuditState {
  const AdminAuditLoading();
}
class AdminAuditSuccess extends AdminAuditState {
  const AdminAuditSuccess(this.data);
  final PaginatedAuditLogs data;
}
class AdminAuditError extends AdminAuditState {
  const AdminAuditError(this.message);
  final String message;
}

/// Provider for admin users list.
final adminUsersProvider = StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) {
  final repository = ref.watch(adminMgmtRepositoryProvider);
  return AdminUsersNotifier(repository)..load();
});

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  AdminUsersNotifier(this._repository) : super(const AdminUsersLoading());

  final AdminMgmtRepository _repository;

  Future<void> load({
    String? search,
    String? role,
    String? status,
    String? kycStatus,
    int page = 1,
  }) async {
    state = const AdminUsersLoading();
    await _fetch(search: search, role: role, status: status, kycStatus: kycStatus, page: page);
  }

  Future<void> refresh() async {
    await _fetch();
  }

  Future<void> loadMore({
    String? search,
    String? role,
    String? status,
    String? kycStatus,
    int page = 1,
  }) async {
    await _fetch(search: search, role: role, status: status, kycStatus: kycStatus, page: page);
  }

  Future<void> _fetch({
    String? search,
    String? role,
    String? status,
    String? kycStatus,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final data = await _repository.listUsers(
        search: search,
        role: role,
        status: status,
        kycStatus: kycStatus,
        page: page,
        pageSize: pageSize,
      );
      state = AdminUsersSuccess(data);
    } catch (error) {
      state = AdminUsersError(_mapError(error));
    }
  }

  String _mapError(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'AUTH_REQUIRED' || 'AUTH_INVALID_TOKEN' => 'Your session expired. Please sign in again.',
        'ACCESS_DENIED' => 'Administrator access is required.',
        'NETWORK_ERROR' || 'TIMEOUT' => 'No internet connection',
        _ => 'Could not load users.',
      };
    }
    return 'Could not load users.';
  }
}

/// Provider for admin disputes list.
final adminDisputesProvider = StateNotifierProvider<AdminDisputesNotifier, AdminDisputesState>((ref) {
  final repository = ref.watch(adminMgmtRepositoryProvider);
  return AdminDisputesNotifier(repository)..load();
});

class AdminDisputesNotifier extends StateNotifier<AdminDisputesState> {
  AdminDisputesNotifier(this._repository) : super(const AdminDisputesLoading());

  final AdminMgmtRepository _repository;

  Future<void> load({
    String? status,
    String? priority,
    String? buyerId,
    String? sellerId,
    int page = 1,
  }) async {
    state = const AdminDisputesLoading();
    await _fetch(status: status, priority: priority, buyerId: buyerId, sellerId: sellerId, page: page);
  }

  Future<void> refresh() async {
    await _fetch();
  }

  Future<void> _fetch({
    String? status,
    String? priority,
    String? buyerId,
    String? sellerId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final data = await _repository.listDisputes(
        status: status,
        priority: priority,
        buyerId: buyerId,
        sellerId: sellerId,
        page: page,
        pageSize: pageSize,
      );
      state = AdminDisputesSuccess(data);
    } catch (error) {
      state = AdminDisputesError(_mapError(error));
    }
  }

  Future<DisputeActionResponse> resolveDispute(
    String disputeId, DisputeResolutionRequest request,
  ) async {
    try {
      final result = await _repository.resolveDispute(disputeId, request);
      await refresh();
      return result;
    } catch (error) {
      rethrow;
    }
  }

  Future<DisputeActionResponse> rejectDispute(
    String disputeId, DisputeResolutionRequest request,
  ) async {
    try {
      final result = await _repository.rejectDispute(disputeId, request);
      await refresh();
      return result;
    } catch (error) {
      rethrow;
    }
  }

  Future<DisputeActionResponse> assignDispute(String disputeId) async {
    try {
      final result = await _repository.assignDispute(disputeId);
      await refresh();
      return result;
    } catch (error) {
      rethrow;
    }
  }

  String _mapError(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'AUTH_REQUIRED' || 'AUTH_INVALID_TOKEN' => 'Your session expired. Please sign in again.',
        'ACCESS_DENIED' => 'Administrator access is required.',
        'NETWORK_ERROR' || 'TIMEOUT' => 'No internet connection',
        _ => 'Could not load disputes.',
      };
    }
    return 'Could not load disputes.';
  }
}

/// Provider for admin audit logs.
final adminAuditProvider = StateNotifierProvider<AdminAuditNotifier, AdminAuditState>((ref) {
  final repository = ref.watch(adminMgmtRepositoryProvider);
  return AdminAuditNotifier(repository)..load();
});

class AdminAuditNotifier extends StateNotifier<AdminAuditState> {
  AdminAuditNotifier(this._repository) : super(const AdminAuditLoading());

  final AdminMgmtRepository _repository;

  Future<void> load({
    String? search,
    String? eventType,
    String? severity,
    String? actorId,
    String? resourceType,
    int page = 1,
  }) async {
    state = const AdminAuditLoading();
    await _fetch(
      search: search,
      eventType: eventType,
      severity: severity,
      actorId: actorId,
      resourceType: resourceType,
      page: page,
    );
  }

  Future<void> refresh() async {
    await _fetch();
  }

  Future<void> _fetch({
    String? search,
    String? eventType,
    String? severity,
    String? actorId,
    String? resourceType,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final data = await _repository.listAuditLogs(
        search: search,
        eventType: eventType,
        severity: severity,
        actorId: actorId,
        resourceType: resourceType,
        page: page,
        pageSize: pageSize,
      );
      state = AdminAuditSuccess(data);
    } catch (error) {
      state = AdminAuditError(_mapError(error));
    }
  }

  String _mapError(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'AUTH_REQUIRED' || 'AUTH_INVALID_TOKEN' => 'Your session expired. Please sign in again.',
        'ACCESS_DENIED' => 'Administrator access is required.',
        'NETWORK_ERROR' || 'TIMEOUT' => 'No internet connection',
        _ => 'Could not load audit logs.',
      };
    }
    return 'Could not load audit logs.';
  }
}
