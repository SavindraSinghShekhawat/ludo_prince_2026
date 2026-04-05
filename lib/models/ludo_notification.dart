enum NotificationType { friendRequest, gameInvite, system }

class LudoNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  bool isRead;

  LudoNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    required this.timestamp,
    this.isRead = false,
  });

  LudoNotification copyWith({
    bool? isRead,
  }) {
    return LudoNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      data: data,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
