import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'core/services/settings_service.dart';

@pragma('vm:entry-point')
Future<void> interactiveWidgetCallback(Uri? uri) async {
  if (uri?.host == 'timer') {
    final minsStr = uri?.queryParameters['mins'];
    if (minsStr != null) {
      final mins = int.parse(minsStr);
      
      // Save global target state for sidebar real-time visibility based on duration dynamically
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_timer_${mins}_start_ms', DateTime.now().millisecondsSinceEpoch);

      // Natively schedule the notification
      await NotificationService().initialize();
      await NotificationService().scheduleQuickTimer(mins);
      
      // Morph button to tick
      final btnId = "btn_${mins}m_tick";
      await HomeWidget.saveWidgetData<bool>(btnId, true);
      await HomeWidget.updateWidget(name: 'ScheduleWidgetProvider', androidName: 'ScheduleWidgetProvider');
      
      // Revert after 2 seconds safely
      await Future.delayed(const Duration(seconds: 2));
      await HomeWidget.saveWidgetData<bool>(btnId, false);
      await HomeWidget.updateWidget(name: 'ScheduleWidgetProvider', androidName: 'ScheduleWidgetProvider');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SettingsService.instance.init();
  
  // Register the background worker channel
  HomeWidget.registerBackgroundCallback(interactiveWidgetCallback);
  
  // Register active listener to catch widget interactions when the app is alive 
  // (otherwise the background isolate gets blocked and drops the event!)
  HomeWidget.widgetClicked.listen(interactiveWidgetCallback);
  
  // Lock app orientation to Portrait strictly
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
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
