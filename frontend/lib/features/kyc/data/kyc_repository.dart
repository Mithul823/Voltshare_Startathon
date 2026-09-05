import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/kyc_models.dart';

abstract class KycRepository {
  Future<KycRecord> submitKyc(KycRecord submission);
  Future<KycRecord?> getMyKyc();
  Future<KycAdminSummary> getAdminSummary();
  Future<PaginatedKycRecords> listAll({String? status, String? search, int page = 1, int pageSize = 20});
  Future<KycRecord> reviewKyc(String kycId, String status, String? remarks);
  Future<Map<String, dynamic>> getKycStatus();
}

class MockKycRepository implements KycRepository {
  KycRecord? _myKyc;
  final Map<String, KycRecord> records = {};
  final Map<String, dynamic> _users = {};

  @override
  Future<KycRecord> submitKyc(KycRecord submission) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final record = KycRecord(
      id: 'KYC-${DateTime.now().millisecondsSinceEpoch}',
      userId: submission.userId,
      userRole: submission.userRole,
      fullName: submission.fullName,
      dateOfBirth: submission.dateOfBirth,
      address: submission.address,
      district: submission.district,
      state: submission.state,
      pinCode: submission.pinCode,
      idType: submission.idType,
      idNumber: submission.idNumber,
      phone: submission.phone,
      status: KycStatus.pending,
      submittedAt: DateTime.now(),
      renewableEnergySource: submission.renewableEnergySource,
      installedCapacityKw: submission.installedCapacityKw,
      plantLocation: submission.plantLocation,
      utilityLicenseNumber: submission.utilityLicenseNumber,
      bankAccountNumber: submission.bankAccountNumber,
      bankIfscCode: submission.bankIfscCode,
      bankAccountHolder: submission.bankAccountHolder,
    );
    _myKyc = record;
    records[record.id] = record;
    _users[submission.userId] = {'id': submission.userId, 'full_name': submission.fullName, 'role': submission.userRole};
    return record;
  }

  @override
  Future<KycRecord?> getMyKyc() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _myKyc;
  }

  @override
  Future<KycAdminSummary> getAdminSummary() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final allRecords = records.values.toList();
    return KycAdminSummary(
      totalApplications: allRecords.length,
      pending: allRecords.where((r) => r.status == KycStatus.pending).length,
      verified: allRecords.where((r) => r.status == KycStatus.verified).length,
      rejected: allRecords.where((r) => r.status == KycStatus.rejected).length,
      resubmissionRequested: allRecords.where((r) => r.status == KycStatus.resubmissionRequested).length,
    );
  }

  @override
  Future<PaginatedKycRecords> listAll({String? status, String? search, int page = 1, int pageSize = 20}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    var items = records.values.toList();
    if (status != null) items = items.where((r) => r.status.value == status).toList();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      items = items.where((r) => r.fullName.toLowerCase().contains(q) || r.idNumber.toLowerCase().contains(q)).toList();
    }
    items.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
    final total = items.length;
    final totalPages = (total + pageSize - 1) ~/ pageSize;
    final start = (page - 1) * pageSize;
    final end = start + pageSize > total ? total : start + pageSize;
    return PaginatedKycRecords(
      items: items.sublist(start, end),
      page: page,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<KycRecord> reviewKyc(String kycId, String status, String? remarks) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final existing = records[kycId];
    if (existing == null) throw const AppException('KYC record not found.');
    final updated = KycRecord(
      id: existing.id,
      userId: existing.userId,
      userRole: existing.userRole,
      fullName: existing.fullName,
      dateOfBirth: existing.dateOfBirth,
      address: existing.address,
      district: existing.district,
      state: existing.state,
      pinCode: existing.pinCode,
      idType: existing.idType,
      idNumber: existing.idNumber,
      phone: existing.phone,
      selfieUrl: existing.selfieUrl,
      idProofUrl: existing.idProofUrl,
      ownershipProofUrl: existing.ownershipProofUrl,
      status: KycStatus.fromValue(status),
      reviewedBy: 'admin',
      reviewedAt: DateTime.now(),
      remarks: remarks,
      submittedAt: existing.submittedAt,
      renewableEnergySource: existing.renewableEnergySource,
      installedCapacityKw: existing.installedCapacityKw,
      plantLocation: existing.plantLocation,
      utilityLicenseNumber: existing.utilityLicenseNumber,
      bankAccountNumber: existing.bankAccountNumber,
      bankIfscCode: existing.bankIfscCode,
      bankAccountHolder: existing.bankAccountHolder,
    );
    records[kycId] = updated;
    if (_myKyc?.id == kycId) _myKyc = updated;
    return updated;
  }

  @override
  Future<Map<String, dynamic>> getKycStatus() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (_myKyc == null) return {'can_purchase': false, 'can_sell': false, 'needs_kyc': true};
    return {
      'can_purchase': _myKyc!.canPurchase,
      'can_sell': _myKyc!.canSell,
      'needs_kyc': _myKyc!.needsSubmission,
    };
  }
}

class ApiKycRepository implements KycRepository {
  ApiKycRepository(this._client);
  final ApiClient _client;

  @override
  Future<KycRecord> submitKyc(KycRecord submission) async {
    final data = await _client.post('/kyc', body: submission.toJson());
    return KycRecord.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<KycRecord?> getMyKyc() async {
    try {
      final data = await _client.get('/kyc/me');
      if (data == null) return null;
      return KycRecord.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<KycAdminSummary> getAdminSummary() async {
    final data = await _client.get('/admin/kyc/summary');
    return KycAdminSummary.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<PaginatedKycRecords> listAll({String? status, String? search, int page = 1, int pageSize = 20}) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (status != null) 'status': status,
      if (search != null) 'search': search,
    };
    final data = await _client.get('/admin/kyc', query: params);
    return PaginatedKycRecords.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<KycRecord> reviewKyc(String kycId, String status, String? remarks) async {
    final body = <String, dynamic>{'status': status};
    if (remarks != null) body['remarks'] = remarks;
    final data = await _client.patch('/admin/kyc/$kycId/review', body: body);
    return KycRecord.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getKycStatus() async {
    final data = await _client.get('/kyc/status');
    return data as Map<String, dynamic>;
  }
}

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return ApiKycRepository(ref.watch(apiClientProvider));
  }
  return MockKycRepository();
});
