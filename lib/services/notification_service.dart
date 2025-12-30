import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import '../db_helper.dart';

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
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
      } catch (e) {
        debugPrint('Error setting location: $e');
        // Fallback to local or UTC if needed
        tz.setLocalLocation(tz.local);
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      
      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - can navigate to specific event
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

  /// Schedule a notification for an event
  Future<void> scheduleEventNotification(Event event) async {
    try {
      if (!event.remindMe || event.remindTime == null) return;

      final eventDate = DateTime.parse(event.date);
      final reminderDate = eventDate.subtract(
        Duration(days: event.remindDaysBefore ?? 0),
      );

      // Parse the reminder time (format: "HH:mm AM/PM" or "HH:mm")
      final timeParts = _parseTimeString(event.remindTime!);
      if (timeParts == null) return;

      final scheduledDateTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        timeParts['hour']!,
        timeParts['minute']!,
      );

      // Don't schedule if the time has already passed
      if (scheduledDateTime.isBefore(DateTime.now())) {
        debugPrint('Skipping past notification for event ${event.id}');
        return;
      }

      final tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);
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
        importance: Importance.max, // Changed to Max for "pop in" effect
        priority: Priority.max,     // Changed to Max for "pop in" effect
        icon: '@mipmap/ic_launcher',
        styleInformation: bigTextStyleInformation,
        fullScreenIntent: true, // Attempt to be more intrusive/visible
        category: AndroidNotificationCategory.event,
        ticker: title,
        visibility: NotificationVisibility.public,
      );

      final details = NotificationDetails(android: androidDetails);

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
        matchDateTimeComponents: DateTimeComponents.dateAndTime, // Optional: verify if needed
      );

      debugPrint('Scheduled notification for event ${event.id} at $scheduledDateTime');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  String _getNotificationTitle(Event event) {
    switch (event.type) {
      case 'birthday':
        return '🎂 Birthday Reminder';
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
      final db = await DBHelper.database;
      final maps = await db.query('events', where: 'remindMe = ?', whereArgs: [1]);
      final events = maps.map((e) => Event.fromMap(e)).toList();

      // Cancel all existing notifications first
      await _notifications.cancelAll();

      // Reschedule each event
      for (final event in events) {
        await scheduleEventNotification(event);
      }

      debugPrint('Rescheduled ${events.length} notifications');
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }
}
