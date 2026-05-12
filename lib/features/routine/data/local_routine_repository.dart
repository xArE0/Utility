import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/routine_entities.dart';

class LocalRoutineRepository {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'routine.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE habits(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            emoji TEXT NOT NULL DEFAULT '✅',
            sortOrder INTEGER DEFAULT 0,
            scheduledTime TEXT,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE habit_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            habitId INTEGER NOT NULL,
            date TEXT NOT NULL,
            UNIQUE(habitId, date),
            FOREIGN KEY(habitId) REFERENCES habits(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE habits ADD COLUMN scheduledTime TEXT');
        }
      },
    );
  }

  // ── Habits CRUD ──

  Future<List<Habit>> getAllHabits() async {
    if (_db == null) await init();
    final maps = await _db!.query('habits', orderBy: 'sortOrder ASC, id ASC');
    return maps.map((m) => Habit.fromMap(m)).toList();
  }

  Future<int> addHabit(Habit habit) async {
    if (_db == null) await init();
    return await _db!.insert('habits', habit.toMap());
  }

  Future<void> updateHabit(Habit habit) async {
    if (_db == null) await init();
    await _db!.update('habits', habit.toMap(),
        where: 'id = ?', whereArgs: [habit.id]);
  }

  Future<void> deleteHabit(int id) async {
    if (_db == null) await init();
    await _db!.delete('habit_logs', where: 'habitId = ?', whereArgs: [id]);
    await _db!.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // ── Logs ──

  Future<List<HabitLog>> getLogsForDate(String date) async {
    if (_db == null) await init();
    final maps =
        await _db!.query('habit_logs', where: 'date = ?', whereArgs: [date]);
    return maps.map((m) => HabitLog.fromMap(m)).toList();
  }

  Future<List<HabitLog>> getLogsForHabit(int habitId) async {
    if (_db == null) await init();
    final maps = await _db!
        .query('habit_logs', where: 'habitId = ?', whereArgs: [habitId]);
    return maps.map((m) => HabitLog.fromMap(m)).toList();
  }

  Future<List<HabitLog>> getAllLogs() async {
    if (_db == null) await init();
    final maps = await _db!.query('habit_logs');
    return maps.map((m) => HabitLog.fromMap(m)).toList();
  }

  Future<void> toggleLog(int habitId, String date) async {
    if (_db == null) await init();
    final existing = await _db!.query('habit_logs',
        where: 'habitId = ? AND date = ?', whereArgs: [habitId, date]);
    if (existing.isNotEmpty) {
      await _db!.delete('habit_logs',
          where: 'habitId = ? AND date = ?', whereArgs: [habitId, date]);
    } else {
      await _db!.insert(
          'habit_logs', HabitLog(habitId: habitId, date: date).toMap());
    }
  }

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
