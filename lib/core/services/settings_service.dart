import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/weather_location.dart';
import 'home_widget_service.dart';
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
  int _widgetAwakeMinutes = 10;
  String _defaultScreen = 'schedule';

  String get sidebarName => _sidebarName;
  String get scheduleName => _scheduleName;
  String get secretPassword => _secretPassword;
  String get vaultExportPassword => _vaultExportPassword;
  int get widgetTimer1 => _widgetTimer1;
  int get widgetTimer2 => _widgetTimer2;
  int get widgetAwakeMinutes => _widgetAwakeMinutes;
  String get defaultScreen => _defaultScreen;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _sidebarName = _prefs.getString('sidebarName') ?? 'Avishek Shrestha';
    _scheduleName = _prefs.getString('scheduleName') ?? 'xArE0';
    _secretPassword = _prefs.getString('secretPassword') ?? '';
    _vaultExportPassword = _prefs.getString('vaultExportPassword') ?? 'super123';
    _widgetTimer1 = _prefs.getInt('widgetTimer1') ?? 5;
    _widgetTimer2 = _prefs.getInt('widgetTimer2') ?? 15;
    _widgetAwakeMinutes = _prefs.getInt('widgetAwakeMinutes') ?? 10;
    _defaultScreen = _prefs.getString('defaultScreen') ?? 'schedule';
    final raw = _prefs.getString('sidebarHiddenItems') ?? '';
    _sidebarHiddenItems = raw.isEmpty ? {} : raw.split(',').toSet();
    _loadLocations();

    // The widget keeps its own copy (it works while the app isn't running); this app's settings
    // are the source, so push them on every launch. Never throws.
    await _pushWidgetSettings();
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

  Future<void> updateWidgetSettings(int t1, int t2, int awakeMinutes) async {
    _widgetTimer1 = t1.clamp(1, 999);
    _widgetTimer2 = t2.clamp(1, 999);
    _widgetAwakeMinutes = awakeMinutes.clamp(1, 999);
    await _prefs.setInt('widgetTimer1', _widgetTimer1);
    await _prefs.setInt('widgetTimer2', _widgetTimer2);
    await _prefs.setInt('widgetAwakeMinutes', _widgetAwakeMinutes);
    await _pushWidgetSettings();
    notifyListeners();
  }

  Future<void> _pushWidgetSettings() => HomeWidgetService.instance.configure(
        timer1: _widgetTimer1,
        timer2: _widgetTimer2,
        awakeMinutes: _widgetAwakeMinutes,
      );

  Future<void> updateDefaultScreen(String value) async {
    _defaultScreen = value;
    await _prefs.setString('defaultScreen', value);
    notifyListeners();
  }

  // ── Sidebar visibility ───────────────────────────────────────────────────

  /// Keys of sidebar items the user has hidden. All items are visible by default.
  Set<String> _sidebarHiddenItems = {};

  Set<String> get sidebarHiddenItems => Set.unmodifiable(_sidebarHiddenItems);

  bool isSidebarItemVisible(String key) => !_sidebarHiddenItems.contains(key);

  Future<void> updateSidebarHiddenItems(Set<String> hidden) async {
    _sidebarHiddenItems = Set.from(hidden);
    await _prefs.setString('sidebarHiddenItems', hidden.join(','));
    notifyListeners();
  }

  // ── Weather location ─────────────────────────────────────────────────────

  WeatherLocation _location = WeatherLocation.kathmandu;
  List<WeatherLocation> _savedLocations = [WeatherLocation.kathmandu];

  /// The place weather, sunrise/sunset and air quality are shown for.
  WeatherLocation get location => _location;

  /// Places the user has picked before, for switching back quickly. Always includes [location].
  List<WeatherLocation> get savedLocations => List.unmodifiable(_savedLocations);

  void _loadLocations() {
    try {
      final saved = (json.decode(_prefs.getString('weatherLocations') ?? '[]') as List)
          .map(WeatherLocation.fromJson)
          .whereType<WeatherLocation>()
          .toList();
      final active = WeatherLocation.fromJson(json.decode(_prefs.getString('weatherLocation') ?? 'null'));
      if (active != null) _location = active;
      if (saved.isNotEmpty) _savedLocations = saved;
    } catch (_) {
      // Corrupt entry: keep the defaults.
    }
    if (!_savedLocations.any((l) => l.key == _location.key)) {
      _savedLocations = [_location, ..._savedLocations];
    }
  }

  Future<void> selectLocation(WeatherLocation value) async {
    _location = value;
    if (!_savedLocations.any((l) => l.key == value.key)) {
      _savedLocations = [..._savedLocations, value];
    }
    await _saveLocations();
    notifyListeners();
  }

  /// The active location can't be removed; pick another one first.
  Future<void> removeLocation(WeatherLocation value) async {
    if (value.key == _location.key) return;
    _savedLocations = _savedLocations.where((l) => l.key != value.key).toList();
    await _saveLocations();
    notifyListeners();
  }

  Future<void> _saveLocations() async {
    await _prefs.setString('weatherLocation', json.encode(_location.toJson()));
    await _prefs.setString(
        'weatherLocations', json.encode(_savedLocations.map((l) => l.toJson()).toList()));
  }
}
