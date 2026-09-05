import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'support_models.dart';

/// Abstract repository for support tickets.
abstract class SupportRepository {
  // User-facing
  Future<List<SupportTicket>> getMyTickets();
  Future<SupportTicket> createTicket(Map<String, dynamic> data);
  Future<SupportTicket> getTicket(String ticketId);
  Future<List<SupportMessage>> getMessages(String ticketId);
  Future<SupportMessage> replyToTicket(String ticketId, String message);

  // Admin
  Future<List<SupportTicket>> getAllTickets();
  Future<SupportTicket> updateTicket(String ticketId, Map<String, dynamic> data);
  Future<SupportSummary> getSummary();
}

/// Provider that selects mock or live repository.
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return SupportApiRepository(ref.watch(apiClientProvider));
  }
  return SupportMockRepository();
});

/// Live API implementation.
class SupportApiRepository implements SupportRepository {
  SupportApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<SupportTicket>> getMyTickets() async {
    final data = await _client.get('/support/mine');
    return (data as List).map((e) => SupportTicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<SupportTicket> createTicket(Map<String, dynamic> data) async {
    final result = await _client.post('/support', body: data);
    return SupportTicket.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<SupportTicket> getTicket(String ticketId) async {
    final result = await _client.get('/support/$ticketId');
    return SupportTicket.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final data = await _client.get('/support/$ticketId/messages');
    return (data as List).map((e) => SupportMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<SupportMessage> replyToTicket(String ticketId, String message) async {
    final result = await _client.post('/support/$ticketId/reply', body: {'message': message});
    return SupportMessage.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<List<SupportTicket>> getAllTickets() async {
    final data = await _client.get('/admin/support/tickets');
    return (data as List).map((e) => SupportTicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<SupportTicket> updateTicket(String ticketId, Map<String, dynamic> data) async {
    final result = await _client.patch('/admin/support/tickets/$ticketId', body: data);
    return SupportTicket.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<SupportSummary> getSummary() async {
    final result = await _client.get('/admin/support/summary');
    return SupportSummary.fromJson(result as Map<String, dynamic>);
  }
}

/// Deterministic mock implementation.
class SupportMockRepository implements SupportRepository {
  SupportMockRepository();

  final List<SupportTicket> _mockTickets = [];
  final Map<String, List<SupportMessage>> _mockMessages = {};
  int _idCounter = 0;

  @override
  Future<List<SupportTicket>> getMyTickets({String? userId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_mockTickets.isEmpty) _seedTickets();
    return _mockTickets.where((t) => t.userId == (userId ?? 'current-user')).toList();
  }

  @override
  Future<SupportTicket> createTicket(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _idCounter++;
    final now = DateTime.now();
    final ticket = SupportTicket(
      id: 'TKT-MOCK-${_idCounter.toString().padLeft(4, '0')}',
      userId: 'current-user',
      userName: 'Test User',
      userRole: 'consumer',
      category: data['category'] as String? ?? 'Other',
      subject: data['subject'] as String? ?? '',
      description: data['description'] as String? ?? '',
      priority: data['priority'] as String? ?? 'Medium',
      status: 'Open',
      createdAt: now,
      updatedAt: now,
      messageCount: 1,
    );
    _mockTickets.insert(0, ticket);
    _mockMessages[ticket.id] = [
      SupportMessage(
        id: 'MSG-MOCK-${_idCounter}',
        ticketId: ticket.id,
        senderId: 'current-user',
        senderName: 'Test User',
        message: ticket.description,
        createdAt: now,
      ),
    ];
    return ticket;
  }

  @override
  Future<SupportTicket> getTicket(String ticketId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _mockTickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => SupportTicket(
        id: ticketId,
        userId: 'sample-user',
        userName: 'Sample User',
        userRole: 'consumer',
        category: 'Other',
        subject: 'How to buy energy?',
        description: 'I need help understanding how to purchase energy from the marketplace.',
        priority: 'Low',
        status: 'Resolved',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
        resolvedAt: DateTime.now().subtract(const Duration(hours: 6)),
        messageCount: 4,
      ),
    );
  }

  @override
  Future<List<SupportMessage>> getMessages(String ticketId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockMessages[ticketId] ?? _seedMessages(ticketId);
  }

  @override
  Future<SupportMessage> replyToTicket(String ticketId, String message) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _idCounter++;
    final msg = SupportMessage(
      id: 'MSG-MOCK-${_idCounter.toString().padLeft(4, '0')}',
      ticketId: ticketId,
      senderId: 'current-user',
      senderName: 'Test User',
      message: message,
      createdAt: DateTime.now(),
    );
    _mockMessages[ticketId] = [...(_mockMessages[ticketId] ?? []), msg];
    return msg;
  }

  @override
  Future<List<SupportTicket>> getAllTickets() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_mockTickets.isEmpty) _seedTickets();
    return List.from(_mockTickets);
  }

  @override
  Future<SupportTicket> updateTicket(String ticketId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _mockTickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) throw Exception('Ticket not found');

    final existing = _mockTickets[index];
    final updatedJson = {
      'id': existing.id,
      'user_id': existing.userId,
      'user_name': existing.userName,
      'user_role': existing.userRole,
      'category': existing.category,
      'subject': existing.subject,
      'description': existing.description,
      'priority': existing.priority,
      'status': data['status'] ?? existing.status,
      'assigned_admin': data['assigned_admin'] ?? existing.assignedAdmin,
      'created_at': existing.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'message_count': existing.messageCount,
    };
    final updated = SupportTicket.fromJson(updatedJson);
    _mockTickets[index] = updated;
    return updated;
  }

  @override
  Future<SupportSummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_mockTickets.isEmpty) _seedTickets();
    int open = 0, inProgress = 0, resolved = 0, closed = 0;
    for (final t in _mockTickets) {
      switch (t.status) {
        case 'Open': open++; break;
        case 'In Progress': inProgress++; break;
        case 'Resolved': resolved++; break;
        case 'Closed': closed++; break;
      }
    }
    return SupportSummary(
      total: _mockTickets.length,
      open: open,
      inProgress: inProgress,
      resolved: resolved,
      closed: closed,
    );
  }

  void _seedTickets() {
    final now = DateTime.now();
    _mockTickets.addAll([
      SupportTicket(
        id: 'TKT-MOCK-0001',
        userId: 'current-user',
        userName: 'Test User',
        userRole: 'consumer',
        category: 'Marketplace',
        subject: 'Unable to complete purchase',
        description: 'I keep getting an error when trying to purchase energy from the marketplace.',
        priority: 'High',
        status: 'Open',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        messageCount: 1,
      ),
      SupportTicket(
        id: 'TKT-MOCK-0002',
        userId: 'consumer-001',
        userName: 'Ananya Nair',
        userRole: 'consumer',
        category: 'Wallet',
        subject: 'Deposit not showing up',
        description: 'I deposited ₹5000 an hour ago but my wallet balance is not updated.',
        priority: 'High',
        status: 'In Progress',
        assignedAdmin: 'admin-001',
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        messageCount: 3,
      ),
      SupportTicket(
        id: 'TKT-MOCK-0003',
        userId: 'producer-001',
        userName: 'Chandra Devi',
        userRole: 'producer',
        category: 'Account',
        subject: 'Change account email',
        description: 'I need to update my registered email address.',
        priority: 'Low',
        status: 'Resolved',
        assignedAdmin: 'admin-001',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 12)),
        resolvedAt: now.subtract(const Duration(hours: 12)),
        messageCount: 4,
      ),
      SupportTicket(
        id: 'TKT-MOCK-0004',
        userId: 'consumer-002',
        userName: 'Biju Mathew',
        userRole: 'consumer',
        category: 'Bug',
        subject: 'App crashes on login',
        description: 'The app crashes every time I try to log in after the latest update.',
        priority: 'Critical',
        status: 'Open',
        createdAt: now.subtract(const Duration(minutes: 30)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        messageCount: 1,
      ),
    ]);
  }

  List<SupportMessage> _seedMessages(String ticketId) {
    final messages = [
      SupportMessage(
        id: 'MSG-0001',
        ticketId: ticketId,
        senderId: 'sample-user',
        senderName: 'Sample User',
        message: 'I need help with the marketplace.',
        isAdminReply: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      SupportMessage(
        id: 'MSG-0002',
        ticketId: ticketId,
        senderId: 'admin-001',
        senderName: 'Admin VoltShare',
        message: 'Hello! I\'d be happy to help. Could you please describe the issue you\'re facing?',
        isAdminReply: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2)).add(const Duration(hours: 1)),
      ),
      SupportMessage(
        id: 'MSG-0003',
        ticketId: ticketId,
        senderId: 'sample-user',
        senderName: 'Sample User',
        message: 'I cannot find the buy button on the marketplace screen.',
        isAdminReply: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)).add(const Duration(hours: 2)),
      ),
      SupportMessage(
        id: 'MSG-0004',
        ticketId: ticketId,
        senderId: 'admin-001',
        senderName: 'Admin VoltShare',
        message: 'I see. The buy button should appear when you select a listing. Let me check if there\'s a permissions issue with your account.',
        isAdminReply: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
    _mockMessages[ticketId] = messages;
    return messages;
  }
}
