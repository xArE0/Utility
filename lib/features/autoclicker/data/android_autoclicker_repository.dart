import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/autoclicker_entities.dart';
import '../domain/autoclicker_repository.dart';

class AndroidAutoClickerRepository implements IAutoClickerRepository {
  static const _channel = MethodChannel('com.example.utility/autoclicker');
  static const _intervalKey = 'autoclicker_interval_ms';
  static const _maxClicksKey = 'autoclicker_max_clicks';

  final _statusController = StreamController<AutoClickerStatus>.broadcast();

  AndroidAutoClickerRepository() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'status' && call.arguments is Map) {
        _statusController.add(AutoClickerStatus.fromMap(call.arguments as Map));
      }
    });
  }

  @override
  Stream<AutoClickerStatus> get statusStream => _statusController.stream;

  @override
  Future<AutoClickerConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return const AutoClickerConfig().copyWith(
      intervalMs: prefs.getInt(_intervalKey),
      maxClicks: prefs.getInt(_maxClicksKey),
    );
  }

  @override
  Future<void> saveConfig(AutoClickerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, config.intervalMs);
    await prefs.setInt(_maxClicksKey, config.maxClicks);
  }

  @override
  Future<AutoClickerStatus> getStatus() async {
    final map = await _invoke<Map<Object?, Object?>>('getStatus');
    return map == null ? const AutoClickerStatus() : AutoClickerStatus.fromMap(map);
  }

  @override
  Future<void> showOverlay(AutoClickerConfig config) => _invoke('showOverlay', _args(config));

  @override
  Future<void> hideOverlay() => _invoke('hideOverlay');

  @override
  Future<void> startClicking() => _invoke('startClicking');

  @override
  Future<void> stopClicking() => _invoke('stopClicking');

  @override
  Future<void> updateConfig(AutoClickerConfig config) => _invoke('updateConfig', _args(config));

  @override
  Future<void> openAccessibilitySettings() => _invoke('openAccessibilitySettings');

  @override
  Future<void> openAppInfo() => _invoke('openAppInfo');

  @override
  Future<void> openAutostartSettings() => _invoke('openAutostartSettings');

  @override
  Future<void> moveToBackground() => _invoke('moveToBackground');

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _statusController.close();
  }

  Map<String, Object> _args(AutoClickerConfig c) => {
        'intervalMs': c.intervalMs,
        'maxClicks': c.maxClicks,
      };

  /// Native failures keep their message so the UI can show exactly what went wrong.
  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw AutoClickerException(e.code, e.message ?? 'Auto Clicker error (${e.code})');
    } on MissingPluginException {
      throw const AutoClickerException('UNSUPPORTED', 'Auto Clicker is only available on Android.');
    }
  }
}
