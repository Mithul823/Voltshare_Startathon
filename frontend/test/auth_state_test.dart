import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/features/authentication/data/auth_repository.dart';
import 'package:frontend/features/authentication/domain/user_profile.dart';
import 'package:frontend/features/authentication/domain/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _testSessionProvider = StateProvider<Session?>((ref) => null);

void main() {
  test(
    'current profile follows live session changes without restart',
    () async {
      final repository = _FetchingAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          currentSessionProvider.overrideWith(
            (ref) => ref.watch(_testSessionProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(currentProfileProvider.future), isNull);

      container.read(_testSessionProvider.notifier).state = _session(
        userId: 'user-1',
        token: 'token-1',
      );
      final firstProfile = await container.read(currentProfileProvider.future);
      expect(firstProfile?.id, 'user-1');
      expect(repository.fetchedUserIds, ['user-1']);

      container.read(_testSessionProvider.notifier).state = _session(
        userId: 'user-2',
        token: 'token-2',
      );
      final secondProfile = await container.read(currentProfileProvider.future);
      expect(secondProfile?.id, 'user-2');
      expect(repository.fetchedUserIds, ['user-1', 'user-2']);

      container.read(_testSessionProvider.notifier).state = null;
      expect(await container.read(currentProfileProvider.future), isNull);
    },
  );
}

Session _session({required String userId, required String token}) {
  return Session(
    accessToken: token,
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: '$userId@example.com',
      createdAt: DateTime.utc(2026).toIso8601String(),
    ),
  );
}

class _FetchingAuthRepository extends AuthRepository {
  _FetchingAuthRepository()
    : super(
        config: const AppConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: 'publishable',
        ),
        client: null,
      );

  final fetchedUserIds = <String>[];

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    fetchedUserIds.add(userId);
    return UserProfile(
      id: userId,
      email: '$userId@example.com',
      fullName: 'Test User',
      phone: '',
      role: UserRole.prosumer,
      city: 'Kochi',
      district: 'Ernakulam',
      state: 'Kerala',
    );
  }
}
