import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/notifications/domain/notification_item.dart';
import 'package:frontend/features/realtime/data/reconnect_manager.dart';
import 'package:frontend/features/realtime/domain/realtime_event.dart';

void main() {
  group('Phase 6.5 realtime', () {
    test('reconnect manager uses exponential backoff and queues actions', () {
      final manager = ReconnectManager(
        baseDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 4),
      );

      expect(manager.nextDelay(), const Duration(seconds: 1));
      expect(manager.nextDelay(), const Duration(seconds: 2));
      expect(manager.nextDelay(), const Duration(seconds: 4));
      expect(manager.nextDelay(), const Duration(seconds: 4));

      manager.queue({'type': 'ping'});
      expect(manager.drainQueue(), hasLength(1));
      expect(manager.drainQueue(), isEmpty);
      manager.reset();
      expect(manager.nextDelay(), const Duration(seconds: 1));
    });

    test('realtime event parses websocket event payload', () {
      final event = RealtimeEvent.fromJson({
        'id': 'EVT-1',
        'type': 'wallet.updated',
        'channels': ['wallet'],
        'createdAt': '2026-07-19T10:00:00Z',
        'payload': {'balance': 1200},
      });

      expect(event.id, 'EVT-1');
      expect(event.type, 'wallet.updated');
      expect(event.channels, ['wallet']);
      expect(event.payload['balance'], 1200);
    });

    test('critical notifications remain pinned until acknowledged', () {
      final notification = NotificationItem.fromJson({
        'id': 'NTF-1',
        'title': 'Grid alert',
        'message': 'Demand spike detected.',
        'category': 'Grid',
        'priority': 'CRITICAL',
        'createdAt': '2026-07-19T10:00:00Z',
        'read': false,
        'acknowledged': false,
      });

      expect(notification.category, NotificationCategory.grid);
      expect(notification.priority, NotificationPriority.critical);
      expect(notification.pinned, isTrue);
    });
  });
}
