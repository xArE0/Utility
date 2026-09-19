/// What to click: how often, and for how long.
class AutoClickerConfig {
  static const int minIntervalMs = 50;
  static const int maxIntervalMs = 3600000; // 1 hour
  static const int maxClickLimit = 1000000;

  final int intervalMs;

  /// Stop after this many taps. 0 means keep going until stopped.
  final int maxClicks;

  const AutoClickerConfig({this.intervalMs = 500, this.maxClicks = 0});

  bool get isUnlimited => maxClicks == 0;

  AutoClickerConfig copyWith({int? intervalMs, int? maxClicks}) {
    return AutoClickerConfig(
      intervalMs: (intervalMs ?? this.intervalMs).clamp(minIntervalMs, maxIntervalMs),
      maxClicks: (maxClicks ?? this.maxClicks).clamp(0, maxClickLimit),
    );
  }
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

  /// Xiaomi/Redmi/POCO (MIUI/HyperOS): these kill backgrounded apps unless "Autostart" is granted,
  /// which is the most common reason the service goes from connected to merely "enabled".
  final bool isXiaomi;

  const AutoClickerStatus({
    this.serviceEnabled = false,
    this.serviceConnected = false,
    this.overlayVisible = false,
    this.running = false,
    this.taps = 0,
    this.isXiaomi = false,
  });

  factory AutoClickerStatus.fromMap(Map<Object?, Object?> map) {
    return AutoClickerStatus(
      serviceEnabled: map['serviceEnabled'] == true,
      serviceConnected: map['serviceConnected'] == true,
      overlayVisible: map['overlayVisible'] == true,
      running: map['running'] == true,
      taps: (map['taps'] as num?)?.toInt() ?? 0,
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
