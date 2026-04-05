import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ludo_notification.dart';

class NotificationState {
  final List<LudoNotification> inbox;
  final LudoNotification? activeToast;

  NotificationState({
    this.inbox = const [],
    this.activeToast,
  });

  NotificationState copyWith({
    List<LudoNotification>? inbox,
    LudoNotification? activeToast,
    bool clearActiveToast = false,
  }) {
    return NotificationState(
      inbox: inbox ?? this.inbox,
      activeToast: clearActiveToast ? null : (activeToast ?? this.activeToast),
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  Timer? _dismissTimer;

  @override
  NotificationState build() {
    ref.onDispose(() => _dismissTimer?.cancel());
    return NotificationState();
  }

  void addNotification(LudoNotification notification, {bool showToast = true}) {
    // Check if notification with same ID already exists
    if (state.inbox.any((n) => n.id == notification.id)) return;

    final newInbox = [notification, ...state.inbox];

    state = state.copyWith(
      inbox: newInbox,
      activeToast: showToast ? notification : null,
    );

    if (showToast) {
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 5), () {
        state = state.copyWith(clearActiveToast: true);
      });
    }
  }

  void markAsRead(String id) {
    final newInbox = state.inbox.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    state = state.copyWith(inbox: newInbox);
  }

  void markAllAsRead() {
    final newInbox = state.inbox.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(inbox: newInbox);
  }

  void dismissToast() {
    _dismissTimer?.cancel();
    state = state.copyWith(clearActiveToast: true);
  }

  void clearAll() {
    state = NotificationState();
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});
