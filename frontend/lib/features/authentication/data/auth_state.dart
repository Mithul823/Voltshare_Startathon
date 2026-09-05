import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

/// Tracks the lifecycle of authentication initialization.
///
/// - [initializing]: Supabase has been initialized but the session
///   restoration event has not yet been received from onAuthStateChange.
/// - [authenticated]: A valid session exists.
/// - [unauthenticated]: No session exists (user must log in).
enum AuthState { initializing, authenticated, unauthenticated }

/// A FutureProvider that resolves once the authentication state is known.
///
/// This ensures the router and splash screen wait for Supabase session
/// restoration before making redirect decisions, preventing premature
/// navigation to login when a session is being restored asynchronously.
final authInitializationProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  if (!repository.isConfigured) {
    return;
  }

  // Create a completer that resolves when the first non-null auth state
  // is received from the onAuthStateChange stream.
  final completer = Completer<void>();

  final subscription = repository.authStateChanges.listen(
    (state) {
      if (!completer.isCompleted) {
        // The first emitted state confirms auth initialization is done.
        // Supabase replays the latest event (INITIAL_SESSION or SIGNED_IN)
        // on first subscription.
        completer.complete();
      }
    },
    onError: (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    },
  );

  // If the session is already available synchronously (e.g., from a freshly
  // completed sign-in), resolve immediately without waiting for the stream.
  if (repository.currentSession != null) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  // Timeout: if no auth state is received within 5 seconds, resolve anyway
  // to avoid blocking the app indefinitely.
  unawaited(Future<void>.delayed(const Duration(seconds: 5), () {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }));

  // Clean up subscription when the provider is disposed
  ref.onDispose(subscription.cancel);

  return completer.future;
});

/// Derives the current [AuthState] from the auth initialization status
/// and the current session.
final authStateProvider = Provider<AuthState>((ref) {
  final initializationAsync = ref.watch(authInitializationProvider);
  final session = ref.watch(currentSessionProvider);

  // While initialization is still running, show initializing
  if (initializationAsync.isLoading) {
    return AuthState.initializing;
  }

  // Even after initialization completes, there might be a brief window
  // where the session is null because Supabase hasn't emitted it yet.
  // Check both the initialization status and the synchronous session.
  return session != null ? AuthState.authenticated : AuthState.unauthenticated;
});
