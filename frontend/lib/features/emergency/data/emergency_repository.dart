import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'emergency_models.dart';

/// Abstract repository for emergency assistance.
abstract class EmergencyRepository {
  Future<List<EmergencyRequest>> getMyRequests();
  Future<EmergencyRequest> createRequest(Map<String, dynamic> data);
  Future<EmergencyRequest> getRequest(String requestId);

  // Admin
  Future<List<EmergencyRequest>> getAllRequests();
  Future<EmergencyRequest> updateRequest(
    String requestId,
    Map<String, dynamic> data,
  );
  Future<EmergencyAllocation> createAllocation(Map<String, dynamic> data);
  Future<EmergencySummary> getSummary();
}

/// Provider that selects mock or live repository based on USE_MOCK_BACKEND.
final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return EmergencyApiRepository(ref.watch(apiClientProvider));
  }
  return EmergencyMockRepository();
});

/// Live API implementation.
class EmergencyApiRepository implements EmergencyRepository {
  EmergencyApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<EmergencyRequest>> getMyRequests() async {
    final data = await _client.get('/emergency/mine');
    return (data as List)
        .map((e) => EmergencyRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EmergencyRequest> createRequest(Map<String, dynamic> data) async {
    final result = await _client.post('/emergency', body: data);
    return EmergencyRequest.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<EmergencyRequest> getRequest(String requestId) async {
    final result = await _client.get('/emergency/$requestId');
    return EmergencyRequest.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<List<EmergencyRequest>> getAllRequests() async {
    final data = await _client.get('/admin/emergency/requests');
    return (data as List)
        .map((e) => EmergencyRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EmergencyRequest> updateRequest(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final result = await _client.patch(
      '/admin/emergency/requests/$requestId',
      body: data,
    );
    return EmergencyRequest.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<EmergencyAllocation> createAllocation(
    Map<String, dynamic> data,
  ) async {
    final result = await _client.post(
      '/admin/emergency/allocations',
      body: data,
    );
    return EmergencyAllocation.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<EmergencySummary> getSummary() async {
    final result = await _client.get('/admin/emergency/summary');
    return EmergencySummary.fromJson(result as Map<String, dynamic>);
  }
}

/// Deterministic mock implementation.
class EmergencyMockRepository implements EmergencyRepository {
  EmergencyMockRepository();

  final List<EmergencyRequest> _mockRequests = [];
  int _idCounter = 0;

  @override
  Future<List<EmergencyRequest>> getMyRequests() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockRequests.where((r) => r.consumerId == 'current-user').toList();
  }

  @override
  Future<EmergencyRequest> createRequest(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _idCounter++;
    final now = DateTime.now();
    final request = EmergencyRequest(
      id: 'EMR-MOCK-${_idCounter.toString().padLeft(4, '0')}',
      consumerId: 'current-user',
      consumerName: 'Test Consumer',
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      description: data['description'] as String? ?? '',
      requiredEnergyKwh: (data['required_energy_kwh'] as num?)?.toDouble() ?? 0,
      priority: data['priority'] as String? ?? 'Medium',
      status: 'Pending',
      latitude: data['latitude'] as double?,
      longitude: data['longitude'] as double?,
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      imageUrl: data['image_url'] as String?,
      createdAt: now,
      updatedAt: now,
    );
    _mockRequests.insert(0, request);
    return request;
  }

  @override
  Future<EmergencyRequest> getRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _mockRequests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => _createDemoRequest(),
    );
  }

  @override
  Future<List<EmergencyRequest>> getAllRequests() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_mockRequests.isEmpty) {
      _seedRequests();
    }
    return List.from(_mockRequests);
  }

  @override
  Future<EmergencyRequest> updateRequest(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) throw Exception('Request not found');

    final existing = _mockRequests[index];
    final updatedJson = {
      'id': existing.id,
      'consumer_id': existing.consumerId,
      'consumer_name': existing.consumerName,
      'title': existing.title,
      'category': existing.category,
      'description': existing.description,
      'required_energy_kwh': existing.requiredEnergyKwh,
      'allocated_energy_kwh':
          data['allocated_energy_kwh'] ?? existing.allocatedEnergyKwh,
      'priority': existing.priority,
      'status': data['status'] ?? existing.status,
      'latitude': existing.latitude,
      'longitude': existing.longitude,
      'address': existing.address,
      'phone': existing.phone,
      'admin_notes': data['admin_notes'] ?? existing.adminNotes,
      'created_at': existing.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Update status-based timestamps
    if (data['status'] == 'Approved') {
      updatedJson['approved_at'] = DateTime.now().toIso8601String();
    }
    if (data['status'] == 'Completed') {
      updatedJson['completed_at'] = DateTime.now().toIso8601String();
    }

    final updated = EmergencyRequest.fromJson(updatedJson);
    _mockRequests[index] = updated;
    return updated;
  }

  @override
  Future<EmergencyAllocation> createAllocation(
    Map<String, dynamic> data,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return EmergencyAllocation(
      id: 'EMA-MOCK-${(_idCounter++).toString().padLeft(4, '0')}',
      requestId: data['request_id'] as String? ?? '',
      source: data['source'] as String? ?? 'Government Reserve',
      allocatedEnergy: (data['allocated_energy'] as num?)?.toDouble() ?? 0,
      remarks: data['remarks'] as String?,
      allocatedBy: 'admin-current',
      allocatedAt: DateTime.now(),
    );
  }

  @override
  Future<EmergencySummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_mockRequests.isEmpty) {
      _seedRequests();
    }
    int pending = 0, approved = 0, rejected = 0, completed = 0, critical = 0;
    for (final r in _mockRequests) {
      switch (r.status) {
        case 'Pending':
          pending++;
          break;
        case 'Approved':
          approved++;
          break;
        case 'Rejected':
          rejected++;
          break;
        case 'Completed':
          completed++;
          break;
      }
      if (r.isCritical) critical++;
    }
    return EmergencySummary(
      total: _mockRequests.length,
      pending: pending,
      approved: approved,
      rejected: rejected,
      completed: completed,
      critical: critical,
    );
  }

  EmergencyRequest _createDemoRequest() {
    return EmergencyRequest(
      id: 'EMR-MOCK-0001',
      consumerId: 'current-user',
      consumerName: 'Ananya Nair',
      title: 'Medical Emergency - Life Support Equipment',
      category: 'Medical',
      description:
          'Need urgent power for life support equipment at home due to grid failure.',
      requiredEnergyKwh: 15.0,
      priority: 'Critical',
      status: 'Approved',
      address: '123 Main St, Kochi',
      phone: '+91-9876543210',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      approvedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
  }

  void _seedRequests() {
    final now = DateTime.now();
    _mockRequests.addAll([
      EmergencyRequest(
        id: 'EMR-MOCK-0001',
        consumerId: 'consumer-001',
        consumerName: 'Ananya Nair',
        title: 'Medical Emergency - Life Support Equipment',
        category: 'Medical',
        description:
            'Need urgent power for life support equipment at home due to grid failure.',
        requiredEnergyKwh: 15.0,
        allocatedEnergyKwh: 15.0,
        priority: 'Critical',
        status: 'Completed',
        address: '123 Main St, Kochi',
        phone: '+91-9876543210',
        createdAt: now.subtract(const Duration(hours: 24)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        approvedAt: now.subtract(const Duration(hours: 23)),
        completedAt: now.subtract(const Duration(hours: 1)),
      ),
      EmergencyRequest(
        id: 'EMR-MOCK-0002',
        consumerId: 'consumer-002',
        consumerName: 'Biju Mathew',
        title: 'Flood Relief - Community Shelter',
        category: 'Flood',
        description:
            'Power needed for community shelter housing 50 people after flooding.',
        requiredEnergyKwh: 50.0,
        allocatedEnergyKwh: 40.0,
        priority: 'Critical',
        status: 'Approved',
        address: 'Flood Relief Camp, Kozhikode',
        phone: '+91-9876543211',
        latitude: 11.2588,
        longitude: 75.7804,
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        approvedAt: now.subtract(const Duration(hours: 4)),
      ),
      EmergencyRequest(
        id: 'EMR-MOCK-0003',
        consumerId: 'consumer-003',
        consumerName: 'Priya Sharma',
        title: 'Hospital Backup Power',
        category: 'Hospital',
        description:
            'Backup power required for critical medical equipment during maintenance.',
        requiredEnergyKwh: 100.0,
        priority: 'High',
        status: 'Pending',
        address: 'City Hospital, Kochi',
        phone: '+91-9876543212',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      EmergencyRequest(
        id: 'EMR-MOCK-0004',
        consumerId: 'consumer-004',
        consumerName: 'Ravi Krishnan',
        title: 'Fire Rescue Support',
        category: 'Fire',
        description:
            'Emergency power for fire rescue operations at commercial building.',
        requiredEnergyKwh: 25.0,
        priority: 'Critical',
        status: 'In Progress',
        address: 'Market Complex, Thrissur',
        phone: '+91-9876543213',
        createdAt: now.subtract(const Duration(minutes: 45)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
        approvedAt: now.subtract(const Duration(minutes: 30)),
      ),
      EmergencyRequest(
        id: 'EMR-MOCK-0005',
        consumerId: 'consumer-005',
        consumerName: 'Deepak Menon',
        title: 'Generator Failure - Medical Equipment',
        category: 'Medical',
        description:
            'Primary generator failed. Need immediate power backup for medical devices.',
        requiredEnergyKwh: 10.0,
        priority: 'Critical',
        status: 'Pending',
        address: 'Green Valley, Thrissur',
        phone: '+91-9876543214',
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
      ),
    ]);
  }
}
