  import 'package:flutter/material.dart';
  import 'app.dart';
  import 'services/notification_service.dart';

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService().initialize();
    runApp(const UtilityApp());
    // Reschedule notifications in the background to avoid blocking startup
    NotificationService().rescheduleAllNotifications();
  }
