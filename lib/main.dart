import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Request notification permission (Android 13+)
  await NotificationService().requestPermission();
  
  runApp(const UtilityApp());
  
  // Reschedule notifications in the background to avoid blocking startup
  NotificationService().rescheduleAllNotifications();
}
