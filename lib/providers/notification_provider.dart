import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/models/app_notification.dart';

class NotificationState {
  final List<AppNotification> inbox;
  final AppNotification? activeToast;

  NotificationState({this.inbox = const [], this.activeToast});

  NotificationState copyWith({
    List<AppNotification>? inbox,
    AppNotification? activeToast,
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
  Set<String> _viewedNotificationIds = {};

  @override
  NotificationState build() {
    ref.onDispose(() => _dismissTimer?.cancel());
    _loadViewedIds();
    return NotificationState();
  }

  Future<void> _loadViewedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('viewed_notifications') ?? [];
      _viewedNotificationIds = list.toSet();
      if (_viewedNotificationIds.isNotEmpty && state.inbox.isNotEmpty) {
        final updated = state.inbox.map((n) {
          if (_viewedNotificationIds.contains(n.id)) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList();
        state = state.copyWith(inbox: updated);
      }
    } catch (_) {}
  }

  Future<void> _saveViewedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only up to latest 200 IDs to avoid unbounded growth
      final toSave = _viewedNotificationIds.toList();
      if (toSave.length > 200) {
        toSave.removeRange(0, toSave.length - 200);
      }
      await prefs.setStringList('viewed_notifications', toSave);
    } catch (_) {}
  }

  void addNotification(AppNotification notification, {bool showToast = true}) {
    // Check if notification with same ID already exists
    if (state.inbox.any((n) => n.id == notification.id)) return;

    final isAlreadyViewed = _viewedNotificationIds.contains(notification.id);
    final effectiveNotification = isAlreadyViewed
        ? notification.copyWith(isRead: true)
        : notification;

    final newInbox = [effectiveNotification, ...state.inbox];

    final shouldShowToast = showToast && !isAlreadyViewed;
    state = state.copyWith(
      inbox: newInbox,
      activeToast: shouldShowToast ? effectiveNotification : null,
    );

    if (shouldShowToast) {
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 5), () {
        state = state.copyWith(clearActiveToast: true);
      });
    }
  }

  /// Marks all current inbox notifications as viewed (e.g. when user opens the notifications dialog)
  void markInboxAsViewed() {
    if (state.inbox.isEmpty) return;
    bool hasUnread = false;
    for (final n in state.inbox) {
      if (!n.isRead) {
        hasUnread = true;
        _viewedNotificationIds.add(n.id);
      }
    }
    if (hasUnread) {
      final updated =
          state.inbox.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(inbox: updated);
      _saveViewedIds();
    }
  }

  void markAsRead(String id) {
    _viewedNotificationIds.add(id);
    _saveViewedIds();
    final newInbox = state.inbox.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    state = state.copyWith(inbox: newInbox);
  }

  void markAllAsRead() {
    for (final n in state.inbox) {
      _viewedNotificationIds.add(n.id);
    }
    _saveViewedIds();
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
