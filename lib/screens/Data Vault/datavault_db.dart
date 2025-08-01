import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DataVaultDB {
  static final DataVaultDB _instance = DataVaultDB._internal();
  factory DataVaultDB() => _instance;
  DataVaultDB._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'datavault.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vault(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT,
            value TEXT
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    return await db.query('vault');
  }

  Future<void> addItem(String label, String value) async {
    final db = await database;
    await db.insert('vault', {'label': label, 'value': value});
  }
}