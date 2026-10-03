/// What the floating controls do when started.
enum AutoClickerMode {
  click('click', 'Click', 'clicks'),
  scroll('scroll', 'Scroll', 'swipes'),
  play('play', 'Replay', 'loops');

  final String key;
  final String label;

  /// What "stop after N …" counts in this mode.
  final String unit;

  const AutoClickerMode(this.key, this.label, this.unit);

  static AutoClickerMode fromKey(String? key) =>
      values.firstWhere((m) => m.key == key, orElse: () => click);
}

/// Which way the finger moves. Up = content moves up = next item (like swiping reels).
enum ScrollDirection {
  up('up', 'Up'),
  down('down', 'Down'),
  left('left', 'Left'),
  right('right', 'Right');

  final String key;
  final String label;

  const ScrollDirection(this.key, this.label);

  static ScrollDirection fromKey(String? key) =>
      values.firstWhere((d) => d.key == key, orElse: () => up);
}

/// What to do, how often, and for how long.
class AutoClickerConfig {
  static const int minIntervalMs = 50;
  static const int maxIntervalMs = 3600000; // 1 hour
  static const int maxClickLimit = 1000000;

  final AutoClickerMode mode;
  final int intervalMs;

  /// Stop after this many taps / swipes / replay loops. 0 means keep going until stopped.
  final int maxClicks;

  final ScrollDirection scrollDirection;

  /// Swipe length as a percentage of the screen (height, or width when sideways).
  final int scrollDistancePct;

  /// How long one swipe takes; shorter flings further.
  final int swipeMs;

  /// The recording replay mode plays; null when none is chosen.
  final String? recordingId;

  const AutoClickerConfig({
    this.mode = AutoClickerMode.click,
    this.intervalMs = 500,
    this.maxClicks = 0,
    this.scrollDirection = ScrollDirection.up,
    this.scrollDistancePct = 50,
    this.swipeMs = 350,
    this.recordingId,
  });

  bool get isUnlimited => maxClicks == 0;

  AutoClickerConfig copyWith({
    AutoClickerMode? mode,
    int? intervalMs,
    int? maxClicks,
    ScrollDirection? scrollDirection,
    int? scrollDistancePct,
    int? swipeMs,
    String? recordingId,
    bool clearRecording = false,
  }) {
    return AutoClickerConfig(
      mode: mode ?? this.mode,
      intervalMs: (intervalMs ?? this.intervalMs).clamp(minIntervalMs, maxIntervalMs),
      maxClicks: (maxClicks ?? this.maxClicks).clamp(0, maxClickLimit),
      scrollDirection: scrollDirection ?? this.scrollDirection,
      scrollDistancePct: (scrollDistancePct ?? this.scrollDistancePct).clamp(10, 90),
      swipeMs: (swipeMs ?? this.swipeMs).clamp(50, 3000),
      recordingId: clearRecording ? null : (recordingId ?? this.recordingId),
    );
  }
}

/// A saved touch recording (the touches themselves stay on the native side).
class AutoClickerRecording {
  final String id;
  final String name;
  final DateTime createdAt;
  final int steps;
  final int lengthMs;

  const AutoClickerRecording({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.steps,
    required this.lengthMs,
  });

  factory AutoClickerRecording.fromMap(Map<Object?, Object?> map) => AutoClickerRecording(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? 'Recording',
        createdAt: DateTime.fromMillisecondsSinceEpoch((map['createdAt'] as num?)?.toInt() ?? 0),
        steps: (map['steps'] as num?)?.toInt() ?? 0,
        lengthMs: (map['lengthMs'] as num?)?.toInt() ?? 0,
      );
}

/// Live state reported by the native accessibility service.
class AutoClickerStatus {
  /// The user switched the service on in Android settings (it may not have connected yet).
  final bool serviceEnabled;

  /// The service is bound and able to draw and tap right now.
  final bool serviceConnected;

  /// The floating target + control panel are on screen.
  final bool overlayVisible;

  /// Taps are currently being fired.
  final bool running;
  final int taps;

  /// Touches are being recorded; [recordedCount] so far.
  final bool recording;
  final int recordedCount;

  /// The mode and recording the service is set to (it switches to replay after saving one).
  final String mode;
  final String recordingId;

  /// Changes whenever recordings are added, renamed or deleted.
  final int recordingsVersion;

  /// Xiaomi/Redmi/POCO (MIUI/HyperOS): these kill backgrounded apps unless "Autostart" is granted,
  /// which is the most common reason the service goes from connected to merely "enabled".
  final bool isXiaomi;

  const AutoClickerStatus({
    this.serviceEnabled = false,
    this.serviceConnected = false,
    this.overlayVisible = false,
    this.running = false,
    this.taps = 0,
    this.recording = false,
    this.recordedCount = 0,
    this.mode = 'click',
    this.recordingId = '',
    this.recordingsVersion = 0,
    this.isXiaomi = false,
  });

  factory AutoClickerStatus.fromMap(Map<Object?, Object?> map) {
    return AutoClickerStatus(
      serviceEnabled: map['serviceEnabled'] == true,
      serviceConnected: map['serviceConnected'] == true,
      overlayVisible: map['overlayVisible'] == true,
      running: map['running'] == true,
      taps: (map['taps'] as num?)?.toInt() ?? 0,
      recording: map['recording'] == true,
      recordedCount: (map['recordedCount'] as num?)?.toInt() ?? 0,
      mode: (map['mode'] as String?) ?? 'click',
      recordingId: (map['recordingId'] as String?) ?? '',
      recordingsVersion: (map['recordingsVersion'] as num?)?.toInt() ?? 0,
      isXiaomi: map['isXiaomi'] == true,
    );
  }
}

/// A failure reported by the native side, carrying a message that is safe to show to the user.
class AutoClickerException implements Exception {
  final String code;
  final String message;

  const AutoClickerException(this.code, this.message);

  @override
  String toString() => message;
}
