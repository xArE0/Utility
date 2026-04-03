import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/logbook_entities.dart';
import '../domain/logbook_repository.dart';

class LocalLogbookRepository implements ILogbookRepository {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'logbook.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE log_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            startDate TEXT NOT NULL,
            note TEXT,
            colorHex TEXT DEFAULT '#FF6B35',
            category TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE log_checkpoints(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entryId INTEGER NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY (entryId) REFERENCES log_entries(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  @override
  Future<List<LogEntry>> getAllEntries() async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> entryMaps = await _db!.query('log_entries');
    final entries = <LogEntry>[];

    for (final map in entryMaps) {
      final checkpoints = await getCheckpoints(map['id'] as int);
      entries.add(LogEntry.fromMap(map, checkpoints: checkpoints));
    }

    return entries;
  }

  @override
  Future<int> insertEntry(LogEntry entry) async {
    if (_db == null) await init();
    return await _db!.insert('log_entries', entry.toMap());
  }

  @override
  Future<void> updateEntry(LogEntry entry) async {
    if (_db == null) await init();
    await _db!.update(
      'log_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  @override
  Future<void> deleteEntry(int id) async {
    if (_db == null) await init();
    // Delete checkpoints first
    await _db!.delete('log_checkpoints', where: 'entryId = ?', whereArgs: [id]);
    await _db!.delete('log_entries', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> insertCheckpoint(LogCheckpoint checkpoint) async {
    if (_db == null) await init();
    return await _db!.insert('log_checkpoints', checkpoint.toMap());
  }

  @override
  Future<List<LogCheckpoint>> getCheckpoints(int entryId) async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> maps = await _db!.query(
      'log_checkpoints',
      where: 'entryId = ?',
      whereArgs: [entryId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => LogCheckpoint.fromMap(m)).toList();
  }

  @override
  Future<void> deleteCheckpoint(int id) async {
    if (_db == null) await init();
    await _db!.delete('log_checkpoints', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
