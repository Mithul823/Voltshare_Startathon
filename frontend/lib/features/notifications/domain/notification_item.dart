enum NotificationCategory {
  wallet,
  marketplace,
  purchase,
  sale,
  settlement,
  grid,
  security,
  system;

  static NotificationCategory parse(String value) {
    return values.firstWhere(
      (item) => item.name.toLowerCase() == value.toLowerCase(),
      orElse: () => NotificationCategory.system,
    );
  }
}

enum NotificationPriority {
  low,
  medium,
  high,
  critical;

  static NotificationPriority parse(String value) {
    return values.firstWhere(
      (item) => item.name.toLowerCase() == value.toLowerCase(),
      orElse: () => NotificationPriority.medium,
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.read,
    this.actionUrl,
    this.acknowledged = false,
  });

  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final NotificationPriority priority;
  final DateTime createdAt;
  final bool read;
  final String? actionUrl;
  final bool acknowledged;

  bool get pinned => priority == NotificationPriority.critical && !acknowledged;

  factory NotificationItem.fromJson(Map<String, Object?> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      category: NotificationCategory.parse(json['category']?.toString() ?? ''),
      priority: NotificationPriority.parse(json['priority']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      read: json['read'] == true,
      actionUrl: json['actionUrl']?.toString(),
      acknowledged: json['acknowledged'] == true,
    );
  }
}
