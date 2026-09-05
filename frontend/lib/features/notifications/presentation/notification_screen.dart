import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../domain/notification_item.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Notifications',
                fallbackRoute: AppRoutes.dashboard,
              ),
              const SizedBox(height: 16),
              notifications.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _EmptyState(
                  title: 'Notifications unavailable',
                  message: 'VoltShare could not load notifications right now.',
                  action: 'Retry',
                  onPressed: () => ref.invalidate(notificationsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyState(
                      title: 'No notifications',
                      message:
                          'Realtime wallet, marketplace, and grid updates will appear here.',
                      action: 'Refresh',
                      onPressed: () => ref.invalidate(notificationsProvider),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items) _NotificationTile(item: item),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCritical = item.priority == NotificationPriority.critical;
    return Card(
      child: ListTile(
        leading: Icon(
          _iconFor(item.category),
          color: isCritical ? colorScheme.error : colorScheme.primary,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: Text(item.message),
        trailing: item.pinned
            ? const Icon(Icons.push_pin_outlined)
            : item.read
            ? const Icon(Icons.done)
            : TextButton(
                onPressed: () async {
                  await ref
                      .read(notificationRepositoryProvider)
                      .markRead(item.id);
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadNotificationsProvider);
                },
                child: const Text('Read'),
              ),
        onTap: item.actionUrl == null
            ? null
            : () => context.push(item.actionUrl!),
      ),
    );
  }

  IconData _iconFor(NotificationCategory category) {
    return switch (category) {
      NotificationCategory.wallet => Icons.account_balance_wallet_outlined,
      NotificationCategory.marketplace => Icons.storefront_outlined,
      NotificationCategory.purchase => Icons.shopping_bag_outlined,
      NotificationCategory.sale => Icons.receipt_long_outlined,
      NotificationCategory.settlement => Icons.verified_outlined,
      NotificationCategory.grid => Icons.electrical_services_outlined,
      NotificationCategory.security => Icons.security_outlined,
      NotificationCategory.system => Icons.info_outline,
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
