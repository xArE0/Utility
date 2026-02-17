import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'cooldown_item.dart';

class CooldownDB {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'cooldown.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cooldowns(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cooldownEnd TEXT,
            createdAt TEXT NOT NULL,
            colorIndex INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  static Future<List<CooldownItem>> getAll() async {
    final db = await database;
    final maps = await db.query('cooldowns', orderBy: 'createdAt DESC');
    return maps.map((m) => CooldownItem.fromMap(m)).toList();
  }

  static Future<int> insert(CooldownItem item) async {
    final db = await database;
    return db.insert('cooldowns', item.toMap());
  }

  static Future<int> update(CooldownItem item) async {
    final db = await database;
    return db.update(
      'cooldowns',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  static Future<int> delete(int id) async {
    final db = await database;
    return db.delete('cooldowns', where: 'id = ?', whereArgs: [id]);
  }
}
