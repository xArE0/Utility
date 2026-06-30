class CooldownItem {
  final int? id;
  final String name;
  final DateTime? cooldownEnd;
  final DateTime createdAt;
  final int colorIndex;
  final String? category;
  final int? categoryId;

  CooldownItem({
    this.id,
    required this.name,
    this.cooldownEnd,
    DateTime? createdAt,
    this.colorIndex = 0,
    this.category,
    this.categoryId,
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
      'categoryId': categoryId,
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
      categoryId: map['categoryId'],
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
    int? categoryId,
    bool clearCategoryId = false,
  }) {
    return CooldownItem(
      id: id ?? this.id,
      name: name ?? this.name,
      cooldownEnd: clearCooldown ? null : (cooldownEnd ?? this.cooldownEnd),
      createdAt: createdAt ?? this.createdAt,
      colorIndex: colorIndex ?? this.colorIndex,
      category: clearCategory ? null : (category ?? this.category),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
    );
  }
}

class CooldownCategory {
  final int? id;
  final String name;
  final Duration cooldownDuration;
  final int colorIndex;
  final int iconCodePoint;
  final DateTime createdAt;

  CooldownCategory({
    this.id,
    required this.name,
    required this.cooldownDuration,
    this.colorIndex = 0,
    this.iconCodePoint = 0xe2c7,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get readableDuration {
    final days = cooldownDuration.inDays;
    final hours = cooldownDuration.inHours % 24;
    final minutes = cooldownDuration.inMinutes % 60;
    if (days > 0 && hours > 0) return '${days}d ${hours}h';
    if (days > 0) return '${days}d';
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cooldownDurationMinutes': cooldownDuration.inMinutes,
      'colorIndex': colorIndex,
      'iconCodePoint': iconCodePoint,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CooldownCategory.fromMap(Map<String, dynamic> map) {
    return CooldownCategory(
      id: map['id'],
      name: map['name'],
      cooldownDuration: Duration(minutes: map['cooldownDurationMinutes']),
      colorIndex: map['colorIndex'] ?? 0,
      iconCodePoint: map['iconCodePoint'] ?? 0xe2c7,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  CooldownCategory copyWith({
    int? id,
    String? name,
    Duration? cooldownDuration,
    int? colorIndex,
    int? iconCodePoint,
    DateTime? createdAt,
  }) {
    return CooldownCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      cooldownDuration: cooldownDuration ?? this.cooldownDuration,
      colorIndex: colorIndex ?? this.colorIndex,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
