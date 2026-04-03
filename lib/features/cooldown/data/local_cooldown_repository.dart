import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/cooldown_entities.dart';
import '../domain/cooldown_repository.dart';

class LocalCooldownRepository implements ICooldownRepository {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'cooldown.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cooldowns(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cooldownEnd TEXT,
            createdAt TEXT NOT NULL,
            colorIndex INTEGER DEFAULT 0,
            category TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE cooldowns ADD COLUMN category TEXT');
        }
      },
    );
  }

  @override
  Future<List<CooldownItem>> getAllItems() async {
    if (_db == null) await init();
    final maps = await _db!.query('cooldowns', orderBy: 'createdAt DESC');
    return maps.map((m) => CooldownItem.fromMap(m)).toList();
  }

  @override
  Future<void> addItem(CooldownItem item) async {
    if (_db == null) await init();
    await _db!.insert('cooldowns', item.toMap());
  }

  @override
  Future<void> updateItem(CooldownItem item) async {
    if (_db == null) await init();
    await _db!.update(
      'cooldowns',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> deleteItem(int id) async {
    if (_db == null) await init();
    await _db!.delete('cooldowns', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
