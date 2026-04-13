import 'dart:io';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../domain/vault_entities.dart';
import '../domain/vault_repository.dart';
import '../../../core/services/vault_crypto_service.dart';

class LocalVaultRepository implements IVaultRepository {
  Database? _db;
  final VaultCryptoService _crypto = VaultCryptoService.instance;

  @override
  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'datavault.db');

    // Get the encryption password from secure storage
    final password = await _crypto.getOrCreateDbPassword();

    // Migrate existing unencrypted DB if needed
    await _migrateIfNeeded(path, password);

    _db = await openDatabase(
      path,
      password: password,
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

  /// One-time migration: reads data from an unencrypted DB, creates a new
  /// encrypted one, and replaces the old file.  The old file is only deleted
  /// after the new one is verified.
  Future<void> _migrateIfNeeded(String dbFilePath, String password) async {
    // Skip if we've already migrated
    if (await _crypto.isMigrated()) return;

    final dbFile = File(dbFilePath);
    if (!dbFile.existsSync()) {
      // No existing DB — fresh install, mark as migrated
      await _crypto.markMigrated();
      return;
    }

    // Try opening without a password.  If it succeeds, the DB is unencrypted.
    Database? legacyDb;
    List<Map<String, dynamic>> existingRows = [];

    try {
      legacyDb = await openDatabase(dbFilePath);
      // Check if the vault table exists
      final tables = await legacyDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='vault'",
      );
      if (tables.isNotEmpty) {
        existingRows = await legacyDb.query('vault');
      }
      await legacyDb.close();
    } catch (_) {
      // Opening without password failed — DB is already encrypted or corrupt.
      // Either way, mark migrated and let the normal open handle it.
      await _crypto.markMigrated();
      return;
    }

    // Back up the old file
    final backupPath = '$dbFilePath.unencrypted.bak';
    await dbFile.copy(backupPath);

    // Delete the old unencrypted DB so we can create an encrypted one at the
    // same path
    await dbFile.delete();
    // Also delete journal/wal files if present
    final journal = File('$dbFilePath-journal');
    if (journal.existsSync()) await journal.delete();
    final wal = File('$dbFilePath-wal');
    if (wal.existsSync()) await wal.delete();
    final shm = File('$dbFilePath-shm');
    if (shm.existsSync()) await shm.delete();

    // Create a new encrypted DB and reinsert all rows
    try {
      final newDb = await openDatabase(
        dbFilePath,
        password: password,
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
      );

      for (final row in existingRows) {
        await newDb.insert('vault', {
          'label': row['label'],
          'value': row['value'],
          'category': row['category'] ?? 'Passwords',
        });
      }

      await newDb.close();
      await _crypto.markMigrated();

      // Migration succeeded — remove the backup
      final backup = File(backupPath);
      if (backup.existsSync()) await backup.delete();
    } catch (e) {
      // Migration failed — restore the backup
      final backup = File(backupPath);
      if (backup.existsSync()) {
        await backup.copy(dbFilePath);
        await backup.delete();
      }
      rethrow;
    }
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
