import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Event {
  final int? id;
  final String date;
  final String task;
  final String type;
  final bool remindMe;
  final int? remindDaysBefore;
  final String? remindTime;
  final String? repeat; // e.g. "none", "daily", "weekly", "monthly", "yearly"
  final int? repeatInterval; // for custom e.g. every x days
  final int? durationDays; // for multi-day events: null or 1 = single day, 2+ = multi-day

  Event({
    this.id,
    required this.date,
    required this.task,
    this.type = 'normal',
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
      type: map['type'] ?? 'normal',
      remindMe: (map['remindMe'] ?? 0) == 1,
      remindDaysBefore: map['remindDaysBefore'],
      remindTime: map['remindTime'],
      repeat: map['repeat'] ?? "none",
      repeatInterval: map['repeatInterval'],
      durationDays: map['durationDays'],
    );
  }
  
  /// Check if this event spans the given date
  bool spansDate(DateTime targetDate) {
    final dateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final startDate = DateTime.parse(date);
    final duration = durationDays ?? 1;
    if (duration <= 1) {
      // Single day event - only matches exact date
      return false;
    }
    final endDate = startDate.add(Duration(days: duration - 1));
    return !dateOnly.isBefore(startDate) && !dateOnly.isAfter(endDate);
  }
  
  /// Get day number (1-indexed) for a given date within this event span
  int? getDayNumber(DateTime targetDate) {
    final startDate = DateTime.parse(date);
    final duration = durationDays ?? 1;
    if (duration <= 1) return null;
    
    final dateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    
    final daysDiff = dateOnly.difference(startDate).inDays;
    if (daysDiff >= 0 && daysDiff < duration) {
      return daysDiff + 1; // 1-indexed
    }
    return null;
  }
}

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
        join(dbPath, 'schedule.db'),
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            task TEXT,
            type TEXT,
            remindMe INTEGER,
            remindDaysBefore INTEGER,
            remindTime TEXT,
            repeat TEXT,
            repeatInterval INTEGER,
            durationDays INTEGER
          )
        ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE events ADD COLUMN remindMe INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE events ADD COLUMN remindDaysBefore INTEGER');
            await db.execute('ALTER TABLE events ADD COLUMN remindTime TEXT');
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE events ADD COLUMN repeat TEXT DEFAULT "none"');
            await db.execute('ALTER TABLE events ADD COLUMN repeatInterval INTEGER');
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE events ADD COLUMN durationDays INTEGER');
          }
        }
    );
  }


  static Future<List<Event>> getEventsByDate(String date) async {
    final db = await database;
    final maps = await db.query('events', where: 'date = ?', whereArgs: [date]);
    return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
  }

  static Future<int> insertEvent(Event event) async {
    final db = await database;
    return db.insert('events', event.toMap());
  }

  static Future<int> updateEvent(Event event) async {
    final db = await database;
    return db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  static Future<int> deleteEvent(int id) async {
    final db = await database;
    return db.delete('events', where: 'id = ?', whereArgs: [id]);
  }
}