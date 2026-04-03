import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/schedule_entities.dart';
import '../domain/schedule_repository.dart';

class LocalScheduleRepository implements IScheduleRepository {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'schedule.db'),
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            task TEXT,
            type TEXT,
            remindMe INTEGER DEFAULT 0,
            remindDaysBefore INTEGER,
            remindTime TEXT,
            repeat TEXT DEFAULT 'none',
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
      },
    );
  }

  @override
  Future<List<Event>> getAllEvents() async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> maps = await _db!.query('events');
    return maps.map((m) => Event.fromMap(m)).toList();
  }

  @override
  Future<int> insertEvent(Event event) async {
    if (_db == null) await init();
    return await _db!.insert('events', event.toMap());
  }

  @override
  Future<void> updateEvent(Event event) async {
    if (_db == null) await init();
    await _db!.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  @override
  Future<void> deleteEvent(int id) async {
    if (_db == null) await init();
    await _db!.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
