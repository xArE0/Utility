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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cooldowns(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cooldownEnd TEXT,
            createdAt TEXT NOT NULL,
            colorIndex INTEGER DEFAULT 0,
            category TEXT,
            categoryId INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE cooldown_categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            cooldownDurationMinutes INTEGER NOT NULL,
            colorIndex INTEGER DEFAULT 0,
            iconCodePoint INTEGER DEFAULT 58055,
            createdAt TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE cooldowns ADD COLUMN category TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE cooldowns ADD COLUMN categoryId INTEGER');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cooldown_categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              cooldownDurationMinutes INTEGER NOT NULL,
              colorIndex INTEGER DEFAULT 0,
              iconCodePoint INTEGER DEFAULT 58055,
              createdAt TEXT NOT NULL
            )
          ''');
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
  Future<List<CooldownCategory>> getAllCategories() async {
    if (_db == null) await init();
    final maps = await _db!.query('cooldown_categories', orderBy: 'createdAt ASC');
    return maps.map((m) => CooldownCategory.fromMap(m)).toList();
  }

  @override
  Future<CooldownCategory> addCategory(CooldownCategory category) async {
    if (_db == null) await init();
    final id = await _db!.insert('cooldown_categories', category.toMap());
    return category.copyWith(id: id);
  }

  @override
  Future<void> updateCategory(CooldownCategory category) async {
    if (_db == null) await init();
    await _db!.update(
      'cooldown_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> deleteCategory(int id) async {
    if (_db == null) await init();
    // Clear categoryId on items that reference this category
    await _db!.update(
      'cooldowns',
      {'categoryId': null},
      where: 'categoryId = ?',
      whereArgs: [id],
    );
    await _db!.delete('cooldown_categories', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
