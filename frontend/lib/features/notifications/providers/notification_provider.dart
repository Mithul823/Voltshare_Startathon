import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../realtime/providers/realtime_provider.dart';
import '../data/notification_repository.dart';
import '../domain/notification_item.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    apiClient: ref.watch(apiClientProvider),
    config: ref.watch(appConfigProvider),
  );
});

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) {
  ref.listen(webSocketProvider, (_, next) {
    final event = next.valueOrNull;
    if (event?.type == 'notification.created' ||
        event?.type == 'notification.read') {
      ref.invalidateSelf();
    }
  });
  return ref.watch(notificationRepositoryProvider).load();
});

final unreadNotificationsProvider = FutureProvider<int>((ref) {
  ref.listen(webSocketProvider, (_, next) {
    final event = next.valueOrNull;
    if (event?.type == 'notification.created' ||
        event?.type == 'notification.read') {
      ref.invalidateSelf();
    }
  });
  return ref.watch(notificationRepositoryProvider).unreadCount();
});
