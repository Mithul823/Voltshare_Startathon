class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String category;
  final String subject;
  final String description;
  final String priority;
  final String status;
  final String? assignedAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final int messageCount;

  const SupportTicket({
    required this.id,
    required this.userId,
    this.userName = '',
    this.userRole = '',
    required this.category,
    required this.subject,
    required this.description,
    required this.priority,
    required this.status,
    this.assignedAdmin,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.messageCount = 0,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      userRole: json['user_role'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priority: json['priority'] as String? ?? 'Medium',
      status: json['status'] as String? ?? 'Open',
      assignedAdmin: json['assigned_admin'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isOpen => status == 'Open';
  bool get isInProgress => status == 'In Progress';
  bool get isResolved => status == 'Resolved';
  bool get isClosed => status == 'Closed';
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderName;
  final String message;
  final bool isAdminReply;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    this.senderName = '',
    required this.message,
    this.isAdminReply = false,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String? ?? '',
      ticketId: json['ticket_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isAdminReply: json['is_admin_reply'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SupportSummary {
  final int total;
  final int open;
  final int inProgress;
  final int resolved;
  final int closed;

  const SupportSummary({
    this.total = 0,
    this.open = 0,
    this.inProgress = 0,
    this.resolved = 0,
    this.closed = 0,
  });

  factory SupportSummary.fromJson(Map<String, dynamic> json) {
    return SupportSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      inProgress: (json['in_progress'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
      closed: (json['closed'] as num?)?.toInt() ?? 0,
    );
  }
}
