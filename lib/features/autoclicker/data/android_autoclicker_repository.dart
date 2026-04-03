import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/autoclicker_repository.dart';

class AndroidAutoClickerRepository implements IAutoClickerRepository {
  static const platform = MethodChannel("floating_dot");

  @override
  Future<void> init() async {}

  @override
  Future<int> getDelay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('autoclick_delay') ?? 1200;
  }

  @override
  Future<void> saveDelay(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoclick_delay', value);
  }

  @override
  Future<Map<String, int>> getCoords() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'x': prefs.getInt('autoclick_x') ?? 500,
      'y': prefs.getInt('autoclick_y') ?? 800,
    };
  }

  @override
  Future<void> saveCoords(int x, int y) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoclick_x', x);
    await prefs.setInt('autoclick_y', y);
  }

  @override
  Future<bool> isAccessibilityEnabled() async {
    try {
      return await platform.invokeMethod<bool>("isAccessibilityEnabled") ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> openAccessibilitySettings() async {
    await platform.invokeMethod("openAccessibilitySettings");
  }

  @override
  Future<void> startService() async {
    await platform.invokeMethod("startService");
  }

  @override
  Future<void> stopAutoclick() async {
    await platform.invokeMethod("stopAutoclick");
  }
}
