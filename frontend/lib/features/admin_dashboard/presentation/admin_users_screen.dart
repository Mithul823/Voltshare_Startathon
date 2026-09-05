import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_models.dart';
import '../providers/admin_mgmt_provider.dart';

/// Admin Manage Users screen — replaces the development placeholder.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _searchQuery = '';
  String? _roleFilter;
  String? _statusFilter;
  String? _kycFilter;
  int _currentPage = 1;

  void _applyFilters({int page = 1}) {
    setState(() => _currentPage = page);
    ref
        .read(adminUsersProvider.notifier)
        .load(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          role: _roleFilter,
          status: _statusFilter,
          kycStatus: _kycFilter,
          page: page,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildSummaryRow(context),
          _buildFilterChips(context),
          const Divider(height: 1),
          Expanded(child: _buildUserList(context, state)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Icon(
            Icons.groups_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Manage Users',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _applyFilters(),
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
        title: const Text('Search Users'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name or email...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            setState(() => _searchQuery = value);
            _applyFilters();
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              _applyFilters();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _searchQuery = controller.text);
              _applyFilters();
              Navigator.pop(ctx);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context) {
    final state = ref.watch(adminUsersProvider);
    final total = state is AdminUsersSuccess ? state.data.total : 0;
    final palette = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _SummaryChip(label: 'Total', value: '$total', color: palette.primary),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Consumers', value: '-', color: Colors.blue),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Producers', value: '-', color: Colors.orange),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Active', value: '-', color: Colors.green),
          const SizedBox(width: 8),
          _SummaryChip(label: 'Suspended', value: '-', color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final roles = <String?>[null, 'consumer', 'producer', 'admin'];
    final statuses = <String?>[null, 'active', 'suspended'];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _FilterChip(
            label: 'All Roles',
            selected: _roleFilter == null,
            onSelected: () {
              setState(() => _roleFilter = null);
              _applyFilters();
            },
          ),
          for (final role in roles.skip(1)) ...[
            const SizedBox(width: 6),
            _FilterChip(
              label: role![0].toUpperCase() + role.substring(1),
              selected: _roleFilter == role,
              onSelected: () {
                setState(() => _roleFilter = role);
                _applyFilters();
              },
            ),
          ],
          const SizedBox(width: 12),
          _FilterChip(
            label: 'All Status',
            selected: _statusFilter == null,
            onSelected: () {
              setState(() => _statusFilter = null);
              _applyFilters();
            },
          ),
          for (final status in statuses.skip(1)) ...[
            const SizedBox(width: 6),
            _FilterChip(
              label: status![0].toUpperCase() + status.substring(1),
              selected: _statusFilter == status,
              onSelected: () {
                setState(() => _statusFilter = status);
                _applyFilters();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserList(BuildContext context, AdminUsersState state) {
    return switch (state) {
      AdminUsersLoading() => const Center(child: CircularProgressIndicator()),
      AdminUsersError(:final message) => _buildError(context, message),
      AdminUsersSuccess(:final data) => _buildUserItems(context, data),
    };
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _applyFilters(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItems(BuildContext context, PaginatedAdminUsers data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Try adjusting your search or filters.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _applyFilters(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: data.items.length + (data.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= data.items.length) {
            // Load more button
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => _applyFilters(page: _currentPage + 1),
                  child: const Text('Load More'),
                ),
              ),
            );
          }
          return _UserCard(
            user: data.items[index],
            onTap: () => _showUserDetail(context, data.items[index]),
          );
        },
      ),
    );
  }

  void _showUserDetail(BuildContext context, AdminUserSummary user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UserDetailSheet(
        user: user,
        onSuspend: () {
          Navigator.pop(ctx);
          _confirmAction(
            context,
            'Suspend User',
            'Are you sure you want to suspend ${user.fullName}?',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user.fullName} suspended')),
              );
            },
          );
        },
        onReactivate: () {
          Navigator.pop(ctx);
          _confirmAction(
            context,
            'Reactivate User',
            'Are you sure you want to reactivate ${user.fullName}?',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user.fullName} reactivated')),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(title),
          ),
        ],
      ),
    );
  }
}

// Helper widgets

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});
  final AdminUserSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                child: Text(
                  user.initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (user.email != null)
                      Text(
                        user.email!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          text: user.role,
                          color: user.role == 'admin'
                              ? Colors.purple
                              : user.role == 'producer'
                              ? Colors.orange
                              : Colors.blue,
                        ),
                        _Badge(
                          text: user.isActive ? 'Active' : 'Suspended',
                          color: user.isActive ? Colors.green : Colors.red,
                        ),
                        if (user.kycStatus != null)
                          _Badge(
                            text: user.kycStatus!,
                            color: user.kycStatus == 'verified'
                                ? Colors.green
                                : Colors.orange,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (user.city != null)
                Text(
                  user.city!,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  const _UserDetailSheet({
    required this.user,
    required this.onSuspend,
    required this.onReactivate,
  });
  final AdminUserSummary user;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.initials,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (user.email != null)
              Center(
                child: Text(
                  user.email!,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 16),
            if (user.city != null || user.district != null)
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: '${user.city ?? ''}, ${user.district ?? ''}',
                context: context,
              ),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Role: ${user.role}',
              context: context,
            ),
            _DetailRow(
              icon: Icons.check_circle_outlined,
              label: 'Status: ${user.isActive ? "Active" : "Suspended"}',
              context: context,
            ),
            _DetailRow(
              icon: Icons.verified_outlined,
              label: 'KYC: ${user.kycStatus ?? "Not submitted"}',
              context: context,
            ),
            _DetailRow(
              icon: Icons.email_outlined,
              label: 'Email verified: ${user.emailVerified ? "Yes" : "No"}',
              context: context,
            ),
            if (user.createdAt != null)
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Joined: ${_formatDate(user.createdAt!)}',
                context: context,
              ),
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.inventory_2_outlined,
              label: 'Listings: ${user.listingsCount}',
              context: context,
            ),
            _DetailRow(
              icon: Icons.shopping_bag_outlined,
              label: 'Purchases: ${user.purchasesCount}',
              context: context,
            ),
            _DetailRow(
              icon: Icons.forum_outlined,
              label: 'Disputes: ${user.disputesCount}',
              context: context,
            ),
            const SizedBox(height: 16),
            if (user.isActive)
              FilledButton.tonalIcon(
                onPressed: onSuspend,
                icon: const Icon(Icons.block_outlined),
                label: const Text('Suspend User'),
                style: FilledButton.styleFrom(foregroundColor: Colors.red),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onReactivate,
                icon: const Icon(Icons.check_circle_outlined),
                label: const Text('Reactivate User'),
                style: FilledButton.styleFrom(foregroundColor: Colors.green),
              ),
          ],
        ),
      ),
    );
  }

  Widget _DetailRow({
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
