import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'admin_models.dart';

/// Repository for admin management operations (users, disputes, audit).
abstract class AdminMgmtRepository {
  Future<PaginatedAdminUsers> listUsers({
    String? search,
    String? role,
    String? status,
    String? kycStatus,
    int page = 1,
    int pageSize = 20,
  });

  Future<AdminUserSummary> getUserDetail(String userId);

  Future<AdminUserSummary> suspendUser(String userId);

  Future<AdminUserSummary> reactivateUser(String userId);

  Future<PaginatedAdminDisputes> listDisputes({
    String? status,
    String? priority,
    String? buyerId,
    String? sellerId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  });

  Future<AdminDisputeSummary> getDisputeDetail(String disputeId);

  Future<DisputeActionResponse> resolveDispute(
    String disputeId,
    DisputeResolutionRequest request,
  );

  Future<DisputeActionResponse> rejectDispute(
    String disputeId,
    DisputeResolutionRequest request,
  );

  Future<DisputeActionResponse> assignDispute(String disputeId);

  Future<PaginatedAuditLogs> listAuditLogs({
    String? search,
    String? eventType,
    String? severity,
    String? actorId,
    String? resourceType,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  });
}

/// Provider that selects mock or live repository.
final adminMgmtRepositoryProvider = Provider<AdminMgmtRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return AdminMgmtApiRepository(ref.watch(apiClientProvider));
  }
  return AdminMgmtMockRepository();
});

/// Live API implementation.
class AdminMgmtApiRepository implements AdminMgmtRepository {
  AdminMgmtApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<PaginatedAdminUsers> listUsers({
    String? search,
    String? role,
    String? status,
    String? kycStatus,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (role != null) queryParams['role'] = role;
    if (status != null) queryParams['status'] = status;
    if (kycStatus != null) queryParams['kyc_status'] = kycStatus;

    final data = await _client.get('/admin/users', query: queryParams);
    return PaginatedAdminUsers.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<AdminUserSummary> getUserDetail(String userId) async {
    final data = await _client.get('/admin/users/$userId');
    return AdminUserSummary.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<AdminUserSummary> suspendUser(String userId) async {
    final data = await _client.post('/admin/users/$userId/suspend');
    return AdminUserSummary.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<AdminUserSummary> reactivateUser(String userId) async {
    final data = await _client.post('/admin/users/$userId/reactivate');
    return AdminUserSummary.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<PaginatedAdminDisputes> listDisputes({
    String? status,
    String? priority,
    String? buyerId,
    String? sellerId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;
    if (buyerId != null) queryParams['buyer_id'] = buyerId;
    if (sellerId != null) queryParams['seller_id'] = sellerId;

    final data = await _client.get('/admin/disputes', query: queryParams);
    return PaginatedAdminDisputes.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<AdminDisputeSummary> getDisputeDetail(String disputeId) async {
    final data = await _client.get('/admin/disputes/$disputeId');
    return AdminDisputeSummary.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<DisputeActionResponse> resolveDispute(
    String disputeId,
    DisputeResolutionRequest request,
  ) async {
    final data = await _client.post(
      '/admin/disputes/$disputeId/resolve',
      body: request.toJson(),
    );
    return DisputeActionResponse.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<DisputeActionResponse> rejectDispute(
    String disputeId,
    DisputeResolutionRequest request,
  ) async {
    final data = await _client.post(
      '/admin/disputes/$disputeId/reject',
      body: request.toJson(),
    );
    return DisputeActionResponse.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<DisputeActionResponse> assignDispute(String disputeId) async {
    final data = await _client.post('/admin/disputes/$disputeId/assign');
    return DisputeActionResponse.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<PaginatedAuditLogs> listAuditLogs({
    String? search,
    String? eventType,
    String? severity,
    String? actorId,
    String? resourceType,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (eventType != null) queryParams['event_type'] = eventType;
    if (severity != null) queryParams['severity'] = severity;
    if (actorId != null) queryParams['actor_id'] = actorId;
    if (resourceType != null) queryParams['resource_type'] = resourceType;

    final data = await _client.get('/admin/audit-logs', query: queryParams);
    return PaginatedAuditLogs.fromJson(data as Map<String, Object?>);
  }
}

/// Deterministic mock implementation.
class AdminMgmtMockRepository implements AdminMgmtRepository {
  AdminMgmtMockRepository() {
    _users ??= _initMockUsers();
  }

  static List<AdminUserSummary>? _users;

  @override
  Future<PaginatedAdminUsers> listUsers({
    String? search,
    String? role,
    String? status,
    String? kycStatus,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final all = _users ?? _initMockUsers();
    var filtered = all;

    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      filtered = all
          .where(
            (u) =>
                u.fullName.toLowerCase().contains(lower) ||
                (u.email?.toLowerCase().contains(lower) ?? false),
          )
          .toList();
    }
    if (role != null) filtered = filtered.where((u) => u.role == role).toList();
    if (status == 'active')
      filtered = filtered.where((u) => u.isActive).toList();
    if (status == 'suspended')
      filtered = filtered.where((u) => !u.isActive).toList();
    if (kycStatus != null)
      filtered = filtered.where((u) => u.kycStatus == kycStatus).toList();

    final total = filtered.length;
    final totalPages = (total + pageSize - 1) ~/ pageSize;
    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();

    return PaginatedAdminUsers(
      items: items,
      page: page,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<AdminUserSummary> getUserDetail(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final user = (_users ?? _initMockUsers())
        .where((u) => u.id == userId)
        .firstOrNull;
    if (user == null)
      throw ApiException(code: 'HTTP_404', message: 'User not found');
    return user;
  }

  @override
  Future<AdminUserSummary> suspendUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final all = _users ?? _initMockUsers();
    final index = all.indexWhere((u) => u.id == userId);
    if (index == -1)
      throw ApiException(code: 'HTTP_404', message: 'User not found');
    final updated = all[index].copyWith(isActive: false);
    all[index] = updated;
    return updated;
  }

  @override
  Future<AdminUserSummary> reactivateUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final all = _users ?? _initMockUsers();
    final index = all.indexWhere((u) => u.id == userId);
    if (index == -1)
      throw ApiException(code: 'HTTP_404', message: 'User not found');
    final updated = all[index].copyWith(isActive: true);
    all[index] = updated;
    return updated;
  }

  @override
  Future<PaginatedAdminDisputes> listDisputes({
    String? status,
    String? priority,
    String? buyerId,
    String? sellerId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final all = _getMockDisputes();
    var filtered = all;

    if (status != null)
      filtered = filtered.where((d) => d.status == status).toList();
    if (priority != null)
      filtered = filtered.where((d) => d.priority == priority).toList();
    if (buyerId != null)
      filtered = filtered.where((d) => d.buyerId == buyerId).toList();
    if (sellerId != null)
      filtered = filtered.where((d) => d.sellerId == sellerId).toList();

    final total = filtered.length;
    final totalPages = (total + pageSize - 1) ~/ pageSize;
    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();

    return PaginatedAdminDisputes(
      items: items,
      page: page,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<AdminDisputeSummary> getDisputeDetail(String disputeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final dispute = _getMockDisputes()
        .where((d) => d.id == disputeId)
        .firstOrNull;
    if (dispute == null)
      throw ApiException(code: 'HTTP_404', message: 'Dispute not found');
    return dispute;
  }

  @override
  Future<DisputeActionResponse> resolveDispute(
    String disputeId,
    DisputeResolutionRequest request,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return DisputeActionResponse(
      id: disputeId,
      status: 'resolved',
      message: 'Dispute resolved successfully.',
    );
  }

  @override
  Future<DisputeActionResponse> rejectDispute(
    String disputeId,
    DisputeResolutionRequest request,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return DisputeActionResponse(
      id: disputeId,
      status: 'rejected',
      message: 'Dispute rejected.',
    );
  }

  @override
  Future<DisputeActionResponse> assignDispute(String disputeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return DisputeActionResponse(
      id: disputeId,
      status: 'assigned',
      message: 'Dispute assigned.',
    );
  }

  @override
  Future<PaginatedAuditLogs> listAuditLogs({
    String? search,
    String? eventType,
    String? severity,
    String? actorId,
    String? resourceType,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final all = _getMockAuditLogs();
    var filtered = all;

    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      filtered = all
          .where(
            (l) =>
                l.summary.toLowerCase().contains(lower) ||
                l.action.toLowerCase().contains(lower) ||
                (l.actorName?.toLowerCase().contains(lower) ?? false),
          )
          .toList();
    }
    if (eventType != null)
      filtered = filtered.where((l) => l.eventType == eventType).toList();
    if (severity != null)
      filtered = filtered.where((l) => l.severity == severity).toList();
    if (actorId != null)
      filtered = filtered.where((l) => l.actorUserId == actorId).toList();
    if (resourceType != null)
      filtered = filtered.where((l) => l.resourceType == resourceType).toList();

    final total = filtered.length;
    final totalPages = (total + pageSize - 1) ~/ pageSize;
    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();

    return PaginatedAuditLogs(
      items: items,
      page: page,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
    );
  }

  List<AdminUserSummary> _initMockUsers() {
    final now = DateTime.now();
    return [
      AdminUserSummary(
        id: 'admin-001',
        fullName: 'Admin VoltShare',
        email: 'admin@voltshare-demo.local',
        role: 'admin',
        isActive: true,
        emailVerified: true,
        kycStatus: 'verified',
        city: 'Kochi',
        district: 'Ernakulam',
        createdAt: now.subtract(const Duration(days: 90)),
        listingsCount: 0,
        purchasesCount: 0,
        disputesCount: 0,
      ),
      AdminUserSummary(
        id: 'consumer-001',
        fullName: 'Ananya Nair',
        email: 'consumer1@voltshare-demo.local',
        role: 'consumer',
        isActive: true,
        emailVerified: true,
        kycStatus: 'verified',
        city: 'Thiruvananthapuram',
        district: 'Thiruvananthapuram',
        createdAt: now.subtract(const Duration(days: 30)),
        listingsCount: 0,
        purchasesCount: 3,
        disputesCount: 1,
      ),
      AdminUserSummary(
        id: 'consumer-002',
        fullName: 'Biju Mathew',
        email: 'consumer2@voltshare-demo.local',
        role: 'consumer',
        isActive: false,
        emailVerified: true,
        kycStatus: 'pending',
        city: 'Kozhikode',
        district: 'Kozhikode',
        createdAt: now.subtract(const Duration(days: 15)),
        listingsCount: 0,
        purchasesCount: 1,
        disputesCount: 0,
      ),
      AdminUserSummary(
        id: 'producer-001',
        fullName: 'Chandra Devi',
        email: 'producer1@voltshare-demo.local',
        role: 'producer',
        isActive: true,
        emailVerified: true,
        kycStatus: 'verified',
        city: 'Thodupuzha',
        district: 'Idukki',
        createdAt: now.subtract(const Duration(days: 60)),
        listingsCount: 5,
        purchasesCount: 0,
        disputesCount: 0,
      ),
      AdminUserSummary(
        id: 'producer-002',
        fullName: 'Deepak Menon',
        email: 'producer2@voltshare-demo.local',
        role: 'producer',
        isActive: true,
        emailVerified: false,
        kycStatus: 'submitted',
        city: 'Thrissur',
        district: 'Thrissur',
        createdAt: now.subtract(const Duration(days: 7)),
        listingsCount: 2,
        purchasesCount: 0,
        disputesCount: 1,
      ),
      AdminUserSummary(
        id: 'extra-001',
        fullName: 'Priya Sharma',
        email: 'priya@example.com',
        role: 'consumer',
        isActive: true,
        emailVerified: true,
        kycStatus: 'verified',
        city: 'Kochi',
        district: 'Ernakulam',
        createdAt: now.subtract(const Duration(days: 45)),
        listingsCount: 0,
        purchasesCount: 7,
        disputesCount: 0,
      ),
      AdminUserSummary(
        id: 'extra-002',
        fullName: 'Ravi Krishnan',
        email: 'ravi@example.com',
        role: 'producer',
        isActive: true,
        emailVerified: true,
        kycStatus: 'verified',
        city: 'Alappuzha',
        district: 'Alappuzha',
        createdAt: now.subtract(const Duration(days: 20)),
        listingsCount: 3,
        purchasesCount: 0,
        disputesCount: 2,
      ),
    ];
  }

  List<AdminDisputeSummary> _getMockDisputes() {
    final now = DateTime.now();
    return [
      AdminDisputeSummary(
        id: 'dsp-001',
        escrowId: 'escrow-001',
        purchaseId: 'purch-001',
        buyerId: 'consumer-001',
        buyerName: 'Ananya Nair',
        sellerId: 'producer-001',
        sellerName: 'Chandra Devi',
        listingTitle: 'Solar Surplus — Kochi',
        amountPaise: 125000,
        reason: 'Energy shortfall — received 8.5 kWh instead of 10 kWh',
        status: 'open',
        priority: 'high',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      AdminDisputeSummary(
        id: 'dsp-002',
        escrowId: 'escrow-002',
        purchaseId: 'purch-002',
        buyerId: 'extra-001',
        buyerName: 'Priya Sharma',
        sellerId: 'producer-002',
        sellerName: 'Deepak Menon',
        listingTitle: 'Wind Energy — Thrissur',
        amountPaise: 85000,
        reason: 'Delayed delivery — energy not delivered within agreed window',
        status: 'under_review',
        priority: 'high',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      AdminDisputeSummary(
        id: 'dsp-003',
        escrowId: 'escrow-003',
        purchaseId: 'purch-003',
        buyerId: 'consumer-001',
        buyerName: 'Ananya Nair',
        sellerId: 'producer-001',
        sellerName: 'Chandra Devi',
        listingTitle: 'Solar Surplus — Kochi',
        amountPaise: 42000,
        reason: 'Settlement mismatch — expected refund of not processed',
        status: 'resolved',
        priority: 'medium',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AdminDisputeSummary(
        id: 'dsp-004',
        escrowId: 'escrow-004',
        purchaseId: 'purch-004',
        buyerId: 'producer-002',
        buyerName: 'Deepak Menon',
        sellerId: 'consumer-002',
        sellerName: 'Biju Mathew (Suspended)',
        listingTitle: 'Backup Energy — Kozhikode',
        amountPaise: 95000,
        reason: 'Buyer claims energy quality below agreed standards',
        status: 'open',
        priority: 'critical',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      AdminDisputeSummary(
        id: 'dsp-005',
        escrowId: 'escrow-005',
        purchaseId: 'purch-005',
        buyerId: 'consumer-002',
        buyerName: 'Biju Mathew',
        sellerId: 'producer-001',
        sellerName: 'Chandra Devi',
        listingTitle: 'Solar Surplus — Idukki',
        amountPaise: 34000,
        reason: 'Buyer unable to verify delivery — meter data mismatch',
        status: 'under_review',
        priority: 'medium',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<AdminAuditLog> _getMockAuditLogs() {
    final now = DateTime.now();
    return [
      AdminAuditLog(
        id: 'aud-001',
        timestamp: now.subtract(const Duration(minutes: 2)),
        eventType: 'authentication',
        severity: 'info',
        actorUserId: 'admin-001',
        actorName: 'Admin VoltShare',
        actorRole: 'admin',
        action: 'admin_login',
        resourceType: 'session',
        resourceId: 'admin-001',
        summary: 'Admin logged in successfully from trusted device.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-002',
        timestamp: now.subtract(const Duration(minutes: 15)),
        eventType: 'marketplace',
        severity: 'info',
        actorUserId: 'producer-001',
        actorName: 'Chandra Devi',
        actorRole: 'producer',
        action: 'listing_created',
        resourceType: 'listing',
        resourceId: 'lst-001',
        summary: 'New solar energy listing created — 50 kWh at \u20b95.80/kWh.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-003',
        timestamp: now.subtract(const Duration(hours: 1)),
        eventType: 'financial',
        severity: 'info',
        actorUserId: 'consumer-001',
        actorName: 'Ananya Nair',
        actorRole: 'consumer',
        action: 'escrow_funded',
        resourceType: 'escrow',
        resourceId: 'escrow-001',
        summary:
            'Escrow funded successfully — \u20b91,250 held for energy purchase.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-004',
        timestamp: now.subtract(const Duration(hours: 2)),
        eventType: 'security',
        severity: 'warning',
        actorName: 'System',
        action: 'failed_login',
        resourceType: 'session',
        resourceId: 'unknown',
        summary:
            '3 failed login attempts detected for consumer1@voltshare-demo.local.',
        status: 'failed',
      ),
      AdminAuditLog(
        id: 'aud-005',
        timestamp: now.subtract(const Duration(hours: 3)),
        eventType: 'dispute',
        severity: 'critical',
        actorUserId: 'consumer-001',
        actorName: 'Ananya Nair',
        actorRole: 'consumer',
        action: 'dispute_raised',
        resourceType: 'dispute',
        resourceId: 'dsp-001',
        summary:
            'Dispute raised: Energy shortfall — 8.5 kWh received instead of 10 kWh.',
        status: 'open',
        metadataSummary: 'Amount: \u20b91,250',
      ),
      AdminAuditLog(
        id: 'aud-006',
        timestamp: now.subtract(const Duration(hours: 5)),
        eventType: 'admin_action',
        severity: 'info',
        actorUserId: 'admin-001',
        actorName: 'Admin VoltShare',
        actorRole: 'admin',
        action: 'user_suspended',
        resourceType: 'user',
        resourceId: 'consumer-002',
        summary: 'User Biju Mathew suspended: Payment compliance issue.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-007',
        timestamp: now.subtract(const Duration(hours: 8)),
        eventType: 'marketplace',
        severity: 'info',
        actorUserId: 'producer-002',
        actorName: 'Deepak Menon',
        actorRole: 'producer',
        action: 'purchase_completed',
        resourceType: 'purchase',
        resourceId: 'purch-003',
        summary: 'Energy purchase completed — 5 kWh at \u20b94.50/kWh.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-008',
        timestamp: now.subtract(const Duration(hours: 12)),
        eventType: 'settlement',
        severity: 'info',
        actorName: 'System',
        action: 'settlement_completed',
        resourceType: 'settlement',
        resourceId: 'stl-001',
        summary: 'Settlement of \u20b9820 released to producer Chandra Devi.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-009',
        timestamp: now.subtract(const Duration(days: 1)),
        eventType: 'financial',
        severity: 'info',
        actorUserId: 'consumer-001',
        actorName: 'Ananya Nair',
        actorRole: 'consumer',
        action: 'wallet_deposit',
        resourceType: 'wallet',
        resourceId: 'wallet-c1',
        summary: 'Wallet deposit of \u20b92,000 via UPI completed.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-010',
        timestamp: now.subtract(const Duration(days: 2)),
        eventType: 'security',
        severity: 'critical',
        actorName: 'System',
        action: 'anomaly_detected',
        resourceType: 'energy',
        resourceId: 'meter-012',
        summary: 'Unusual consumption pattern detected for consumer #1042.',
        status: 'investigating',
      ),
      AdminAuditLog(
        id: 'aud-011',
        timestamp: now.subtract(const Duration(days: 3)),
        eventType: 'admin_action',
        severity: 'info',
        actorUserId: 'admin-001',
        actorName: 'Admin VoltShare',
        actorRole: 'admin',
        action: 'dispute_resolved',
        resourceType: 'dispute',
        resourceId: 'dsp-003',
        summary:
            'Dispute resolved: Settlement adjustment of \u20b9350 credited to buyer.',
        status: 'succeeded',
      ),
      AdminAuditLog(
        id: 'aud-012',
        timestamp: now.subtract(const Duration(days: 5)),
        eventType: 'authentication',
        severity: 'warning',
        actorName: 'System',
        action: 'new_device_login',
        resourceType: 'session',
        resourceId: 'consumer-002',
        summary: 'New device login detected for Biju Mathew from Kozhikode.',
        status: 'succeeded',
      ),
    ];
  }
}
