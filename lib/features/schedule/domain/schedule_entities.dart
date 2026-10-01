class Event {
  final int? id;
  final String date;
  final String task;
  final String type;
  final bool remindMe;
  final int? remindDaysBefore;
  final String? remindTime;
  final String? repeat;
  final int? repeatInterval;
  final int? durationDays;
  final bool done;

  Event({
    this.id,
    required this.date,
    required this.task,
    required this.type,
    this.remindMe = false,
    this.remindDaysBefore,
    this.remindTime,
    this.repeat = "none",
    this.repeatInterval,
    this.durationDays,
    this.done = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'task': task,
      'type': type,
      'remindMe': remindMe ? 1 : 0,
      'remindDaysBefore': remindDaysBefore,
      'remindTime': remindTime,
      'repeat': repeat,
      'repeatInterval': repeatInterval,
      'durationDays': durationDays,
      'done': done ? 1 : 0,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      date: map['date'],
      task: map['task'],
      type: map['type'],
      remindMe: (map['remindMe'] ?? 0) == 1,
      remindDaysBefore: map['remindDaysBefore'],
      remindTime: map['remindTime'],
      repeat: map['repeat'] ?? "none",
      repeatInterval: map['repeatInterval'],
      durationDays: map['durationDays'],
      done: (map['done'] ?? 0) == 1,
    );
  }

  bool get isRecurring => type == 'birthday' || (repeat != null && repeat != 'none');

  /// Whether a birthday or repeating event falls on [day] (a date; time is ignored). For one-off
  /// events, whether [day] is its date. Shared by the calendar and reminder scheduling.
  bool occursOn(DateTime day) {
    final start = DateTime.parse(date);
    final d = DateTime(day.year, day.month, day.day);
    if (type == 'birthday') return start.month == d.month && start.day == d.day;
    final startDay = DateTime(start.year, start.month, start.day);
    if (d.isBefore(startDay)) return false;
    switch (repeat) {
      case 'daily':
        return true;
      case 'weekly':
        return d.weekday == start.weekday;
      case 'monthly':
        return d.day == start.day;
      case 'yearly':
        return d.month == start.month && d.day == start.day;
      case 'custom':
        final interval = repeatInterval ?? 1;
        return interval > 0 && d.difference(startDay).inDays % interval == 0;
      default:
        return d == startDay;
    }
  }

  bool spansDate(DateTime target) {
    if (durationDays == null || durationDays! <= 1) return false;
    final start = DateTime.parse(date);
    final end = start.add(Duration(days: durationDays! - 1));
    final normalizedTarget = DateTime(target.year, target.month, target.day);
    return (normalizedTarget.isAtSameMomentAs(start) || normalizedTarget.isAfter(start)) &&
           (normalizedTarget.isAtSameMomentAs(end) || normalizedTarget.isBefore(end));
  }

  int? getDayNumber(DateTime target) {
    if (durationDays == null || durationDays! <= 1) return null;
    final start = DateTime.parse(date);
    final normalizedTarget = DateTime(target.year, target.month, target.day);
    final diff = normalizedTarget.difference(start).inDays;
    if (diff < 0 || diff >= durationDays!) return null;
    return diff + 1;
  }
}
