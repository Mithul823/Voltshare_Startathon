import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/supabase_service.dart';
import 'auth_api_repository.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = config.isSupabaseConfigured
      ? ref.watch(supabaseClientProvider)
      : null;
  final apiRepository = config.useMockBackend
      ? null
      : AuthApiRepository(ref.watch(apiClientProvider));
  return AuthRepository(
    config: config,
    client: client,
    apiRepository: apiRepository,
  );
});

final authSessionStreamProvider = StreamProvider<Session?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (!repository.isConfigured) {
    return Stream<Session?>.value(null);
  }
  return repository.authStateChanges.map((state) => state.session).distinct((
    previous,
    next,
  ) {
    return previous?.user.id == next?.user.id &&
        previous?.accessToken == next?.accessToken;
  });
});

final currentSessionProvider = Provider<Session?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final streamSession = ref.watch(authSessionStreamProvider);
  return streamSession.when(
    data: (session) => session,
    loading: () => repository.currentSession,
    error: (_, _) => repository.currentSession,
  );
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  final session = ref.watch(currentSessionProvider);
  if (session == null || !repository.isConfigured) {
    if (ref.watch(appConfigProvider).isMockMode) {
      return UserProfile(
        id: 'producer-1',
        email: 'ravi@voltshare-demo.local',
        fullName: 'Ravi Kumar',
        phone: '+91 9876543210',
        role: UserRole.prosumer,
        city: 'Kochi',
        district: 'Ernakulam',
        state: 'Kerala',
      );
    }
    return null;
  }
  return repository.fetchProfile(session.user.id);
});

class AuthRepository {
  const AuthRepository({
    required AppConfig config,
    required SupabaseClient? client,
    AuthApiRepository? apiRepository,
  }) : _config = config,
       _client = client,
       _apiRepository = apiRepository;

  final AppConfig _config;
  final SupabaseClient? _client;
  final AuthApiRepository? _apiRepository;

  bool get isConfigured => _config.isSupabaseConfigured;
  User? get currentUser => _client?.auth.currentUser;
  Session? get currentSession => _client?.auth.currentSession;
  Stream<AuthState> get authStateChanges {
    return _client?.auth.onAuthStateChange ?? const Stream.empty();
  }

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const AppException('Add your Supabase URL and publishable key.');
    }
    return client;
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _requiredClient.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AppException(_friendlyAuthMessage(error.message));
    } catch (error) {
      throw AppException(_friendlyAuthMessage(error.toString()));
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    required String city,
    required String district,
    required String state,
  }) async {
    try {
      final response = await _requiredClient.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'role': role.value,
          'city': city.trim(),
          'district': district.trim(),
          'state': state.trim(),
        },
      );

      final user = response.user;
      if (user == null) {
        throw const AppException('Registration did not return a user.');
      }

      final profile = UserProfile(
        id: user.id,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: role,
        city: city.trim(),
        district: district.trim(),
        state: state.trim(),
      );

      if (response.session != null) {
        await upsertProfile(profile);
      }
    } on AuthException catch (error) {
      throw AppException(_friendlyAuthMessage(error.message));
    } on PostgrestException catch (error) {
      throw AppException(error.message);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_friendlyAuthMessage(error.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await _requiredClient.auth.signOut();
    } on AuthException catch (error) {
      throw AppException(_friendlyAuthMessage(error.message));
    } catch (error) {
      throw AppException(_friendlyAuthMessage(error.toString()));
    }
  }

  Future<void> refreshSession() async {
    try {
      await _requiredClient.auth.refreshSession();
    } on AuthException catch (error) {
      throw AppException(_friendlyAuthMessage(error.message));
    } catch (error) {
      throw AppException(_friendlyAuthMessage(error.toString()));
    }
  }

  Future<UserProfile?> fetchProfile(String userId) async {
    final apiRepository = _apiRepository;
    if (apiRepository != null) {
      try {
        return await apiRepository.userMe();
      } catch (_) {
        throw const AppException('Unable to load your backend profile.');
      }
    }
    try {
      final row = await _requiredClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return UserProfile.fromMap(row);
    } on PostgrestException catch (error) {
      throw AppException(error.message);
    } catch (_) {
      throw const AppException('Unable to load your profile.');
    }
  }

  Future<void> upsertProfile(UserProfile profile) async {
    await _requiredClient.from('profiles').upsert(profile.toInsertMap());
  }

  String _friendlyAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'Email or password is incorrect.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already exists')) {
      return 'An account already exists for this email.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('clientexception')) {
      return 'Unable to reach Supabase. Check your internet connection and SUPABASE_URL.';
    }
    return message;
  }
}
