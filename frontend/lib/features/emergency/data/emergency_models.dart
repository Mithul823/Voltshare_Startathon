class EmergencyRequest {
  final String id;
  final String consumerId;
  final String consumerName;
  final String title;
  final String category;
  final String description;
  final double requiredEnergyKwh;
  final double allocatedEnergyKwh;
  final String priority;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? phone;
  final String? imageUrl;
  final String? adminNotes;
  final String? assignedAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;

  const EmergencyRequest({
    required this.id,
    required this.consumerId,
    this.consumerName = '',
    required this.title,
    required this.category,
    required this.description,
    required this.requiredEnergyKwh,
    this.allocatedEnergyKwh = 0,
    required this.priority,
    required this.status,
    this.latitude,
    this.longitude,
    this.address,
    this.phone,
    this.imageUrl,
    this.adminNotes,
    this.assignedAdmin,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.completedAt,
  });

  factory EmergencyRequest.fromJson(Map<String, dynamic> json) {
    return EmergencyRequest(
      id: json['id'] as String? ?? '',
      consumerId: json['consumer_id'] as String? ?? '',
      consumerName: json['consumer_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiredEnergyKwh: (json['required_energy_kwh'] as num?)?.toDouble() ?? 0,
      allocatedEnergyKwh: (json['allocated_energy_kwh'] as num?)?.toDouble() ?? 0,
      priority: json['priority'] as String? ?? 'Medium',
      status: json['status'] as String? ?? 'Pending',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      imageUrl: json['image_url'] as String?,
      adminNotes: json['admin_notes'] as String?,
      assignedAdmin: json['assigned_admin'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consumer_id': consumerId,
      'title': title,
      'category': category,
      'description': description,
      'required_energy_kwh': requiredEnergyKwh,
      'allocated_energy_kwh': allocatedEnergyKwh,
      'priority': priority,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'image_url': imageUrl,
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'Pending': return 'Pending';
      case 'Approved': return 'Approved';
      case 'Rejected': return 'Rejected';
      case 'In Progress': return 'In Progress';
      case 'Completed': return 'Completed';
      default: return status;
    }
  }

  String get priorityDisplay => priority;

  bool get isCritical => priority == 'Critical';
  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';
  bool get isInProgress => status == 'In Progress';
  bool get isCompleted => status == 'Completed';
}

class EmergencyAllocation {
  final String id;
  final String requestId;
  final String source;
  final double allocatedEnergy;
  final String? remarks;
  final String allocatedBy;
  final DateTime allocatedAt;

  const EmergencyAllocation({
    required this.id,
    required this.requestId,
    required this.source,
    required this.allocatedEnergy,
    this.remarks,
    required this.allocatedBy,
    required this.allocatedAt,
  });

  factory EmergencyAllocation.fromJson(Map<String, dynamic> json) {
    return EmergencyAllocation(
      id: json['id'] as String? ?? '',
      requestId: json['request_id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      allocatedEnergy: (json['allocated_energy'] as num?)?.toDouble() ?? 0,
      remarks: json['remarks'] as String?,
      allocatedBy: json['allocated_by'] as String? ?? '',
      allocatedAt: DateTime.tryParse(json['allocated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class EmergencySummary {
  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int completed;
  final int critical;

  const EmergencySummary({
    this.total = 0,
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
    this.completed = 0,
    this.critical = 0,
  });

  factory EmergencySummary.fromJson(Map<String, dynamic> json) {
    return EmergencySummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      approved: (json['approved'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      critical: (json['critical'] as num?)?.toInt() ?? 0,
    );
  }
}
