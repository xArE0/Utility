import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import '../core/services/system_service.dart';
import '../features/schedule/data/local_schedule_repository.dart';
import '../features/schedule/domain/schedule_entities.dart';

/// Top-level background handler — MUST be a top-level function (not a class
/// method) so the Android OS can invoke it even when the app process is dead.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  // This runs in its own isolate when the app is killed.
  // Heavy work (navigation, etc.) should NOT go here.
  debugPrint('Background notification tapped: ${response.payload}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      // The phone's zone: repeating reminders keep their wall-clock time across DST and travel.
      final zone = await SystemService.timezone();
      try {
        tz.setLocalLocation(tz.getLocation(zone ?? 'Asia/Kathmandu'));
      } catch (e) {
        debugPrint('Unknown timezone $zone: $e');
        tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        // ✅ Register the top-level background handler so notifications work
        //    even when the app is completely killed.
        onDidReceiveBackgroundNotificationResponse:
            onBackgroundNotificationResponse,
      );
      
      // Create notification channel immediately to ensure it exists
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            'event_reminders',
            'Event Reminders',
            description: 'Notifications for scheduled events',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        debugPrint('Notification channel created');
      }
      
      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Request exact alarm permission (Android 12+), only when it is actually missing (USE_EXACT_ALARM
  /// normally grants it). Exact alarms fire on time without exempting the app from battery
  /// optimisation, so no such exemption is requested.
  Future<bool> requestExactAlarmPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    if (await android.canScheduleExactNotifications() ?? true) return true;

    final granted = await android.requestExactAlarmsPermission();
    debugPrint('Exact alarm permission granted: $granted');
    return granted ?? false;
  }

  /// Schedule a notification for an event
  Future<void> scheduleEventNotification(Event event) async {
    try {
      if (!event.remindMe || event.remindTime == null) return;

      // Parse the reminder time (format: "HH:mm AM/PM" or "HH:mm")
      final timeParts = _parseTimeString(event.remindTime!);
      if (timeParts == null) {
        debugPrint('Failed to parse time: ${event.remindTime}');
        return;
      }

      final scheduledDateTime = _nextReminder(
          event, timeParts['hour']!, timeParts['minute']!, event.remindDaysBefore ?? 0);
      if (scheduledDateTime == null) {
        debugPrint('No upcoming reminder for event ${event.id}');
        return;
      }

      final tzScheduledDate = tz.TZDateTime(tz.local, scheduledDateTime.year,
          scheduledDateTime.month, scheduledDateTime.day, scheduledDateTime.hour,
          scheduledDateTime.minute);
      final title = _getNotificationTitle(event);
      final body = event.task;

      // Create a BigTextStyle information for better UI
      final BigTextStyleInformation bigTextStyleInformation =
          BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        summaryText: 'Event Reminder',
        htmlFormatSummaryText: true,
      );

      final androidDetails = AndroidNotificationDetails(
        'event_reminders',
        'Event Reminders',
        channelDescription: 'Notifications for scheduled events',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.reminder,
        ticker: title,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
      );

      final details = NotificationDetails(android: androidDetails);
      
      // Use exactAllowWhileIdle for reliable on-time delivery.
      // The app requests SCHEDULE_EXACT_ALARM permission at startup; if the
      // user hasn't granted it the plugin falls back to inexact automatically.
      await _notifications.zonedSchedule(
        event.id ?? event.hashCode,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: event.id?.toString(),
        // Re-armed natively after each firing where the pattern allows; monthly and custom
        // intervals get their next occurrence when the app next starts.
        matchDateTimeComponents: _repeatPattern(event),
      );

      debugPrint('✓ Scheduled notification for event ${event.id}:');
      debugPrint('  Title: $title');
      debugPrint('  Time: $scheduledDateTime');
      debugPrint('  TZ Time: $tzScheduledDate');
    } catch (e, stackTrace) {
      debugPrint('Error scheduling notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// The first reminder still ahead: the event's next occurrence (today onwards), moved
  /// [daysBefore] days earlier, at [hour]:[minute]. Null when there is none within 3 years.
  DateTime? _nextReminder(Event event, int hour, int minute, int daysBefore) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(DateTime day) =>
        DateTime(day.year, day.month, day.day - daysBefore, hour, minute);

    if (!event.isRecurring) {
      final reminder = at(DateTime.parse(event.date));
      return reminder.isAfter(now) ? reminder : null;
    }
    for (int i = 0; i <= 3 * 366; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (!event.occursOn(day)) continue;
      final reminder = at(day);
      if (reminder.isAfter(now)) return reminder;
    }
    return null;
  }

  /// The match the plugin repeats on, or null for one-shot (one-off, monthly, custom).
  /// Monthly isn't matched natively: with "days before", the reminder day shifts month to month.
  DateTimeComponents? _repeatPattern(Event event) {
    if (event.type == 'birthday') return DateTimeComponents.dateAndTime;
    return switch (event.repeat) {
      'daily' => DateTimeComponents.time,
      'weekly' => DateTimeComponents.dayOfWeekAndTime,
      'yearly' => DateTimeComponents.dateAndTime,
      _ => null,
    };
  }

  String _getNotificationTitle(Event event) {
    switch (event.type) {
      case 'birthday':
        return '🎂 Birthday Reminder';
      case 'reminder':
        return '🔔 Reminder';
      case 'exam':
        return '📚 Exam Reminder';
      case 'homework':
        return '📝 Homework Due';
      case 'event':
        return '📅 Event Reminder';
      default:
        return '⏰ Reminder';
    }
  }

  Map<String, int>? _parseTimeString(String timeStr) {
    try {
      // Handle formats like "10:30 AM", "14:30", "2:30 PM"
      final cleanTime = timeStr.trim().toUpperCase();
      final isPM = cleanTime.contains('PM');
      final isAM = cleanTime.contains('AM');
      
      final timePart = cleanTime
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .trim();
      
      final parts = timePart.split(':');
      if (parts.length != 2) return null;

      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Convert to 24-hour format
      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      return {'hour': hour, 'minute': minute};
    } catch (e) {
      debugPrint('Error parsing time: $timeStr - $e');
      return null;
    }
  }

  /// Cancel a scheduled notification for an event
  Future<void> cancelEventNotification(int eventId) async {
    await _notifications.cancel(eventId);
    debugPrint('Cancelled notification for event $eventId');
  }

  /// Reschedule all event notifications (call on app startup or after boot)
  Future<void> rescheduleAllNotifications() async {
    try {
      debugPrint('Rescheduling all notifications...');
      final repository = LocalScheduleRepository();
      await repository.init();
      final allEvents = await repository.getAllEvents();
      final events = allEvents.where((e) => e.remindMe == true).toList();

      // Cancel existing event notifications first, but preserve widget quick-timers (IDs > 100000)
      final pending = await _notifications.pendingNotificationRequests();
      for (final req in pending) {
        if (req.id < 100000) {
          await _notifications.cancel(req.id);
        }
      }

      // Reschedule each event
      for (final event in events) {
        await scheduleEventNotification(event);
      }

      debugPrint('Rescheduled ${events.length} notifications');
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  /// Show a test notification immediately (for debugging)
  Future<void> showTestNotification() async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'event_reminders',
        'Event Reminders',
        channelDescription: 'Notifications for scheduled events',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      final details = NotificationDetails(android: androidDetails);

      await _notifications.show(
        999,
        '🔔 Test Notification',
        'If you see this, notifications are working!',
        details,
      );
      debugPrint('Test notification shown');
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  /// Get pending notifications count for debugging
  Future<int> getPendingNotificationsCount() async {
    final pending = await _notifications.pendingNotificationRequests();
    debugPrint('Pending notifications: ${pending.length}');
    for (final notification in pending) {
      debugPrint('  - ID: ${notification.id}, Title: ${notification.title}');
    }
    return pending.length;
  }

  /// Schedule a one-shot habit reminder for today at the given time.
  /// ID space: 200000 + habitId to avoid collisions.
  Future<void> scheduleHabitReminder(int habitId, String habitName, String emoji, int hour, int minute) async {
    try {
      final now = DateTime.now();
      var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

      // If the time has already passed today, don't schedule
      if (scheduledTime.isBefore(now)) {
        debugPrint('Habit reminder time already passed for today');
        return;
      }

      final tzScheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
      final notifId = 200000 + habitId;

      final androidDetails = const AndroidNotificationDetails(
        'habit_reminders',
        'Habit Reminders',
        channelDescription: 'Daily habit reminder notifications',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      final details = NotificationDetails(android: androidDetails);

      await _notifications.zonedSchedule(
        notifId,
        '$emoji $habitName',
        'Time to do your habit!',
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✓ Habit reminder set for $habitName at $hour:$minute');
    } catch (e) {
      debugPrint('Error scheduling habit reminder: $e');
    }
  }

  /// Cancel a habit reminder notification
  Future<void> cancelHabitReminder(int habitId) async {
    final notifId = 200000 + habitId;
    await _notifications.cancel(notifId);
    debugPrint('Cancelled habit reminder for habit $habitId');
  }
}
