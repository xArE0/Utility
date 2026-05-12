import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _prefs;

  String _sidebarName = 'Avishek Shrestha';
  String _scheduleName = 'xArE0';
  String _secretPassword = '';
  String _vaultExportPassword = 'super123';
  int _widgetTimer1 = 5;
  int _widgetTimer2 = 15;
  int _widgetTimer3 = 30;

  String get sidebarName => _sidebarName;
  String get scheduleName => _scheduleName;
  String get secretPassword => _secretPassword;
  String get vaultExportPassword => _vaultExportPassword;
  int get widgetTimer1 => _widgetTimer1;
  int get widgetTimer2 => _widgetTimer2;
  int get widgetTimer3 => _widgetTimer3;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _sidebarName = _prefs.getString('sidebarName') ?? 'Avishek Shrestha';
    _scheduleName = _prefs.getString('scheduleName') ?? 'xArE0';
    _secretPassword = _prefs.getString('secretPassword') ?? '';
    _vaultExportPassword = _prefs.getString('vaultExportPassword') ?? 'super123';
    _widgetTimer1 = _prefs.getInt('widgetTimer1') ?? 5;
    _widgetTimer2 = _prefs.getInt('widgetTimer2') ?? 15;
    _widgetTimer3 = _prefs.getInt('widgetTimer3') ?? 30;
  }

  Future<void> updateSidebarName(String value) async {
    _sidebarName = value;
    await _prefs.setString('sidebarName', value);
    notifyListeners();
  }

  Future<void> updateScheduleName(String value) async {
    _scheduleName = value;
    await _prefs.setString('scheduleName', value);
    notifyListeners();
  }

  Future<void> updateSecretPassword(String value) async {
    _secretPassword = value;
    await _prefs.setString('secretPassword', value);
    notifyListeners();
  }

  Future<void> updateVaultExportPassword(String value) async {
    _vaultExportPassword = value.isEmpty ? 'super123' : value;
    await _prefs.setString('vaultExportPassword', _vaultExportPassword);
    notifyListeners();
  }

  Future<void> updateWidgetTimers(int t1, int t2, int t3) async {
    _widgetTimer1 = t1.clamp(1, 999);
    _widgetTimer2 = t2.clamp(1, 999);
    _widgetTimer3 = t3.clamp(1, 999);
    await _prefs.setInt('widgetTimer1', _widgetTimer1);
    await _prefs.setInt('widgetTimer2', _widgetTimer2);
    await _prefs.setInt('widgetTimer3', _widgetTimer3);

    // Push values to the widget's SharedPreferences so Kotlin can read them
    await HomeWidget.saveWidgetData<int>('widget_timer1', _widgetTimer1);
    await HomeWidget.saveWidgetData<int>('widget_timer2', _widgetTimer2);
    await HomeWidget.saveWidgetData<int>('widget_timer3', _widgetTimer3);

    // Also update the button labels on the widget
    await HomeWidget.saveWidgetData<String>('widget_timer1_label', '${_widgetTimer1}m');
    await HomeWidget.saveWidgetData<String>('widget_timer2_label', '${_widgetTimer2}m');
    await HomeWidget.saveWidgetData<String>('widget_timer3_label', '${_widgetTimer3}m');

    // Trigger widget refresh
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      androidName: 'ScheduleWidgetProvider',
    );
    notifyListeners();
  }
}
