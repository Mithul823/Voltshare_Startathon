import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_item.dart';

class NotificationRepository {
  const NotificationRepository({
    required ApiClient apiClient,
    required AppConfig config,
  }) : _apiClient = apiClient,
       _config = config;

  final ApiClient _apiClient;
  final AppConfig _config;

  Future<List<NotificationItem>> load() async {
    if (_config.useMockBackend) {
      return _mockNotifications();
    }
    final data = await _apiClient.get('/notifications');
    return [
      for (final item in (data as List? ?? const []))
        NotificationItem.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  Future<int> unreadCount() async {
    if (_config.useMockBackend) {
      return 3;
    }
    final data = await _apiClient.get('/notifications/unread-count');
    return ((data as Map?)?['count'] as num?)?.toInt() ?? 0;
  }

  Future<NotificationItem> markRead(String id) async {
    if (_config.useMockBackend) {
      return NotificationItem(
        id: 'NOTIF-MOCK-0',
        title: 'Notification',
        message: 'Marked as read',
        category: NotificationCategory.system,
        priority: NotificationPriority.low,
        createdAt: DateTime.now(),
        read: true,
      );
    }
    final data = await _apiClient.patch('/notifications/$id/read');
    return NotificationItem.fromJson((data as Map).cast<String, Object?>());
  }

  List<NotificationItem> _mockNotifications() {
    return [
      NotificationItem(
        id: 'NOTIF-MOCK-1',
        title: 'Welcome to VoltShare',
        message: 'Your mock energy marketplace is ready. Explore the dashboard and listings.',
        category: NotificationCategory.system,
        priority: NotificationPriority.medium,
        createdAt: DateTime(2026, 7, 21, 10),
        read: false,
      ),
      NotificationItem(
        id: 'NOTIF-MOCK-2',
        title: 'Listing published',
        message: 'Your energy listing is now visible in the marketplace.',
        category: NotificationCategory.marketplace,
        priority: NotificationPriority.medium,
        createdAt: DateTime(2026, 7, 21, 9, 30),
        read: false,
      ),
      NotificationItem(
        id: 'NOTIF-MOCK-3',
        title: 'Deposit completed',
        message: 'Your wallet top-up of Rs 500.00 is available.',
        category: NotificationCategory.wallet,
        priority: NotificationPriority.medium,
        createdAt: DateTime(2026, 7, 21, 8),
        read: false,
      ),
      NotificationItem(
        id: 'NOTIF-MOCK-4',
        title: 'Mock mode active',
        message: 'Running with deterministic demo data. No real transactions will occur.',
        category: NotificationCategory.system,
        priority: NotificationPriority.low,
        createdAt: DateTime(2026, 7, 21, 7),
        read: true,
      ),
    ];
  }
}
