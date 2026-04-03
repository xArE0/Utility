import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/autoclicker_repository.dart';

class AutoClickerController extends ChangeNotifier {
  final IAutoClickerRepository _repository;

  int _delay = 1200;
  int _x = 500;
  int _y = 800;
  bool _accessEnabled = false;
  bool _checking = true;
  String? _error;

  int get delay => _delay;
  int get x => _x;
  int get y => _y;
  bool get accessEnabled => _accessEnabled;
  bool get checking => _checking;
  String? get error => _error;

  AutoClickerController({required IAutoClickerRepository repository}) : _repository = repository;

  set error(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> init() async {
    await _repository.init();
    await _loadData();
    _checking = false;
    notifyListeners();
  }

  Future<void> _loadData() async {
    _delay = await _repository.getDelay();
    final coords = await _repository.getCoords();
    _x = coords['x']!;
    _y = coords['y']!;
    _accessEnabled = await _repository.isAccessibilityEnabled();
  }

  Future<void> saveDelay(int value) async {
    _delay = value;
    notifyListeners();
    await _repository.saveDelay(value);
  }

  Future<void> saveCoords(int x, int y) async {
    _x = x;
    _y = y;
    notifyListeners();
    await _repository.saveCoords(x, y);
  }

  Future<void> checkAccessibility() async {
    _accessEnabled = await _repository.isAccessibilityEnabled();
    notifyListeners();
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _repository.openAccessibilitySettings();
    } catch (e) {
      _error = "Couldn't open accessibility settings: $e";
      notifyListeners();
    }
  }

  Future<void> startFloatingService(BuildContext context) async {
    _error = null;
    notifyListeners();
    await checkAccessibility();
    if (!_accessEnabled) {
      _error = "Enable the Accessibility Service first.";
      notifyListeners();
      return;
    }
    try {
      await _repository.startService();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Floating dot shown. Move it, then tap the dot to start/stop autoclicking.")),
        );
      }
    } on PlatformException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> stopAutoclick(BuildContext context) async {
    try {
      await _repository.stopAutoclick();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Autoclick stopped.")),
        );
      }
    } catch (_) {}
  }
}
