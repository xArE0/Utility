/// Android volume streams the schedule can change. [key] matches the native side.
enum VolumeStream {
  media('media', 'Media'),
  ring('ring', 'Ring'),
  notification('notification', 'Notification'),
  alarm('alarm', 'Alarm');

  final String key;
  final String label;

  const VolumeStream(this.key, this.label);

  /// Ring/notification can't go to 0 (that switches the phone to vibrate) and are skipped while
  /// the phone is on vibrate/silent.
  bool get isRinger => this == ring || this == notification;

  static VolumeStream? fromKey(String key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// At [hour]:[minute] on [days], set each stream in [levels] to that percent.
///
/// A [once] rule ignores [days]: it runs at the first [hour]:[minute] after [armedAt] (when it
/// was switched on), then the native side switches it off again.
class VolumeRule {
  final String id;
  final String label;
  final int hour;
  final int minute;

  /// 1 = Monday … 7 = Sunday, like [DateTime.weekday].
  final Set<int> days;
  final bool enabled;
  final Map<VolumeStream, int> levels;
  final bool once;

  /// Milliseconds since epoch when a [once] rule was last switched on.
  final int? armedAt;

  const VolumeRule({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.days,
    this.enabled = true,
    required this.levels,
    this.once = false,
    this.armedAt,
  });

  VolumeRule copyWith({
    String? label,
    int? hour,
    int? minute,
    Set<int>? days,
    bool? enabled,
    Map<VolumeStream, int>? levels,
    bool? once,
    int? armedAt,
  }) {
    return VolumeRule(
      id: id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      days: days ?? this.days,
      enabled: enabled ?? this.enabled,
      levels: levels ?? this.levels,
      once: once ?? this.once,
      armedAt: armedAt ?? this.armedAt,
    );
  }

  /// When a switched-on [once] rule will run; null if it's off or has already run.
  DateTime? get onceRunAt {
    if (!once || !enabled || armedAt == null) return null;
    final armed = DateTime.fromMillisecondsSinceEpoch(armedAt!);
    var at = DateTime(armed.year, armed.month, armed.day, hour, minute);
    if (!at.isAfter(armed)) {
      at = DateTime(at.year, at.month, at.day + 1, hour, minute);
    }
    return at;
  }

  /// Minutes since midnight, for sorting.
  int get minuteOfDay => hour * 60 + minute;

  Map<String, Object> toJson() => {
        'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'days': (days.toList()..sort()),
        'enabled': enabled,
        'levels': {for (final e in levels.entries) e.key.key: e.value},
        'once': once,
        if (armedAt != null) 'armedAt': armedAt!,
      };

  factory VolumeRule.fromJson(Map<String, dynamic> json) {
    final rawLevels = (json['levels'] as Map?) ?? const {};
    return VolumeRule(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? '',
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
      days: ((json['days'] as List?) ?? const [])
          .map((d) => (d as num).toInt())
          .toSet(),
      enabled: json['enabled'] != false,
      levels: {
        for (final e in rawLevels.entries)
          if (VolumeStream.fromKey(e.key as String) != null)
            VolumeStream.fromKey(e.key as String)!: (e.value as num).toInt(),
      },
      once: json['once'] == true,
      armedAt: (json['armedAt'] as num?)?.toInt(),
    );
  }
}

/// A stream's real step range on this phone. Percentages are rounded to these steps.
class StreamInfo {
  final int min;
  final int max;
  final int current;

  const StreamInfo(
      {required this.min, required this.max, required this.current});

  int stepFor(int percent, {bool isRinger = false}) {
    var step = (percent / 100 * max).round().clamp(min, max);
    if (isRinger && step < 1) step = 1;
    return step;
  }

  int percentOf(int step) => max == 0 ? 0 : (step * 100 / max).round();
}

/// One run of the schedule, as recorded natively (so it covers runs while the app was closed).
class VolumeLogEntry {
  final DateTime at;
  final String label;
  final bool manual;
  final List<String> result;

  const VolumeLogEntry({
    required this.at,
    required this.label,
    required this.manual,
    required this.result,
  });

  factory VolumeLogEntry.fromJson(Map<String, dynamic> json) => VolumeLogEntry(
        at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num).toInt()),
        label: (json['label'] as String?) ?? '',
        manual: json['manual'] == true,
        result: ((json['result'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class VolumeState {
  final Map<VolumeStream, StreamInfo> streams;

  /// 'normal', 'vibrate' or 'silent'.
  final String ringerMode;
  final DateTime? nextChange;
  final List<VolumeLogEntry> log;

  /// Xiaomi/Redmi/POCO: alarms and boot events are dropped for swiped-away apps unless
  /// "Autostart" is granted.
  final bool isXiaomi;

  /// Xiaomi only: 'allowed', 'denied', or 'unknown' when the ROM wouldn't say.
  final String autostart;

  const VolumeState({
    this.streams = const {},
    this.ringerMode = 'normal',
    this.nextChange,
    this.log = const [],
    this.isXiaomi = false,
    this.autostart = 'unknown',
  });
}

/// A failure reported by the native side, carrying a message that is safe to show to the user.
class VolumeException implements Exception {
  final String code;
  final String message;

  const VolumeException(this.code, this.message);

  @override
  String toString() => message;
}
