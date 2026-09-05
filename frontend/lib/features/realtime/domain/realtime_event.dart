class RealtimeEvent {
  const RealtimeEvent({
    required this.id,
    required this.type,
    required this.channels,
    required this.createdAt,
    this.userId,
    this.actorUserId,
    this.payload = const {},
  });

  final String id;
  final String type;
  final List<String> channels;
  final DateTime createdAt;
  final String? userId;
  final String? actorUserId;
  final Map<String, Object?> payload;

  factory RealtimeEvent.fromJson(Map<String, Object?> json) {
    return RealtimeEvent(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      channels: [
        for (final channel in (json['channels'] as List? ?? const []))
          channel.toString(),
      ],
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      userId: json['userId']?.toString(),
      actorUserId: json['actorUserId']?.toString(),
      payload: (json['payload'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }
}
