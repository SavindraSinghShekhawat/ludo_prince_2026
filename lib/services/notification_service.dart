import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:ludo_prince/services/notification_router.dart';
import 'package:ludo_prince/utils/app_logger.dart';

/// Central notification service managing local scheduled game reminders for Ludo Prince.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String channelId = 'ludo_prince_game_reminders';
  static const String channelName = 'Game Reminders';
  static const String channelDescription =
      'Daily prime-time, weekend battles, and smart re-engagement reminders to play Ludo Prince.';

  /// Channel accent color (Cyan) matching AppColors.primaryCyan.
  static const Color notificationColor = Color(0xFF00E5FF);

  /// Initializes timezone data and native local notification handlers.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      AppLogger.error('NotificationService: Failed to configure timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        AppLogger.debug(
          'Notification tapped with payload: ${response.payload}',
        );
        NotificationRouter.handleNotificationPayload(response.payload);
      },
    );

    // Check if the app was launched by tapping a notification from terminated state
    try {
      final launchDetails = await _flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        AppLogger.debug(
          'NotificationService: Cold launch detected with payload: ${launchDetails.notificationResponse!.payload}',
        );
        NotificationRouter.setPendingPayload(
          launchDetails.notificationResponse!.payload,
        );
      }
    } catch (e) {
      AppLogger.error('NotificationService: Failed to retrieve launch details: $e');
    }

    _isInitialized = true;
    AppLogger.debug('NotificationService: Initialized successfully');
  }

  /// Requests notification permissions on iOS and Android 13+.
  Future<bool> requestPermissions() async {
    bool granted = false;

    if (Platform.isIOS) {
      final iosPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final result = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = result ?? false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final result = await androidPlugin?.requestNotificationsPermission();
      granted = result ?? false;
    }

    return granted;
  }

  /// Checks if notifications are currently enabled.
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? true;
    }
    return true;
  }

  /// Schedules a recurring daily reminder at [hour]:[minute].
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: notificationColor,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      AppLogger.debug(
        'NotificationService: Scheduled daily reminder ($id) for $scheduledDate',
      );
    } catch (e) {
      AppLogger.error('NotificationService: Failed to schedule daily reminder: $e');
    }
  }

  /// Schedules a weekly recurring reminder on a specific [dayOfWeek] (1 = Mon, 6 = Sat, 7 = Sun).
  Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Calculate days until next target weekday
    int daysDiff = (dayOfWeek - scheduledDate.weekday) % 7;
    if (daysDiff < 0) daysDiff += 7;
    if (daysDiff == 0 && scheduledDate.isBefore(now)) {
      daysDiff = 7;
    }

    scheduledDate = scheduledDate.add(Duration(days: daysDiff));

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: notificationColor,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
      AppLogger.debug(
        'NotificationService: Scheduled weekly reminder ($id) for $scheduledDate',
      );
    } catch (e) {
      AppLogger.error('NotificationService: Failed to schedule weekly reminder: $e');
    }
  }

  /// Schedules a one-time reminder at a specific [scheduledTime] (e.g. for inactivity re-engagement).
  Future<void> scheduleOneTimeReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: notificationColor,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      AppLogger.debug(
        'NotificationService: Scheduled one-time reminder ($id) for $tzTime',
      );
    } catch (e) {
      AppLogger.error('NotificationService: Failed to schedule one-time reminder: $e');
    }
  }

  /// Displays an immediate notification (e.g. "Test Reminder" triggered from Settings).
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: notificationColor,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      AppLogger.error('NotificationService: Failed to show immediate notification: $e');
    }
  }

  /// Cancels a specific scheduled reminder by [id].
  Future<void> cancelReminder(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }

  /// Cancels all scheduled reminders.
  Future<void> cancelAllReminders() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Returns list of all currently pending notifications.
  Future<List<int>> getPendingNotificationIds() async {
    final pending =
        await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return pending.map((e) => e.id).toList();
  }
}

final notificationService = NotificationService();
