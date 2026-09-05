import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import 'sales_repository.dart';

/// States for producer sales.
sealed class SalesState {
  const SalesState();
}

class SalesLoading extends SalesState {
  const SalesLoading();
}

class SalesSuccess extends SalesState {
  const SalesSuccess(this.data);
  final ProducerSalesPage data;
}

class SalesError extends SalesState {
  const SalesError(this.message);
  final String message;
}

/// Provider for producer sales data.
final salesProvider = StateNotifierProvider<SalesNotifier, SalesState>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return SalesNotifier(repository)..load();
});

class SalesNotifier extends StateNotifier<SalesState> {
  SalesNotifier(this._repository) : super(const SalesLoading());

  final SalesRepository _repository;
  String? _statusFilter;
  String? _lastSearch;

  Future<void> load({String? status, String? search, int page = 1}) async {
    state = const SalesLoading();
    _statusFilter = status;
    _lastSearch = search;
    await _fetch(status: status, search: search, page: page);
  }

  Future<void> refresh() async {
    await _fetch(status: _statusFilter, search: _lastSearch);
  }

  Future<void> loadMore({int page = 1}) async {
    await _fetch(status: _statusFilter, search: _lastSearch, page: page);
  }

  void retry() {
    load(status: _statusFilter, search: _lastSearch);
  }

  Future<void> _fetch({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final data = await _repository.getSales(
        status: status,
        search: search,
        page: page,
        pageSize: pageSize,
      );
      if (!mounted) return;
      state = SalesSuccess(data);
    } catch (error) {
      if (!mounted) return;
      state = SalesError(_mapError(error));
    }
  }

  String _mapError(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'AUTH_REQUIRED' ||
        'AUTH_INVALID_TOKEN' => 'Your session expired. Please sign in again.',
        'ACCESS_DENIED' => 'You do not have permission to view sales.',
        'NETWORK_ERROR' || 'TIMEOUT' => 'No internet connection',
        'HTTP_500' ||
        'HTTP_502' ||
        'HTTP_503' => 'Sales data is temporarily unavailable.',
        _ => 'Could not load sales.',
      };
    }
    return 'Could not load sales.';
  }
}
