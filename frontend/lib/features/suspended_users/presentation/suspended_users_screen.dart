import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/voltshare_ui.dart';
import '../data/suspended_users_repository.dart';

final suspendedUsersProvider =
    StateNotifierProvider<SuspendedUsersNotifier, AsyncValue<PaginatedSuspendedUsers>>((ref) {
  return SuspendedUsersNotifier(ref);
});

class SuspendedUsersNotifier extends StateNotifier<AsyncValue<PaginatedSuspendedUsers>> {
  SuspendedUsersNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  String? _search;
  int _page = 1;

  void load({String? search, int page = 1}) {
    _search = search;
    _page = page;
    _fetch();
  }

  Future<void> _fetch() async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(suspendedUsersRepositoryProvider);
      final result = await repo.listSuspended(search: _search, page: _page);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restore(String userId) async {
    try {
      await _ref.read(suspendedUsersRepositoryProvider).restoreUser(userId);
      _fetch();
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteEntry(String userId) async {
    try {
      await _ref.read(suspendedUsersRepositoryProvider).deleteSuspension(userId);
      _fetch();
    } catch (e) {
      // ignore
    }
  }
}

class SuspendedUsersScreen extends ConsumerWidget {
  const SuspendedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(suspendedUsersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Suspended Users',
              showBackButton: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () => _showSearch(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.read(suspendedUsersProvider.notifier).load(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Suspended users are removed from marketplace, search, and listings.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 20),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (page) {
                  if (page.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block_outlined, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          const Text('No suspended users', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Suspended users will appear here.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.read(suspendedUsersProvider.notifier).load(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: page.items.length + (page.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index >= page.items.length) {
                          return Center(
                            child: OutlinedButton(
                              onPressed: () {
                                final notifier = ref.read(suspendedUsersProvider.notifier);
                                notifier.load(page: page.page + 1);
                              },
                              child: const Text('Load More'),
                            ),
                          );
                        }
                        return _SuspendedUserCard(
                          record: page.items[index],
                          onRestore: () => _confirmRestore(context, ref, page.items[index]),
                          onDelete: () => _confirmDelete(context, ref, page.items[index]),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Suspended Users'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name or email...', prefixIcon: Icon(Icons.search)),
          onSubmitted: (v) {
            ref.read(suspendedUsersProvider.notifier).load(search: v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () { ref.read(suspendedUsersProvider.notifier).load(); Navigator.pop(ctx); }, child: const Text('Clear')),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context, WidgetRef ref, SuspendedUserRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore User'),
        content: Text('Are you sure you want to restore ${record.fullName}? They will regain full access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(suspendedUsersProvider.notifier).restore(record.userId);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${record.fullName} restored')));
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SuspendedUserRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text('Are you sure you want to permanently delete the suspension record for ${record.fullName}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(suspendedUsersProvider.notifier).deleteEntry(record.userId);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suspension deleted for ${record.fullName}')));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SuspendedUserCard extends StatelessWidget {
  final SuspendedUserRecord record;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  const _SuspendedUserCard({required this.record, required this.onRestore, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.red.withOpacity(0.1),
              child: Text(record.initials, style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red.shade700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (record.email != null) Text(record.email!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      _Badge(text: record.role, color: Colors.blue),
                      _Badge(text: 'Suspended', color: Colors.red),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Reason: ${record.suspensionReason}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                  Text('Suspended: ${_formatDate(record.suspendedAt)}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.restore_from_trash_outlined, size: 20),
                  tooltip: 'Restore',
                  color: Colors.green,
                  onPressed: onRestore,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever_outlined, size: 20),
                  tooltip: 'Delete permanently',
                  color: Colors.red,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
