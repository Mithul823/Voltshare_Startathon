import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

final authTokenProvider = Provider<AuthTokenProvider>((ref) {
  return AuthTokenProvider(ref);
});

class AuthTokenProvider {
  const AuthTokenProvider(this._ref);

  final Ref _ref;

  /// Returns a valid access token, refreshing the session if the current
  /// token is expired or will expire within the safety margin (30 seconds).
  ///
  /// Returns `null` if there is no active session at all.
  Future<String?> accessToken() async {
    final client = _ref.read(supabaseClientProvider);
    final session = client.auth.currentSession;
    if (session == null) return null;

    // Check if the token is expired or about to expire (within 30s safety margin)
    // session.expiresAt is a Unix timestamp (seconds since epoch)
    final expiresAtEpoch = session.expiresAt;
    if (expiresAtEpoch != null) {
      final now = DateTime.now().toUtc();
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(expiresAtEpoch * 1000, isUtc: true);
      if (now.isAfter(expiry.subtract(const Duration(seconds: 30)))) {
        try {
          await client.auth.refreshSession();
          return client.auth.currentSession?.accessToken;
        } catch (_) {
          // Refresh failed — no valid session available
          return null;
        }
      }
    }

    return session.accessToken;
  }

  /// Forcefully refresh the session, ignoring the current token's expiry.
  /// Returns the new access token, or `null` if refresh fails.
  Future<String?> forceRefresh() async {
    final client = _ref.read(supabaseClientProvider);
    try {
      await client.auth.refreshSession();
      return client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
