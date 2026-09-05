import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kyc_repository.dart';
import '../domain/kyc_models.dart';

final myKycProvider = FutureProvider<KycRecord?>((ref) {
  return ref.watch(kycRepositoryProvider).getMyKyc();
});

final kycStatusProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(kycRepositoryProvider).getKycStatus();
});

final kycAdminSummaryProvider = FutureProvider<KycAdminSummary>((ref) {
  return ref.watch(kycRepositoryProvider).getAdminSummary();
});

final kycAdminListProvider = FutureProvider.family<PaginatedKycRecords, KycAdminListParams>((ref, params) {
  return ref.watch(kycRepositoryProvider).listAll(
    status: params.status,
    search: params.search,
    page: params.page,
    pageSize: params.pageSize,
  );
});

class KycAdminListParams {
  const KycAdminListParams({this.status, this.search, this.page = 1, this.pageSize = 20});
  final String? status;
  final String? search;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KycAdminListParams &&
        other.status == status &&
        other.search == search &&
        other.page == page &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode => Object.hash(status, search, page, pageSize);
}

final canPurchaseProvider = FutureProvider<bool>((ref) async {
  final status = await ref.watch(kycStatusProvider.future);
  return (status['can_purchase'] as bool?) ?? false;
});

final canSellProvider = FutureProvider<bool>((ref) async {
  final status = await ref.watch(kycStatusProvider.future);
  return (status['can_sell'] as bool?) ?? false;
});

final needsKycProvider = FutureProvider<bool>((ref) async {
  final status = await ref.watch(kycStatusProvider.future);
  return (status['needs_kyc'] as bool?) ?? true;
});
