import 'package:flutter/material.dart';

abstract class IAutoClickerRepository {
  Future<void> init();
  Future<int> getDelay();
  Future<void> saveDelay(int value);
  Future<Map<String, int>> getCoords();
  Future<void> saveCoords(int x, int y);
  Future<bool> isAccessibilityEnabled();
  Future<void> openAccessibilitySettings();
  Future<void> startService();
  Future<void> stopAutoclick();
}
