import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/weather_location.dart';
import 'vault_crypto_service.dart';
import 'home_widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _prefs;

  String _sidebarName = 'Avishek Shrestha';
  String _scheduleName = 'xArE0';
  String _secretPasswordHash = '';
  String _vaultExportPassword = '';
  int _widgetTimer1 = 5;
  int _widgetTimer2 = 15;
  int _widgetAwakeMinutes = 10;
  String _defaultScreen = 'schedule';

  String get sidebarName => _sidebarName;
  String get scheduleName => _scheduleName;
  /// Whether the secret menu has a password yet (first use sets it).
  bool get hasSecretPassword => _secretPasswordHash.isNotEmpty;

  /// Password the vault is encrypted with on export; empty until the user sets one.
  String get vaultExportPassword => _vaultExportPassword;
  int get widgetTimer1 => _widgetTimer1;
  int get widgetTimer2 => _widgetTimer2;
  int get widgetAwakeMinutes => _widgetAwakeMinutes;
  String get defaultScreen => _defaultScreen;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _sidebarName = _prefs.getString('sidebarName') ?? 'Avishek Shrestha';
    _scheduleName = _prefs.getString('scheduleName') ?? 'xArE0';
    await _loadSecrets();
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

  // ── Secrets (Android Keystore via flutter_secure_storage, never SharedPreferences) ─────────

  static const _secure = FlutterSecureStorage();
  static const _secretHashKey = 'secret_password_hash';
  static const _exportPasswordKey = 'vault_export_password';

  /// The old default export password; treated as "not set".
  static const _legacyDefaultExportPassword = 'super123';

  Future<void> _loadSecrets() async {
    try {
      _secretPasswordHash = await _secure.read(key: _secretHashKey) ?? '';
      _vaultExportPassword = await _secure.read(key: _exportPasswordKey) ?? '';

      // One-time move out of plain-text SharedPreferences.
      final legacySecret = _prefs.getString('secretPassword') ?? '';
      if (legacySecret.isNotEmpty && _secretPasswordHash.isEmpty) {
        await _storeSecretPassword(legacySecret);
      }
      final legacyExport = _prefs.getString('vaultExportPassword') ?? '';
      if (legacyExport.isNotEmpty &&
          legacyExport != _legacyDefaultExportPassword &&
          _vaultExportPassword.isEmpty) {
        await updateVaultExportPassword(legacyExport);
      }
      await _prefs.remove('secretPassword');
      await _prefs.remove('vaultExportPassword');
    } catch (e) {
      debugPrint('Loading secrets failed: $e');
    }
  }

  Future<void> _storeSecretPassword(String value) async {
    _secretPasswordHash = await VaultCryptoService.instance.hashPassword(value);
    await _secure.write(key: _secretHashKey, value: _secretPasswordHash);
  }

  /// Sets a new secret menu password. Empty keeps the current one.
  Future<void> updateSecretPassword(String value) async {
    if (value.isEmpty) return;
    await _storeSecretPassword(value);
    notifyListeners();
  }

  /// Wrong secret-password attempts in a row; from the 5th on, each one locks entry for longer.
  static const _failedAttemptsKey = 'secretFailedAttempts';
  static const _lockedUntilKey = 'secretLockedUntil';

  /// How long entry is still locked after too many wrong passwords; null when not locked.
  Duration? get secretLockRemaining {
    final until = _prefs.getInt(_lockedUntilKey) ?? 0;
    final left = DateTime.fromMillisecondsSinceEpoch(until).difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  /// Checks [input] against the secret menu password. Returns false while locked out.
  Future<bool> verifySecretPassword(String input) async {
    if (secretLockRemaining != null) return false;
    final ok = input.isNotEmpty &&
        await VaultCryptoService.instance.verifyPassword(input, _secretPasswordHash);
    if (ok) {
      await _prefs.remove(_failedAttemptsKey);
      await _prefs.remove(_lockedUntilKey);
      return true;
    }
    final failures = (_prefs.getInt(_failedAttemptsKey) ?? 0) + 1;
    await _prefs.setInt(_failedAttemptsKey, failures);
    if (failures >= 5) {
      // 30 s, 1 min, 2 min, … capped at 30 min.
      final seconds = (30 * (1 << (failures - 5).clamp(0, 6))).clamp(30, 1800);
      await _prefs.setInt(_lockedUntilKey,
          DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch);
    }
    return false;
  }

  /// Sets the vault export password. Empty clears it (export then asks for one).
  Future<void> updateVaultExportPassword(String value) async {
    _vaultExportPassword = value;
    if (value.isEmpty) {
      await _secure.delete(key: _exportPasswordKey);
    } else {
      await _secure.write(key: _exportPasswordKey, value: value);
    }
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
    if (value.isDevice) {
      // A fresh fix replaces the previous one instead of piling up.
      _savedLocations = [
        value,
        ..._savedLocations.where((l) => !l.isDevice && l.key != value.key),
      ];
    } else if (!_savedLocations.any((l) => l.key == value.key)) {
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
