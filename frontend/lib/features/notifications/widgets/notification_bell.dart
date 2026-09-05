import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../providers/notification_provider.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push(AppRoutes.notifications),
          icon: const Icon(Icons.notifications_none_outlined),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onError,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
