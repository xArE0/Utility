import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
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
      final vaultRows = await db.query('vault');

      // Also export vault_history
      List<Map<String, dynamic>> historyRows = [];
      try {
        historyRows = await db.query('vault_history');
      } catch (_) {
        // Table might not exist in older DBs — that's fine
      }
      await db.close();

      // Serialize both tables into a structured JSON
      final exportData = {
        'vault': vaultRows,
        'vault_history': historyRows,
      };
      final jsonData = jsonEncode(exportData);

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
      return await _importVaultFromFile(pickedFile, dbName, password);
    } catch (e) {
      return false;
    }
  }

  /// Shared logic for importing a decrypted vault file.
  /// Supports both old format (plain List) and new format (Map with vault + vault_history).
  Future<bool> _importVaultFromFile(
      File vaultFile, String dbName, String password) async {
    // Decrypt the .vault file → JSON string
    final jsonData = await _crypto.decryptVaultImport(vaultFile, password);
    final decoded = jsonDecode(jsonData);

    List<dynamic> vaultRows;
    List<dynamic> historyRows = [];

    // Support both old format (plain list) and new format (map)
    if (decoded is List) {
      // Old format: just vault entries
      vaultRows = decoded;
    } else if (decoded is Map) {
      vaultRows = (decoded['vault'] as List?) ?? [];
      historyRows = (decoded['vault_history'] as List?) ?? [];
    } else {
      return false;
    }

    // Open (or create) the encrypted vault DB
    final dbPath = await _getDbPath(dbName);
    final dbPassword = await _crypto.getOrCreateDbPassword();
    final db = await cipher.openDatabase(
      dbPath,
      password: dbPassword,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vault(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT,
            value TEXT,
            category TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE vault_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vault_item_id INTEGER,
            old_value TEXT,
            changed_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE vault ADD COLUMN category TEXT");
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS vault_history(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              vault_item_id INTEGER,
              old_value TEXT,
              changed_at TEXT
            )
          ''');
        }
      },
    );

    // Clear existing data and insert imported rows
    await db.delete('vault');
    try {
      await db.delete('vault_history');
    } catch (_) {}

    // We need to track old→new ID mapping so history references remain correct
    final Map<int, int> idMapping = {};

    for (final row in vaultRows) {
      final oldId = row['id'] as int?;
      final newId = await db.insert('vault', {
        'label': row['label'] ?? '',
        'value': row['value'] ?? '',
        'category': row['category'] ?? 'Passwords',
      });
      if (oldId != null) {
        idMapping[oldId] = newId;
      }
    }

    // Restore history with corrected vault_item_id references
    for (final row in historyRows) {
      final oldVaultItemId = row['vault_item_id'] as int?;
      final newVaultItemId =
          oldVaultItemId != null ? (idMapping[oldVaultItemId] ?? oldVaultItemId) : 0;
      await db.insert('vault_history', {
        'vault_item_id': newVaultItemId,
        'old_value': row['old_value'] ?? '',
        'changed_at': row['changed_at'] ?? '',
      });
    }

    await db.close();
    return true;
  }

  // ─────────────────────────────────────────────
  //  Bulk export / import ALL databases
  // ─────────────────────────────────────────────

  @override
  Future<bool> exportAllDatabases(
      List<String> plainDbNames, String vaultDbName, String vaultPassword) async {
    try {
      final archive = Archive();

      // 1. Add all plain DB files to the archive
      for (final dbName in plainDbNames) {
        final dbPath = await _getDbPath(dbName);
        final file = File(dbPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(dbName, bytes.length, bytes));
        }
      }

      // 2. Add the vault as an encrypted .vault file
      final vaultDbPath = await _getDbPath(vaultDbName);
      if (await File(vaultDbPath).exists()) {
        final dbPassword = await _crypto.getOrCreateDbPassword();
        final db = await cipher.openDatabase(vaultDbPath, password: dbPassword);
        final vaultRows = await db.query('vault');

        List<Map<String, dynamic>> historyRows = [];
        try {
          historyRows = await db.query('vault_history');
        } catch (_) {}
        await db.close();

        final exportData = {
          'vault': vaultRows,
          'vault_history': historyRows,
        };
        final jsonData = jsonEncode(exportData);

        // Encrypt the vault JSON
        final plainBytes = utf8.encode(jsonData);
        final encryptedBytes =
            await _crypto.encryptBytes(Uint8List.fromList(plainBytes), vaultPassword);

        archive.addFile(
            ArchiveFile('datavault_backup.vault', encryptedBytes.length, encryptedBytes));
      }

      // 3. Encode as ZIP and share
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) return false;

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/utility_full_backup.zip');
      await zipFile.writeAsBytes(zipBytes, flush: true);

      await Share.shareXFiles(
        [XFile(zipFile.path)],
        text: 'Full Utility backup (.zip)',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> importAllDatabases(
      List<String> plainDbNames, String vaultDbName, String vaultPassword) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return false;

      final pickedFile = File(result.files.single.path!);
      final bytes = await pickedFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Restore plain DB files
      for (final dbName in plainDbNames) {
        final archiveFile = archive.findFile(dbName);
        if (archiveFile != null) {
          final dbPath = await _getDbPath(dbName);
          final outFile = File(dbPath);
          await outFile.writeAsBytes(archiveFile.content as List<int>, flush: true);
        }
      }

      // 2. Restore the encrypted vault
      final vaultArchiveFile = archive.findFile('datavault_backup.vault');
      if (vaultArchiveFile != null) {
        // Write the encrypted vault to a temp file, then use the shared import logic
        final tempDir = await getTemporaryDirectory();
        final tempVaultFile = File('${tempDir.path}/temp_import.vault');
        await tempVaultFile.writeAsBytes(
            vaultArchiveFile.content as List<int>,
            flush: true);

        final vaultImported =
            await _importVaultFromFile(tempVaultFile, vaultDbName, vaultPassword);
        // Clean up temp file
        if (await tempVaultFile.exists()) await tempVaultFile.delete();

        if (!vaultImported) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
