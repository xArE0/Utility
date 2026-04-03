import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/vault_entities.dart';
import '../domain/vault_repository.dart';

class LocalVaultRepository implements IVaultRepository {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'datavault.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vault(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT,
            value TEXT,
            category TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1 && newVersion == 2) {
          await db.execute("ALTER TABLE vault ADD COLUMN category TEXT");
        }
      },
    );
  }

  @override
  Future<List<VaultItem>> getAllItems() async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> maps = await _db!.query('vault');
    return maps.map((m) => VaultItem.fromMap(m)).toList();
  }

  @override
  Future<void> addItem(VaultItem item) async {
    if (_db == null) await init();
    await _db!.insert('vault', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteItem(int id) async {
    if (_db == null) await init();
    await _db!.delete('vault', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateItem(VaultItem item) async {
    if (_db == null) await init();
    await _db!.update(
      'vault',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
