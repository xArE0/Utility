class Habit {
  final int? id;
  final String name;
  final String emoji;
  final int sortOrder;
  final String? scheduledTime; // "HH:mm" 24h format, nullable
  final DateTime createdAt;

  Habit({
    this.id,
    required this.name,
    required this.emoji,
    this.sortOrder = 0,
    this.scheduledTime,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'sortOrder': sortOrder,
        'scheduledTime': scheduledTime,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Habit.fromMap(Map<String, dynamic> m) => Habit(
        id: m['id'],
        name: m['name'],
        emoji: m['emoji'] ?? '✅',
        sortOrder: m['sortOrder'] ?? 0,
        scheduledTime: m['scheduledTime'],
        createdAt: DateTime.parse(m['createdAt']),
      );

  Habit copyWith({
    int? id,
    String? name,
    String? emoji,
    int? sortOrder,
    String? scheduledTime,
    bool clearTime = false,
  }) =>
      Habit(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        sortOrder: sortOrder ?? this.sortOrder,
        scheduledTime: clearTime ? null : (scheduledTime ?? this.scheduledTime),
        createdAt: createdAt,
      );
}

/// One row per (habit, date) pair — presence means "done".
class HabitLog {
  final int? id;
  final int habitId;
  final String date; // yyyy-MM-dd

  HabitLog({this.id, required this.habitId, required this.date});

  Map<String, dynamic> toMap() => {
        'id': id,
        'habitId': habitId,
        'date': date,
      };

  factory HabitLog.fromMap(Map<String, dynamic> m) => HabitLog(
        id: m['id'],
        habitId: m['habitId'],
        date: m['date'],
      );
}
