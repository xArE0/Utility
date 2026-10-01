import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Snapshot of the home screen widget's native state (see UtilityWidget.kt).
class HomeWidgetState {
  final int timer1;
  final int timer2;
  final int awakeMinutes;
  final bool awakeOn;
  final bool canWriteSettings;

  /// End of the running timer, or null when none is running.
  final DateTime? timerEnd;
  final int timerMinutes;

  const HomeWidgetState({
    this.timer1 = 5,
    this.timer2 = 15,
    this.awakeMinutes = 10,
    this.awakeOn = false,
    this.canWriteSettings = false,
    this.timerEnd,
    this.timerMinutes = 0,
  });

  factory HomeWidgetState.fromMap(Map<String, dynamic> map) {
    final endMs = map['timerEndMs'] as int?;
    return HomeWidgetState(
      timer1: map['timer1'] as int? ?? 5,
      timer2: map['timer2'] as int? ?? 15,
      awakeMinutes: map['awakeMinutes'] as int? ?? 10,
      awakeOn: map['awakeOn'] as bool? ?? false,
      canWriteSettings: map['canWriteSettings'] as bool? ?? false,
      timerEnd:
          endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs),
      timerMinutes: map['timerMinutes'] as int? ?? 0,
    );
  }
}

/// Bridge to the native home screen widget. The widget owns its state; this mirrors it and is
/// pushed a "changed" call whenever a widget tap, the timer alarm or the app changes anything.
///
/// Every call fails quietly: the widget is a convenience and must never break app startup.
class HomeWidgetService extends ChangeNotifier {
  HomeWidgetService._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await refresh();
    });
  }

  static final HomeWidgetService instance = HomeWidgetService._();

  static const _channel = MethodChannel('com.example.utility/widget');

  HomeWidgetState _state = const HomeWidgetState();
  HomeWidgetState get state => _state;

  Future<void> refresh() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getState');
      if (raw == null) return;
      _state = HomeWidgetState.fromMap(raw);
      notifyListeners();
    } catch (e) {
      debugPrint('Widget state unavailable: $e');
    }
  }

  Future<void> configure({
    required int timer1,
    required int timer2,
    required int awakeMinutes,
  }) =>
      _call('configure', {
        'timer1': timer1,
        'timer2': timer2,
        'awakeMinutes': awakeMinutes,
      });

  Future<void> setAqi(String text) => _call('setAqi', {'text': text});

  Future<void> cancelTimer() => _call('cancelTimer');

  Future<void> openWriteSettings() => _call('openWriteSettings');

  Future<void> _call(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod(method, args);
    } catch (e) {
      debugPrint('Widget call "$method" failed: $e');
    }
  }
}
