class CooldownItem {
  final int? id;
  final String name;
  final DateTime? cooldownEnd;
  final DateTime createdAt;
  final int colorIndex; // 0-5, maps to accent colors

  CooldownItem({
    this.id,
    required this.name,
    this.cooldownEnd,
    DateTime? createdAt,
    this.colorIndex = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOnCooldown =>
      cooldownEnd != null && cooldownEnd!.isAfter(DateTime.now());

  Duration get remainingDuration {
    if (!isOnCooldown) return Duration.zero;
    return cooldownEnd!.difference(DateTime.now());
  }

  /// Returns a human-friendly remaining time string, e.g. "2d 5h", "3h 14m", "45s"
  String get readableRemaining {
    final d = remainingDuration;
    if (d <= Duration.zero) return 'Ready!';
    if (d.inDays > 0) {
      final hours = d.inHours % 24;
      return '${d.inDays}d ${hours}h';
    }
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return '${d.inHours}h ${mins}m';
    }
    if (d.inMinutes > 0) {
      final secs = d.inSeconds % 60;
      return '${d.inMinutes}m ${secs}s';
    }
    return '${d.inSeconds}s';
  }

  /// Progress ratio 0.0 (just started) → 1.0 (done).
  /// Uses createdAt as the start reference when cooldown is active.
  double get cooldownProgress {
    if (cooldownEnd == null) return 1.0;
    final total = cooldownEnd!.difference(createdAt).inSeconds;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cooldownEnd': cooldownEnd?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'colorIndex': colorIndex,
    };
  }

  factory CooldownItem.fromMap(Map<String, dynamic> map) {
    return CooldownItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      cooldownEnd: map['cooldownEnd'] != null
          ? DateTime.parse(map['cooldownEnd'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      colorIndex: (map['colorIndex'] as int?) ?? 0,
    );
  }

  CooldownItem copyWith({
    int? id,
    String? name,
    DateTime? cooldownEnd,
    bool clearCooldown = false,
    DateTime? createdAt,
    int? colorIndex,
  }) {
    return CooldownItem(
      id: id ?? this.id,
      name: name ?? this.name,
      cooldownEnd: clearCooldown ? null : (cooldownEnd ?? this.cooldownEnd),
      createdAt: createdAt ?? this.createdAt,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}
