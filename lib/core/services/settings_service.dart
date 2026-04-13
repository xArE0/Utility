import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _prefs;

  String _sidebarName = 'Avishek Shrestha';
  String _scheduleName = 'xArE0';
  String _secretPassword = '';

  String get sidebarName => _sidebarName;
  String get scheduleName => _scheduleName;
  String get secretPassword => _secretPassword;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _sidebarName = _prefs.getString('sidebarName') ?? 'Avishek Shrestha';
    _scheduleName = _prefs.getString('scheduleName') ?? 'xArE0';
    _secretPassword = _prefs.getString('secretPassword') ?? '';
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
}
