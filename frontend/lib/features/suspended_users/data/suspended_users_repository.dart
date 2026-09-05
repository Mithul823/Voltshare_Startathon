import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class SuspendedUserRecord {
  final String id;
  final String userId;
  final String fullName;
  final String? email;
  final String role;
  final String suspensionReason;
  final String suspendedBy;
  final String? suspendedByName;
  final DateTime suspendedAt;
  final DateTime? restoredAt;
  final String? restoredBy;
  final bool isRestored;

  const SuspendedUserRecord({
    required this.id,
    required this.userId,
    required this.fullName,
    this.email,
    required this.role,
    required this.suspensionReason,
    required this.suspendedBy,
    this.suspendedByName,
    required this.suspendedAt,
    this.restoredAt,
    this.restoredBy,
    this.isRestored = false,
  });

  factory SuspendedUserRecord.fromJson(Map<String, dynamic> json) {
    return SuspendedUserRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? '',
      suspensionReason: json['suspension_reason']?.toString() ?? '',
      suspendedBy: json['suspended_by']?.toString() ?? '',
      suspendedByName: json['suspended_by_name']?.toString(),
      suspendedAt: DateTime.tryParse(json['suspended_at']?.toString() ?? '') ?? DateTime.now(),
      restoredAt: json['restored_at'] != null ? DateTime.tryParse(json['restored_at'].toString()) : null,
      restoredBy: json['restored_by']?.toString(),
      isRestored: json['is_restored'] == true,
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

class PaginatedSuspendedUsers {
  final List<SuspendedUserRecord> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const PaginatedSuspendedUsers({
    this.items = const [],
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  factory PaginatedSuspendedUsers.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => SuspendedUserRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PaginatedSuspendedUsers(
      items: itemsList,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty && total == 0;
}

abstract class SuspendedUsersRepository {
  Future<PaginatedSuspendedUsers> listSuspended({String? search, int page = 1, int pageSize = 20});
  Future<void> restoreUser(String userId);
  Future<void> deleteSuspension(String userId);
}

class MockSuspendedUsersRepository implements SuspendedUsersRepository {
  final List<SuspendedUserRecord> _records = [];

  @override
  Future<PaginatedSuspendedUsers> listSuspended({String? search, int page = 1, int pageSize = 20}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    var items = List<SuspendedUserRecord>.from(_records);
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      items = items.where((r) => r.fullName.toLowerCase().contains(q) || (r.email?.toLowerCase().contains(q) ?? false)).toList();
    }
    items.sort((a, b) => b.suspendedAt.compareTo(a.suspendedAt));
    final total = items.length;
    final totalPages = (total + pageSize - 1) ~/ pageSize;
    final start = (page - 1) * pageSize;
    final end = start + pageSize > total ? total : start + pageSize;
    return PaginatedSuspendedUsers(items: items.sublist(start, end), page: page, pageSize: pageSize, total: total, totalPages: totalPages);
  }

  @override
  Future<void> restoreUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _records.removeWhere((r) => r.userId == userId);
  }

  @override
  Future<void> deleteSuspension(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _records.removeWhere((r) => r.userId == userId);
  }

  void addMockSuspension(SuspendedUserRecord record) {
    _records.add(record);
  }
}

class ApiSuspendedUsersRepository implements SuspendedUsersRepository {
  ApiSuspendedUsersRepository(this._client);
  final ApiClient _client;

  @override
  Future<PaginatedSuspendedUsers> listSuspended({String? search, int page = 1, int pageSize = 20}) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (search != null) 'search': search,
    };
    final data = await _client.get('/admin/suspended', query: params);
    return PaginatedSuspendedUsers.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> restoreUser(String userId) async {
    await _client.post('/admin/suspended/$userId/restore');
  }

  @override
  Future<void> deleteSuspension(String userId) async {
    await _client.delete('/admin/suspended/$userId');
  }
}

final suspendedUsersRepositoryProvider = Provider<SuspendedUsersRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return ApiSuspendedUsersRepository(ref.watch(apiClientProvider));
  }
  return MockSuspendedUsersRepository();
});
