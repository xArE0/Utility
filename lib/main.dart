import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service (includes background handler registration)
  await NotificationService().initialize();
  
  // Request notification permission (Android 13+)
  final notifGranted = await NotificationService().requestPermission();
  if (!notifGranted) {
    debugPrint('⚠️ Notification permission denied — reminders will not work');
  }

  // Request exact alarm permission (Android 12+) for on-time delivery
  await NotificationService().requestExactAlarmPermission();

  // Request battery optimization exemption so the OS doesn't kill scheduled alarms
  await NotificationService().requestBatteryOptimizationExemption();
  
  runApp(const UtilityApp());
  
  // Reschedule notifications in the background to avoid blocking startup
  NotificationService().rescheduleAllNotifications();
}
