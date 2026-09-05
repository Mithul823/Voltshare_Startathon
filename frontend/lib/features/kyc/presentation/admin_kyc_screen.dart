import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/voltshare_ui.dart';
import '../data/kyc_repository.dart';
import '../domain/kyc_models.dart';
import '../providers/kyc_provider.dart';

class AdminKycScreen extends ConsumerStatefulWidget {
  const AdminKycScreen({super.key});

  @override
  ConsumerState<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends ConsumerState<AdminKycScreen> {
  String? _statusFilter;
  String? _searchQuery;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(kycAdminSummaryProvider);
    final params = KycAdminListParams(status: _statusFilter, search: _searchQuery, page: _page);
    final listAsync = ref.watch(kycAdminListProvider(params));
    final theme = Theme.of(context);

    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'KYC Management', showBackButton: false),
            const SizedBox(height: 8),
            summaryAsync.when(
              data: (summary) => _buildSummaryCards(context, summary, theme),
              loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            _buildFilters(theme),
            const Divider(),
            listAsync.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => const SizedBox(height: 200, child: Center(child: Text('Error loading KYC applications'))),
              data: (page) => _buildList(context, page, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, KycAdminSummary summary, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SummaryCard(label: 'Total', value: '${summary.totalApplications}', color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          _SummaryCard(label: 'Pending', value: '${summary.pending}', color: Colors.orange),
          const SizedBox(width: 8),
          _SummaryCard(label: 'Verified', value: '${summary.verified}', color: Colors.green),
          const SizedBox(width: 8),
          _SummaryCard(label: 'Rejected', value: '${summary.rejected}', color: Colors.red),
          const SizedBox(width: 8),
          _SummaryCard(label: 'Resubmit', value: '${summary.resubmissionRequested}', color: Colors.purple),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    final statuses = <String?>[null, 'pending', 'verified', 'rejected'];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          ActionChip(
            label: const Text('All'),
            onPressed: () => setState(() { _statusFilter = null; _page = 1; }),
            avatar: _statusFilter == null ? const Icon(Icons.check, size: 16) : null,
          ),
          for (final status in statuses.skip(1)) ...[
            const SizedBox(width: 6),
            ActionChip(
              label: Text(status![0].toUpperCase() + status.substring(1)),
              onPressed: () => setState(() { _statusFilter = status; _page = 1; }),
              avatar: _statusFilter == status ? const Icon(Icons.check, size: 16) : null,
            ),
          ],
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final controller = TextEditingController(text: _searchQuery);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search KYC'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search by name or ID...', prefixIcon: Icon(Icons.search)),
          onSubmitted: (v) {
            setState(() { _searchQuery = v; _page = 1; });
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () { setState(() { _searchQuery = null; _page = 1; }); Navigator.pop(ctx); }, child: const Text('Clear')),
          FilledButton(onPressed: () { setState(() { _searchQuery = controller.text; _page = 1; }); Navigator.pop(ctx); }, child: const Text('Search')),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, PaginatedKycRecords pageData, ThemeData theme) {
    if (pageData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No KYC applications found'),
          ],
        ),
      );
    }
    return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: pageData.items.length + (pageData.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= pageData.items.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => setState(() => _page++),
                  child: const Text('Load More'),
                ),
              ),
            );
          }
          return _KycCard(
            record: pageData.items[index],
            onTap: () => _showDetail(context, pageData.items[index]),
          );
        },
    );
  }

  void _showDetail(BuildContext context, KycRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _KycDetailSheet(
        record: record,
        onApprove: () => _review(record.id, 'verified', null),
        onReject: () => _review(record.id, 'rejected', 'KYC application rejected.'),
        onRequestResubmit: () => _review(record.id, 'resubmission_requested', 'Additional documents required.'),
      ),
    );
  }

  void _review(String kycId, String status, String? remarks) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'verified' ? 'Approve KYC' : 'Reject KYC'),
        content: status == 'verified'
            ? const Text('Are you sure you want to approve this KYC application?')
            : TextField(
                controller: TextEditingController(text: remarks),
                decoration: const InputDecoration(hintText: 'Reason for rejection...'),
                maxLines: 3,
                onChanged: (v) => remarks = v,
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(kycRepositoryProvider).reviewKyc(kycId, status, remarks);
                ref.invalidate(kycAdminSummaryProvider);
                ref.invalidate(kycAdminListProvider(const KycAdminListParams()));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KYC ${status == "verified" ? "approved" : "rejected"}.')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(status == 'verified' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 75),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

class _KycCard extends StatelessWidget {
  final KycRecord record;
  final VoidCallback onTap;
  const _KycCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (record.status) {
      KycStatus.verified => Colors.green,
      KycStatus.pending => Colors.orange,
      KycStatus.rejected => Colors.red,
      KycStatus.resubmissionRequested => Colors.purple,
      KycStatus.notSubmitted => Colors.grey,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(_initials(record.fullName), style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('${record.userRole} • ${record.district}, ${record.state}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(record.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _KycDetailSheet extends StatelessWidget {
  final KycRecord record;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestResubmit;

  const _KycDetailSheet({
    required this.record,
    required this.onApprove,
    required this.onReject,
    required this.onRequestResubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('KYC Application', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _DetailField(label: 'Full Name', value: record.fullName),
            _DetailField(label: 'Role', value: record.userRole),
            _DetailField(label: 'DOB', value: record.dateOfBirth),
            _DetailField(label: 'Address', value: record.address),
            _DetailField(label: 'District', value: record.district),
            _DetailField(label: 'State', value: record.state),
            _DetailField(label: 'PIN Code', value: record.pinCode),
            _DetailField(label: 'ID Type', value: record.idType),
            _DetailField(label: 'ID Number', value: record.idNumber),
            _DetailField(label: 'Phone', value: record.phone),
            if (record.renewableEnergySource != null) _DetailField(label: 'Energy Source', value: record.renewableEnergySource!),
            if (record.installedCapacityKw != null) _DetailField(label: 'Capacity', value: '${record.installedCapacityKw} kW'),
            if (record.plantLocation != null) _DetailField(label: 'Plant Location', value: record.plantLocation!),
            if (record.utilityLicenseNumber != null) _DetailField(label: 'License', value: record.utilityLicenseNumber!),
            if (record.remarks != null) _DetailField(label: 'Admin Notes', value: record.remarks!),
            const Divider(height: 24),
            if (record.status == KycStatus.pending || record.status == KycStatus.resubmissionRequested) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRequestResubmit,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Resubmit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  const _DetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
