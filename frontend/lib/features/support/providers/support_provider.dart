import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';

/// Support ticket state.
sealed class SupportState {
  const SupportState();
}

class SupportLoading extends SupportState {
  const SupportLoading();
}

class SupportSuccess extends SupportState {
  const SupportSuccess(this.tickets);
  final List<SupportTicket> tickets;
}

class SupportError extends SupportState {
  const SupportError(this.message, this.onRetry);
  final String message;
  final VoidCallback onRetry;
}

/// Provider for user's support tickets.
final supportProvider = StateNotifierProvider<SupportNotifier, SupportState>((ref) {
  final repository = ref.watch(supportRepositoryProvider);
  return SupportNotifier(repository)..load();
});

class SupportNotifier extends StateNotifier<SupportState> {
  SupportNotifier(this._repository) : super(const SupportLoading());

  final SupportRepository _repository;

  Future<void> load() async {
    state = const SupportLoading();
    try {
      final tickets = await _repository.getMyTickets();
      state = SupportSuccess(tickets);
    } catch (error) {
      state = SupportError(_mapError(error), () => load());
    }
  }

  Future<SupportTicket?> createTicket(Map<String, dynamic> data) async {
    try {
      final ticket = await _repository.createTicket(data);
      await load();
      return ticket;
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
          'No internet connection.',
        _ => 'Could not load support tickets.',
      };
    }
    return 'Could not load support tickets.';
  }
}

/// Provider for messages in a specific ticket.
final ticketMessagesProvider = FutureProvider.family<List<SupportMessage>, String>((ref, ticketId) async {
  final repository = ref.watch(supportRepositoryProvider);
  return repository.getMessages(ticketId);
});

/// Provider for admin support tickets.
final adminSupportProvider = StateNotifierProvider<AdminSupportNotifier, SupportState>((ref) {
  final repository = ref.watch(supportRepositoryProvider);
  return AdminSupportNotifier(repository)..load();
});

class AdminSupportNotifier extends StateNotifier<SupportState> {
  AdminSupportNotifier(this._repository) : super(const SupportLoading());

  final SupportRepository _repository;

  Future<void> load() async {
    state = const SupportLoading();
    try {
      final tickets = await _repository.getAllTickets();
      state = SupportSuccess(tickets);
    } catch (error) {
      state = SupportError(_mapError(error), () => load());
    }
  }

  Future<SupportTicket?> updateTicket(String ticketId, Map<String, dynamic> data) async {
    try {
      final updated = await _repository.updateTicket(ticketId, data);
      await load();
      return updated;
    } catch (error) {
      return null;
    }
  }

  Future<SupportSummary?> getSummary() async {
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
        _ => 'Could not load support tickets.',
      };
    }
    return 'Could not load support tickets.';
  }
}
