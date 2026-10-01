import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/volume_entities.dart';
import '../domain/volume_repository.dart';

class VolumeController extends ChangeNotifier {
  final IVolumeRepository _repository;

  List<VolumeRule> _rules = [];
  VolumeState _state = const VolumeState();
  bool _loading = true;
  bool _disposed = false;
  StreamSubscription<void>? _changesSub;
  Timer? _debounce;

  VolumeController({required IVolumeRepository repository})
      : _repository = repository;

  /// Sorted by time of day.
  List<VolumeRule> get rules => _rules;
  VolumeState get state => _state;
  bool get loading => _loading;

  /// Returns an error message to display, or null on success.
  Future<String?> init() async {
    // Dragging a volume slider fires a burst of changes; refresh once it settles.
    _changesSub = _repository.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), refresh);
    });
    try {
      await startListening();
      await refresh();
      return null;
    } on VolumeException catch (e) {
      return e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Live updates while the screen is visible; stop when it isn't so nothing runs in the background.
  Future<void> startListening() async {
    try {
      await _repository.startListening();
    } on VolumeException {
      // Not fatal: the card still refreshes on resume and pull-to-refresh.
    }
  }

  Future<void> stopListening() async {
    try {
      await _repository.stopListening();
    } on VolumeException {
      // Already gone.
    }
  }

  /// Re-reads rules (one-shots switch themselves off natively), live levels and the run log.
  Future<void> refresh() async {
    try {
      _rules = _sorted(await _repository.loadRules());
      _state = await _repository.getState();
    } on VolumeException {
      _state = const VolumeState();
    }
    notifyListeners();
  }

  /// Switching on (or saving) a one-shot arms it for the next time its hour:minute comes round.
  Future<String?> upsert(VolumeRule rule) {
    if (rule.once && rule.enabled) {
      rule = rule.copyWith(armedAt: DateTime.now().millisecondsSinceEpoch);
    }
    final next = [..._rules.where((r) => r.id != rule.id), rule];
    return _save(next);
  }

  Future<String?> delete(String id) =>
      _save(_rules.where((r) => r.id != id).toList());

  Future<String?> setEnabled(VolumeRule rule, bool enabled) =>
      upsert(rule.copyWith(enabled: enabled));

  Future<String?> applyNow(VolumeRule rule) async {
    try {
      await _repository.applyNow(rule.id);
      return null;
    } on VolumeException catch (e) {
      return e.message;
    } finally {
      await refresh();
    }
  }

  Future<String?> openAutostartSettings() async {
    try {
      await _repository.openAutostartSettings();
      return null;
    } on VolumeException catch (e) {
      return e.message;
    }
  }

  Future<String?> _save(List<VolumeRule> next) async {
    final previous = _rules;
    _rules = _sorted(next);
    notifyListeners();
    try {
      await _repository.saveRules(_rules);
      return null;
    } on VolumeException catch (e) {
      _rules = previous;
      return e.message;
    } finally {
      await refresh();
    }
  }

  List<VolumeRule> _sorted(List<VolumeRule> rules) =>
      [...rules]..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));

  // Async native calls can finish after the screen is gone.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _changesSub?.cancel();
    _repository.stopListening().catchError((_) {});
    _repository.dispose();
    super.dispose();
  }
}
