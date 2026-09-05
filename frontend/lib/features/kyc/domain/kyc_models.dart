enum KycStatus {
  notSubmitted('not_submitted', 'Not Submitted'),
  pending('pending', 'Pending'),
  verified('verified', 'Verified'),
  rejected('rejected', 'Rejected'),
  resubmissionRequested('resubmission_requested', 'Resubmission Requested');

  const KycStatus(this.value, this.label);
  final String value;
  final String label;

  static KycStatus fromValue(String value) {
    return KycStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => KycStatus.notSubmitted,
    );
  }
}

enum IdType {
  aadhar('aadhar', 'Aadhar Card'),
  pan('pan', 'PAN Card'),
  passport('passport', 'Passport'),
  driverLicense('driver_license', "Driver's License"),
  voterId('voter_id', 'Voter ID');

  const IdType(this.value, this.label);
  final String value;
  final String label;

  static IdType fromValue(String value) {
    return IdType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => IdType.aadhar,
    );
  }
}

class KycRecord {
  final String id;
  final String userId;
  final String userRole;
  final String fullName;
  final String dateOfBirth;
  final String address;
  final String district;
  final String state;
  final String pinCode;
  final String idType;
  final String idNumber;
  final String phone;
  final String? selfieUrl;
  final String? idProofUrl;
  final String? ownershipProofUrl;
  final KycStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? remarks;
  final DateTime? submittedAt;
  final String? renewableEnergySource;
  final double? installedCapacityKw;
  final String? plantLocation;
  final String? utilityLicenseNumber;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankAccountHolder;

  const KycRecord({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.fullName,
    required this.dateOfBirth,
    required this.address,
    required this.district,
    required this.state,
    required this.pinCode,
    required this.idType,
    required this.idNumber,
    required this.phone,
    this.selfieUrl,
    this.idProofUrl,
    this.ownershipProofUrl,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.remarks,
    this.submittedAt,
    this.renewableEnergySource,
    this.installedCapacityKw,
    this.plantLocation,
    this.utilityLicenseNumber,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankAccountHolder,
  });

  factory KycRecord.fromJson(Map<String, dynamic> json) {
    return KycRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      dateOfBirth: json['date_of_birth']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pinCode: json['pin_code']?.toString() ?? '',
      idType: json['id_type']?.toString() ?? '',
      idNumber: json['id_number']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      selfieUrl: json['selfie_url']?.toString(),
      idProofUrl: json['id_proof_url']?.toString(),
      ownershipProofUrl: json['ownership_proof_url']?.toString(),
      status: KycStatus.fromValue(json['status']?.toString() ?? 'not_submitted'),
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
      remarks: json['remarks']?.toString(),
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at'].toString()) : null,
      renewableEnergySource: json['renewable_energy_source']?.toString(),
      installedCapacityKw: (json['installed_capacity_kw'] as num?)?.toDouble(),
      plantLocation: json['plant_location']?.toString(),
      utilityLicenseNumber: json['utility_license_number']?.toString(),
      bankAccountNumber: json['bank_account_number']?.toString(),
      bankIfscCode: json['bank_ifsc_code']?.toString(),
      bankAccountHolder: json['bank_account_holder']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'date_of_birth': dateOfBirth,
      'address': address,
      'district': district,
      'state': state,
      'pin_code': pinCode,
      'id_type': idType,
      'id_number': idNumber,
      'phone': phone,
      if (renewableEnergySource != null) 'renewable_energy_source': renewableEnergySource,
      if (installedCapacityKw != null) 'installed_capacity_kw': installedCapacityKw,
      if (plantLocation != null) 'plant_location': plantLocation,
      if (utilityLicenseNumber != null) 'utility_license_number': utilityLicenseNumber,
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
      if (bankIfscCode != null) 'bank_ifsc_code': bankIfscCode,
      if (bankAccountHolder != null) 'bank_account_holder': bankAccountHolder,
    };
  }

  bool get canPurchase => status == KycStatus.verified;
  bool get canSell => status == KycStatus.verified;
  bool get isPending => status == KycStatus.pending;
  bool get isVerified => status == KycStatus.verified;
  bool get isRejected => status == KycStatus.rejected;
  bool get needsSubmission => status == KycStatus.notSubmitted || status == KycStatus.rejected || status == KycStatus.resubmissionRequested;
}

class KycAdminSummary {
  final int totalApplications;
  final int pending;
  final int verified;
  final int rejected;
  final int resubmissionRequested;

  const KycAdminSummary({
    this.totalApplications = 0,
    this.pending = 0,
    this.verified = 0,
    this.rejected = 0,
    this.resubmissionRequested = 0,
  });

  factory KycAdminSummary.fromJson(Map<String, dynamic> json) {
    return KycAdminSummary(
      totalApplications: (json['total_applications'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      resubmissionRequested: (json['resubmission_requested'] as num?)?.toInt() ?? 0,
    );
  }
}

class PaginatedKycRecords {
  final List<KycRecord> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const PaginatedKycRecords({
    this.items = const [],
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  factory PaginatedKycRecords.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => KycRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PaginatedKycRecords(
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
