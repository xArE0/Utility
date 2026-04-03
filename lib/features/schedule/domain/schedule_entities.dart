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
    );
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
