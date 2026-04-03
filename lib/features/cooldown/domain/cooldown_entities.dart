class CooldownItem {
  final int? id;
  final String name;
  final DateTime? cooldownEnd;
  final DateTime createdAt;
  final int colorIndex;
  final String? category;

  CooldownItem({
    this.id,
    required this.name,
    this.cooldownEnd,
    DateTime? createdAt,
    this.colorIndex = 0,
    this.category,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOnCooldown {
    if (cooldownEnd == null) return false;
    return cooldownEnd!.isAfter(DateTime.now());
  }

  double get cooldownProgress {
    if (cooldownEnd == null) return 0.0;
    final now = DateTime.now();
    if (now.isAfter(cooldownEnd!)) return 0.0;

    final total = cooldownEnd!.difference(createdAt).inSeconds;
    if (total <= 0) return 0.0;
    final remaining = cooldownEnd!.difference(now).inSeconds;
    return (remaining / total).clamp(0.0, 1.0);
  }

  String get readableRemaining {
    if (cooldownEnd == null) return '';
    final diff = cooldownEnd!.difference(DateTime.now());
    if (diff.isNegative) return 'Ready';

    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
    } else {
      return '${diff.inSeconds}s';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cooldownEnd': cooldownEnd?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'colorIndex': colorIndex,
      'category': category,
    };
  }

  factory CooldownItem.fromMap(Map<String, dynamic> map) {
    return CooldownItem(
      id: map['id'],
      name: map['name'],
      cooldownEnd: map['cooldownEnd'] != null
          ? DateTime.parse(map['cooldownEnd'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
      colorIndex: map['colorIndex'] ?? 0,
      category: map['category'],
    );
  }

  CooldownItem copyWith({
    int? id,
    String? name,
    DateTime? cooldownEnd,
    bool clearCooldown = false,
    DateTime? createdAt,
    int? colorIndex,
    String? category,
    bool clearCategory = false,
  }) {
    return CooldownItem(
      id: id ?? this.id,
      name: name ?? this.name,
      cooldownEnd: clearCooldown ? null : (cooldownEnd ?? this.cooldownEnd),
      createdAt: createdAt ?? this.createdAt,
      colorIndex: colorIndex ?? this.colorIndex,
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}
