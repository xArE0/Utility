import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/autoclicker_entities.dart';
import '../domain/autoclicker_repository.dart';

class AutoClickerController extends ChangeNotifier {
  final IAutoClickerRepository _repository;
  StreamSubscription<AutoClickerStatus>? _statusSub;

  AutoClickerConfig _config = const AutoClickerConfig();
  AutoClickerStatus _status = const AutoClickerStatus();
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;

  AutoClickerController({required IAutoClickerRepository repository}) : _repository = repository;

  AutoClickerConfig get config => _config;
  AutoClickerStatus get status => _status;
  bool get loading => _loading;
  bool get busy => _busy;

  Future<void> init() async {
    _config = await _repository.loadConfig();
    _statusSub = _repository.statusStream.listen(_onStatus);
    await refresh();
    _loading = false;
    notifyListeners();
  }

  /// Re-reads native state; call when returning from Android settings.
  Future<void> refresh() async {
    try {
      _status = await _repository.getStatus();
    } on AutoClickerException {
      _status = const AutoClickerStatus();
    }
    notifyListeners();
  }

  void _onStatus(AutoClickerStatus status) {
    _status = status;
    notifyListeners();
  }

  Future<void> setInterval(int ms) => _setConfig(_config.copyWith(intervalMs: ms));

  /// 0 = unlimited.
  Future<void> setMaxClicks(int count) => _setConfig(_config.copyWith(maxClicks: count));

  Future<void> _setConfig(AutoClickerConfig next) async {
    _config = next;
    notifyListeners();
    await _repository.saveConfig(next);
    if (_status.overlayVisible) {
      try {
        await _repository.updateConfig(next);
      } on AutoClickerException {
        // Overlay went away between the check and the call; the saved config applies next time.
      }
    }
  }

  /// Shows the floating controls and sends the app to the background so the user can go to the
  /// app they want to click in. Returns an error message to display, or null on success.
  Future<String?> showOverlay() async {
    return _guarded(() async {
      await _repository.showOverlay(_config);
      await _repository.moveToBackground();
    });
  }

  Future<String?> hideOverlay() => _guarded(_repository.hideOverlay);

  /// Starts clicking, then steps this app aside so the taps land in whatever is underneath.
  Future<String?> startClicking() {
    return _guarded(() async {
      await _repository.startClicking();
      await _repository.moveToBackground();
    });
  }

  Future<String?> stopClicking() => _guarded(_repository.stopClicking);

  Future<String?> openAccessibilitySettings() => _guarded(_repository.openAccessibilitySettings);

  Future<String?> openAppInfo() => _guarded(_repository.openAppInfo);

  Future<String?> openAutostartSettings() => _guarded(_repository.openAutostartSettings);

  Future<String?> _guarded(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
      return null;
    } on AutoClickerException catch (e) {
      return e.message;
    } finally {
      _busy = false;
      await refresh();
    }
  }

  // Async native calls can finish after the screen is gone.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _statusSub?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
