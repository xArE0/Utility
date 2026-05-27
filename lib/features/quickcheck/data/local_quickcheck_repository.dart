import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/quickcheck_entities.dart';
import '../domain/quickcheck_repository.dart';

class LocalQuickCheckRepository implements IQuickCheckRepository {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'quickcheck.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE qc_answer_keys(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pageNumber INTEGER UNIQUE,
            name TEXT DEFAULT '',
            answers TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE qc_attempts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pageNumber INTEGER,
            questionIndex INTEGER,
            userAnswer TEXT,
            correctAnswer TEXT,
            isCorrect INTEGER,
            attemptedAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE qc_answer_keys ADD COLUMN name TEXT DEFAULT ''");
        }
      },
    );
  }

  // ── Answer Keys ──────────────────────────────────────────────────────

  @override
  Future<List<AnswerKey>> getAllAnswerKeys() async {
    if (_db == null) await init();
    final maps = await _db!.query('qc_answer_keys', orderBy: 'pageNumber ASC');
    return maps.map((m) => AnswerKey.fromMap(m)).toList();
  }

  @override
  Future<AnswerKey?> getAnswerKeyForPage(int pageNumber) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'qc_answer_keys',
      where: 'pageNumber = ?',
      whereArgs: [pageNumber],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AnswerKey.fromMap(maps.first);
  }

  @override
  Future<void> upsertAnswerKey(AnswerKey key) async {
    if (_db == null) await init();
    await _db!.insert(
      'qc_answer_keys',
      key.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAnswerKey(int pageNumber) async {
    if (_db == null) await init();
    await _db!.delete(
      'qc_answer_keys',
      where: 'pageNumber = ?',
      whereArgs: [pageNumber],
    );
  }

  @override
  Future<void> deleteAllAnswerKeys() async {
    if (_db == null) await init();
    await _db!.delete('qc_answer_keys');
  }

  // ── Attempts ─────────────────────────────────────────────────────────

  @override
  Future<List<AttemptRecord>> getAttemptsForPage(int pageNumber) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'qc_attempts',
      where: 'pageNumber = ?',
      whereArgs: [pageNumber],
      orderBy: 'attemptedAt ASC',
    );
    return maps.map((m) => AttemptRecord.fromMap(m)).toList();
  }

  @override
  Future<List<AttemptRecord>> getWrongAttemptsForPage(int pageNumber) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'qc_attempts',
      where: 'pageNumber = ? AND isCorrect = 0',
      whereArgs: [pageNumber],
      orderBy: 'attemptedAt ASC',
    );
    return maps.map((m) => AttemptRecord.fromMap(m)).toList();
  }

  @override
  Future<List<AttemptRecord>> getAllAttempts() async {
    if (_db == null) await init();
    final maps = await _db!.query('qc_attempts', orderBy: 'attemptedAt ASC');
    return maps.map((m) => AttemptRecord.fromMap(m)).toList();
  }

  @override
  Future<void> addAttempt(AttemptRecord record) async {
    if (_db == null) await init();
    await _db!.insert('qc_attempts', record.toMap());
  }

  @override
  Future<void> clearAttemptsForPage(int pageNumber) async {
    if (_db == null) await init();
    await _db!.delete(
      'qc_attempts',
      where: 'pageNumber = ?',
      whereArgs: [pageNumber],
    );
  }

  @override
  Future<void> clearAttemptForQuestion(int pageNumber, int questionIndex) async {
    if (_db == null) await init();
    await _db!.delete(
      'qc_attempts',
      where: 'pageNumber = ? AND questionIndex = ?',
      whereArgs: [pageNumber, questionIndex],
    );
  }

  @override
  Future<void> clearAllAttempts() async {
    if (_db == null) await init();
    await _db!.delete('qc_attempts');
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
