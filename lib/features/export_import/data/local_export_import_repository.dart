import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import '../domain/export_import_repository.dart';
import '../../../core/services/vault_crypto_service.dart';

class LocalExportImportRepository implements IExportImportRepository {
  final VaultCryptoService _crypto = VaultCryptoService.instance;

  Future<String> _getDbPath(String dbName) async {
    final dir = await getDatabasesPath();
    return '$dir/$dbName';
  }

  @override
  Future<bool> checkDatabaseExists(String dbName) async {
    final dbPath = await _getDbPath(dbName);
    return File(dbPath).exists();
  }

  @override
  Future<bool> exportDatabase(String dbName) async {
    try {
      final dbPath = await _getDbPath(dbName);
      if (await File(dbPath).exists()) {
        await Share.shareXFiles([XFile(dbPath)], text: 'Database backup: $dbName');
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> importDatabase(String dbName) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final dbPath = await _getDbPath(dbName);
        await pickedFile.copy(dbPath);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  //  Encrypted vault export / import
  // ─────────────────────────────────────────────

  @override
  Future<bool> exportEncryptedVault(String dbName, String password) async {
    try {
      final dbPath = await _getDbPath(dbName);
      if (!await File(dbPath).exists()) return false;

      // Open the encrypted vault DB to read all items as plaintext
      final dbPassword = await _crypto.getOrCreateDbPassword();
      final db = await cipher.openDatabase(dbPath, password: dbPassword);
      final rows = await db.query('vault');
      await db.close();

      // Serialize to JSON
      final jsonData = jsonEncode(rows);

      // AES-GCM encrypt with the user's export password
      final encryptedFile = await _crypto.encryptVaultExport(jsonData, password);

      await Share.shareXFiles(
        [XFile(encryptedFile.path)],
        text: 'Encrypted Data Vault backup (.vault)',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> importEncryptedVault(String dbName, String password) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return false;

      final pickedFile = File(result.files.single.path!);

      // Decrypt the .vault file → JSON string
      final jsonData = await _crypto.decryptVaultImport(pickedFile, password);
      final List<dynamic> rows = jsonDecode(jsonData);

      // Open (or create) the encrypted vault DB
      final dbPath = await _getDbPath(dbName);
      final dbPassword = await _crypto.getOrCreateDbPassword();
      final db = await cipher.openDatabase(
        dbPath,
        password: dbPassword,
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

      // Clear existing data and insert imported rows
      await db.delete('vault');
      for (final row in rows) {
        await db.insert('vault', {
          'label': row['label'] ?? '',
          'value': row['value'] ?? '',
          'category': row['category'] ?? 'Passwords',
        });
      }
      await db.close();

      return true;
    } catch (e) {
      return false;
    }
  }
}
