import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/autoclicker_entities.dart';
import '../domain/autoclicker_repository.dart';

class AutoClickerController extends ChangeNotifier {
  final IAutoClickerRepository _repository;
  StreamSubscription<AutoClickerStatus>? _statusSub;

  AutoClickerConfig _config = const AutoClickerConfig();
  AutoClickerStatus _status = const AutoClickerStatus();
  List<AutoClickerRecording> _recordings = const [];
  int _recordingsVersion = -1;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;

  AutoClickerController({required IAutoClickerRepository repository}) : _repository = repository;

  AutoClickerConfig get config => _config;
  AutoClickerStatus get status => _status;
  bool get loading => _loading;
  bool get busy => _busy;
  List<AutoClickerRecording> get recordings => _recordings;

  AutoClickerRecording? get selectedRecording {
    for (final r in _recordings) {
      if (r.id == _config.recordingId) return r;
    }
    return null;
  }

  Future<void> init() async {
    _config = await _repository.loadConfig();
    // The service forgets settings when the app's process restarts; give it the saved ones before
    // reading its state back, so its defaults don't overwrite them.
    try {
      await _repository.updateConfig(_config);
    } on AutoClickerException {
      // Not on Android / not available: nothing to sync.
    }
    _statusSub = _repository.statusStream.listen(_onStatus);
    await loadRecordings();
    await refresh();
    _loading = false;
    notifyListeners();
  }

  /// Re-reads native state; call when returning from Android settings.
  Future<void> refresh() async {
    try {
      await _applyStatus(await _repository.getStatus());
    } on AutoClickerException {
      _status = const AutoClickerStatus();
    }
    notifyListeners();
  }

  void _onStatus(AutoClickerStatus status) {
    _applyStatus(status);
    notifyListeners();
  }

  /// Takes on what the service changed by itself: a new recording (and the switch to replay it).
  Future<void> _applyStatus(AutoClickerStatus status) async {
    _status = status;
    if (status.recordingsVersion != _recordingsVersion) {
      _recordingsVersion = status.recordingsVersion;
      await loadRecordings();
    }
    if (!status.serviceConnected) return;
    final mode = AutoClickerMode.fromKey(status.mode);
    final id = status.recordingId.isEmpty ? null : status.recordingId;
    if (mode != _config.mode || id != _config.recordingId) {
      _config = _config.copyWith(mode: mode, recordingId: id, clearRecording: id == null);
      await _repository.saveConfig(_config);
    }
  }

  Future<void> loadRecordings() async {
    try {
      _recordings = await _repository.getRecordings();
    } on AutoClickerException {
      _recordings = const [];
    }
    notifyListeners();
  }

  Future<void> setInterval(int ms) => _setConfig(_config.copyWith(intervalMs: ms));

  Future<void> setMode(AutoClickerMode mode) => _setConfig(_config.copyWith(mode: mode));

  Future<void> setScrollDirection(ScrollDirection d) =>
      _setConfig(_config.copyWith(scrollDirection: d));

  Future<void> setScrollDistance(int pct) => _setConfig(_config.copyWith(scrollDistancePct: pct));

  Future<void> setSwipeMs(int ms) => _setConfig(_config.copyWith(swipeMs: ms));

  Future<void> selectRecording(String id) => _setConfig(_config.copyWith(recordingId: id));

  Future<String?> renameRecording(String id, String name) => _guarded(() async {
        await _repository.renameRecording(id, name.trim());
        await loadRecordings();
      });

  Future<String?> deleteRecording(String id) => _guarded(() async {
        await _repository.deleteRecording(id);
        if (_config.recordingId == id) {
          await _setConfig(_config.copyWith(clearRecording: true));
        }
        await loadRecordings();
      });

  /// Shows the controls if needed, steps aside, then records the next touches.
  Future<String?> startRecording() => _guarded(() async {
        if (!_status.overlayVisible) await _repository.showOverlay(_config);
        await _repository.startRecording();
        await _repository.moveToBackground();
      });

  Future<String?> stopRecording() => _guarded(_repository.stopRecording);

  /// 0 = unlimited.
  Future<void> setMaxClicks(int count) => _setConfig(_config.copyWith(maxClicks: count));

  Future<void> _setConfig(AutoClickerConfig next) async {
    _config = next;
    notifyListeners();
    await _repository.saveConfig(next);
    if (_status.serviceConnected) {
      try {
        await _repository.updateConfig(next);
      } on AutoClickerException {
        // Service went away between the check and the call; the saved config applies next time.
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
