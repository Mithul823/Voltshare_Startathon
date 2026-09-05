import '../../../core/network/api_client.dart';
import '../domain/user_profile.dart';

class AuthApiRepository {
  const AuthApiRepository(this._client);

  final ApiClient _client;

  Future<UserProfile> authMe() async {
    return _profile(await _client.get('/auth/me') as Map);
  }

  Future<UserProfile> userMe() async {
    return _profile(await _client.get('/users/me') as Map);
  }

  Future<UserProfile> updateUserProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final body = <String, Object?>{
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
    }..removeWhere((_, value) => value == null);
    return _profile(await _client.patch(
      '/users/me',
      body: body,
    ) as Map);
  }

  Future<Map<String, Object?>> health() async {
    return (await _client.get('/health') as Map).cast<String, Object?>();
  }

  UserProfile _profile(Map data) {
    return UserProfile.fromMap({
      'id': data['id'],
      'email': data['email'] ?? '',
      'full_name': data['full_name'] ?? '',
      'phone': data['phone'] ?? '',
      'role': data['role'] ?? 'consumer',
      'city': '',
      'district': '',
      'state': '',
    });
  }
}
