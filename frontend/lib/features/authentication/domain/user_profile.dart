import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.city,
    required this.district,
    required this.state,
    this.isActive = true,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: (map['email'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      role: UserRole.fromValue((map['role'] as String?) ?? 'consumer'),
      city: (map['city'] as String?) ?? '',
      district: (map['district'] as String?) ?? '',
      state: (map['state'] as String?) ?? '',
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String city;
  final String district;
  final String state;
  final bool isActive;

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role.value,
      'city': city,
      'district': district,
      'state': state,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
