import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../providers/kyc_provider.dart';
import '../domain/kyc_models.dart';

class KycStatusScreen extends ConsumerWidget {
  const KycStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycAsync = ref.watch(myKycProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: kycAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Unable to load KYC status', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('$e', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(myKycProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (kyc) {
                if (kyc == null) {
                  return _buildNoKyc(context, ref, theme);
                }
                return _buildKycStatus(context, ref, kyc, theme);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoKyc(BuildContext context, WidgetRef ref, ThemeData theme) {
    return SingleChildScrollView(
      padding: AppInsets.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified_user_outlined, size: 40, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text('KYC Not Submitted', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Please complete KYC verification to access marketplace features.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.kycForm),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Start KYC Verification'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycStatus(BuildContext context, WidgetRef ref, KycRecord kyc, ThemeData theme) {
    final statusColor = switch (kyc.status) {
      KycStatus.verified => Colors.green,
      KycStatus.pending => Colors.orange,
      KycStatus.rejected => Colors.red,
      KycStatus.resubmissionRequested => Colors.orange,
      KycStatus.notSubmitted => Colors.grey,
    };
    final statusIcon = switch (kyc.status) {
      KycStatus.verified => Icons.check_circle,
      KycStatus.pending => Icons.hourglass_empty,
      KycStatus.rejected => Icons.cancel,
      KycStatus.resubmissionRequested => Icons.refresh,
      KycStatus.notSubmitted => Icons.radio_button_unchecked,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, size: 50, color: statusColor),
                ),
                const SizedBox(height: 12),
                Text(kyc.status.label, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: statusColor)),
                if (kyc.remarks != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(kyc.remarks!, textAlign: TextAlign.center, style: TextStyle(color: statusColor.withValues(alpha: 0.87))),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _InfoRow(label: 'Full Name', value: kyc.fullName),
          _InfoRow(label: 'DOB', value: kyc.dateOfBirth),
          _InfoRow(label: 'Address', value: kyc.address),
          _InfoRow(label: 'District', value: kyc.district),
          _InfoRow(label: 'State', value: kyc.state),
          _InfoRow(label: 'PIN Code', value: kyc.pinCode),
          _InfoRow(label: 'ID Type', value: kyc.idType),
          _InfoRow(label: 'ID Number',
              value: '••••${kyc.idNumber.length > 4 ? kyc.idNumber.substring(kyc.idNumber.length - 4) : kyc.idNumber}'),
          _InfoRow(label: 'Phone', value: kyc.phone),
          if (kyc.submittedAt != null) _InfoRow(label: 'Submitted', value: _formatDate(kyc.submittedAt!)),
          if (kyc.reviewedAt != null) _InfoRow(label: 'Reviewed', value: _formatDate(kyc.reviewedAt!)),
          if (kyc.renewableEnergySource != null) _InfoRow(label: 'Energy Source', value: kyc.renewableEnergySource!),
          if (kyc.installedCapacityKw != null) _InfoRow(label: 'Capacity', value: '${kyc.installedCapacityKw} kW'),
          if (kyc.plantLocation != null) _InfoRow(label: 'Plant Location', value: kyc.plantLocation!),
          if (kyc.utilityLicenseNumber != null) _InfoRow(label: 'License', value: kyc.utilityLicenseNumber!),
          const SizedBox(height: 24),
          if (kyc.needsSubmission)
            Center(
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.kycForm),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Resubmit KYC'),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
