class LogEntry {
  final int? id;
  final String title;
  final String startDate; // yyyy-MM-dd
  final String? note;
  final String colorHex; // e.g. '#FF6B35'
  final String? category;
  final List<LogCheckpoint> checkpoints;

  LogEntry({
    this.id,
    required this.title,
    required this.startDate,
    this.note,
    this.colorHex = '#FF6B35',
    this.category,
    this.checkpoints = const [],
  });

  /// Days elapsed since the most recent checkpoint (or startDate if none)
  int get elapsedDays {
    final latest = checkpoints.isNotEmpty
        ? checkpoints.first.date // checkpoints sorted newest-first
        : startDate;
    final from = DateTime.parse(latest);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;
  }

  /// Total days since very first creation
  int get totalDays {
    final from = DateTime.parse(startDate);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate,
      'note': note,
      'colorHex': colorHex,
      'category': category,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map, {List<LogCheckpoint> checkpoints = const []}) {
    return LogEntry(
      id: map['id'],
      title: map['title'],
      startDate: map['startDate'],
      note: map['note'],
      colorHex: map['colorHex'] ?? '#FF6B35',
      category: map['category'],
      checkpoints: checkpoints,
    );
  }

  LogEntry copyWith({
    int? id,
    String? title,
    String? startDate,
    String? note,
    String? colorHex,
    String? category,
    List<LogCheckpoint>? checkpoints,
  }) {
    return LogEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      note: note ?? this.note,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      checkpoints: checkpoints ?? this.checkpoints,
    );
  }
}

class LogCheckpoint {
  final int? id;
  final int entryId;
  final String date; // yyyy-MM-dd
  final String? note;

  LogCheckpoint({
    this.id,
    required this.entryId,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entryId': entryId,
      'date': date,
      'note': note,
    };
  }

  factory LogCheckpoint.fromMap(Map<String, dynamic> map) {
    return LogCheckpoint(
      id: map['id'],
      entryId: map['entryId'],
      date: map['date'],
      note: map['note'],
    );
  }
}
