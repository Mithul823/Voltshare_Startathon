/// Admin user summary returned by the API.
class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    this.fullName = 'VoltShare User',
    this.email,
    this.role = 'consumer',
    this.isActive = true,
    this.emailVerified = false,
    this.kycStatus,
    this.city,
    this.district,
    this.createdAt,
    this.lastLoginAt,
    this.listingsCount = 0,
    this.purchasesCount = 0,
    this.disputesCount = 0,
  });

  factory AdminUserSummary.fromJson(Map<String, Object?> json) {
    return AdminUserSummary(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'VoltShare User',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'consumer',
      isActive: json['is_active'] == true,
      emailVerified: json['email_verified'] == true,
      kycStatus: json['kyc_status']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      createdAt: _parseDt(json['created_at']),
      lastLoginAt: _parseDt(json['last_login_at']),
      listingsCount: _int(json['listings_count']),
      purchasesCount: _int(json['purchases_count']),
      disputesCount: _int(json['disputes_count']),
    );
  }

  final String id;
  final String fullName;
  final String? email;
  final String role;
  final bool isActive;
  final bool emailVerified;
  final String? kycStatus;
  final String? city;
  final String? district;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final int listingsCount;
  final int purchasesCount;
  final int disputesCount;

  AdminUserSummary copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    bool? isActive,
    bool? emailVerified,
    String? kycStatus,
    String? city,
    String? district,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    int? listingsCount,
    int? purchasesCount,
    int? disputesCount,
  }) {
    return AdminUserSummary(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      emailVerified: emailVerified ?? this.emailVerified,
      kycStatus: kycStatus ?? this.kycStatus,
      city: city ?? this.city,
      district: district ?? this.district,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      listingsCount: listingsCount ?? this.listingsCount,
      purchasesCount: purchasesCount ?? this.purchasesCount,
      disputesCount: disputesCount ?? this.disputesCount,
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String get displayName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last[0]}.';
    }
    return fullName;
  }

  static DateTime? _parseDt(Object? val) {
    if (val == null) return null;
    if (val is String)
      return DateTime.tryParse(
        val.replaceAll('Z', '+00:00').replaceAll('+00:00+00:00', '+00:00'),
      );
    if (val is DateTime) return val;
    return null;
  }

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}

/// Paginated response for admin users.
class PaginatedAdminUsers {
  const PaginatedAdminUsers({
    this.items = const [],
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  factory PaginatedAdminUsers.fromJson(Map<String, Object?> json) {
    final itemsList =
        (json['items'] as List<Object?>?)
            ?.map((e) => AdminUserSummary.fromJson(e as Map<String, Object?>))
            .toList() ??
        [];
    return PaginatedAdminUsers(
      items: itemsList,
      page: _int(json['page']),
      pageSize: _int(json['page_size']),
      total: _int(json['total']),
      totalPages: _int(json['total_pages']),
    );
  }

  final List<AdminUserSummary> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty && total == 0;

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}

/// Admin dispute summary returned by the API.
class AdminDisputeSummary {
  const AdminDisputeSummary({
    required this.id,
    this.escrowId,
    this.purchaseId,
    this.buyerId,
    this.buyerName,
    this.sellerId,
    this.sellerName,
    this.listingTitle,
    this.amountPaise = 0,
    this.reason = '',
    this.status = 'open',
    this.priority = 'medium',
    this.createdAt,
    this.updatedAt,
  });

  factory AdminDisputeSummary.fromJson(Map<String, Object?> json) {
    return AdminDisputeSummary(
      id: json['id']?.toString() ?? '',
      escrowId: json['escrow_id']?.toString(),
      purchaseId: json['purchase_id']?.toString(),
      buyerId: json['buyer_id']?.toString(),
      buyerName: json['buyer_name']?.toString(),
      sellerId: json['seller_id']?.toString(),
      sellerName: json['seller_name']?.toString(),
      listingTitle: json['listing_title']?.toString(),
      amountPaise: _int(json['amount_paise']),
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'medium',
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
    );
  }

  final String id;
  final String? escrowId;
  final String? purchaseId;
  final String? buyerId;
  final String? buyerName;
  final String? sellerId;
  final String? sellerName;
  final String? listingTitle;
  final int amountPaise;
  final String reason;
  final String status;
  final String priority;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get amountInr => '₹${(amountPaise / 100).toStringAsFixed(2)}';

  static DateTime? _parseDt(Object? val) {
    if (val == null) return null;
    if (val is String)
      return DateTime.tryParse(
        val.replaceAll('Z', '+00:00').replaceAll('+00:00+00:00', '+00:00'),
      );
    if (val is DateTime) return val;
    return null;
  }

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}

/// Paginated response for admin disputes.
class PaginatedAdminDisputes {
  const PaginatedAdminDisputes({
    this.items = const [],
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  factory PaginatedAdminDisputes.fromJson(Map<String, Object?> json) {
    final itemsList =
        (json['items'] as List<Object?>?)
            ?.map(
              (e) => AdminDisputeSummary.fromJson(e as Map<String, Object?>),
            )
            .toList() ??
        [];
    return PaginatedAdminDisputes(
      items: itemsList,
      page: _int(json['page']),
      pageSize: _int(json['page_size']),
      total: _int(json['total']),
      totalPages: _int(json['total_pages']),
    );
  }

  final List<AdminDisputeSummary> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty && total == 0;

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}

/// Dispute resolution request body.
class DisputeResolutionRequest {
  const DisputeResolutionRequest({
    this.resolution = 'resolved',
    this.reason = '',
    this.refundAmountPaise = 0,
    this.releaseToSellerPaise = 0,
  });

  Map<String, Object?> toJson() => {
    'resolution': resolution,
    'reason': reason,
    'refund_amount_paise': refundAmountPaise,
    'release_to_seller_paise': releaseToSellerPaise,
  };

  final String resolution;
  final String reason;
  final int refundAmountPaise;
  final int releaseToSellerPaise;
}

/// Dispute action response from the API.
class DisputeActionResponse {
  const DisputeActionResponse({
    required this.id,
    this.status = '',
    this.message = '',
  });

  factory DisputeActionResponse.fromJson(Map<String, Object?> json) {
    return DisputeActionResponse(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  final String id;
  final String status;
  final String message;
}

/// Admin audit log entry returned by the API.
class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    this.timestamp,
    this.eventType = 'system',
    this.severity = 'info',
    this.actorUserId,
    this.actorName,
    this.actorRole,
    this.action = '',
    this.resourceType,
    this.resourceId,
    this.summary = '',
    this.status,
    this.metadataSummary,
    this.sourceIp,
  });

  factory AdminAuditLog.fromJson(Map<String, Object?> json) {
    return AdminAuditLog(
      id: json['id']?.toString() ?? '',
      timestamp: _parseDt(json['timestamp']),
      eventType: json['event_type']?.toString() ?? 'system',
      severity: json['severity']?.toString() ?? 'info',
      actorUserId: json['actor_user_id']?.toString(),
      actorName: json['actor_name']?.toString(),
      actorRole: json['actor_role']?.toString(),
      action: json['action']?.toString() ?? '',
      resourceType: json['resource_type']?.toString(),
      resourceId: json['resource_id']?.toString(),
      summary: json['summary']?.toString() ?? '',
      status: json['status']?.toString(),
      metadataSummary: json['metadata_summary']?.toString(),
      sourceIp: json['source_ip']?.toString(),
    );
  }

  final String id;
  final DateTime? timestamp;
  final String eventType;
  final String severity;
  final String? actorUserId;
  final String? actorName;
  final String? actorRole;
  final String action;
  final String? resourceType;
  final String? resourceId;
  final String summary;
  final String? status;
  final String? metadataSummary;
  final String? sourceIp;

  static DateTime? _parseDt(Object? val) {
    if (val == null) return null;
    if (val is String)
      return DateTime.tryParse(
        val.replaceAll('Z', '+00:00').replaceAll('+00:00+00:00', '+00:00'),
      );
    if (val is DateTime) return val;
    return null;
  }
}

/// Paginated response for audit logs.
class PaginatedAuditLogs {
  const PaginatedAuditLogs({
    this.items = const [],
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  factory PaginatedAuditLogs.fromJson(Map<String, Object?> json) {
    final itemsList =
        (json['items'] as List<Object?>?)
            ?.map((e) => AdminAuditLog.fromJson(e as Map<String, Object?>))
            .toList() ??
        [];
    return PaginatedAuditLogs(
      items: itemsList,
      page: _int(json['page']),
      pageSize: _int(json['page_size']),
      total: _int(json['total']),
      totalPages: _int(json['total_pages']),
    );
  }

  final List<AdminAuditLog> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty && total == 0;

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}
