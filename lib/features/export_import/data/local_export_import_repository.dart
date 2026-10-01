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

  /// Every SQLite database file starts with this header.
  static const _sqliteHeader = 'SQLite format 3\u0000';

  static bool _isSqlite(List<int> bytes) =>
      bytes.length >= 100 && String.fromCharCodes(bytes.take(16)) == _sqliteHeader;

  /// Plain copies of earlier exports stay in the cache until the share target has read them;
  /// remove them before writing new ones so they don't pile up.
  Future<void> _clearOldExports() async {
    try {
      final tempDir = await getTemporaryDirectory();
      await for (final f in tempDir.list()) {
        final name = f.uri.pathSegments.last;
        if (f is File &&
            (name.contains('_backup_') || name == 'temp_import.vault') &&
            (name.endsWith('.db') || name.endsWith('.vault') || name.endsWith('.zip'))) {
          await f.delete();
        }
      }
    } catch (_) {}
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
        await _clearOldExports();
        final tempDir = await getTemporaryDirectory();
        final now = DateTime.now();
        final dateStr =
            '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
        final baseName = dbName.replaceAll('.db', '');
        final tempFile = File('${tempDir.path}/${baseName}_backup_$dateStr.db');
        await File(dbPath).copy(tempFile.path);

        await Share.shareXFiles([XFile(tempFile.path)],
            text: 'Database backup: $dbName');
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
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isNotEmpty && result.single.path != null) {
        final pickedFile = File(result.single.path!);
        // Refuse anything that isn't a database rather than overwrite data with it.
        if (!_isSqlite(await pickedFile.openRead(0, 100).expand((b) => b).toList())) {
          return false;
        }
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

      // Also export vault_custom_fields
      List<Map<String, dynamic>> customFieldRows = [];
      try {
        customFieldRows = await db.query('vault_custom_fields');
      } catch (_) {
        // Table might not exist in older DBs — that's fine
      }
      await db.close();

      // Serialize both tables into a structured JSON
      final exportData = {
        'vault': vaultRows,
        'vault_history': historyRows,
        'vault_custom_fields': customFieldRows,
      };
      final jsonData = jsonEncode(exportData);

      // AES-GCM encrypt with the user's export password
      await _clearOldExports();
      final encryptedFile =
          await _crypto.encryptVaultExport(jsonData, password);

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
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty || result.single.path == null) return false;

      final pickedFile = File(result.single.path!);
      return await _importVaultFromFile(pickedFile, dbName, password);
    } catch (e) {
      return false;
    }
  }

  /// Shared logic for importing a decrypted vault file.
  /// Supports both old format (plain List) and new format (Map with vault + vault_history).
  Future<bool> _importVaultFromFile(
      File vaultFile, String dbName, String password) async {
    try {
      // Decrypt the .vault file → JSON string
      final jsonData = await _crypto.decryptVaultImport(vaultFile, password);
      final decoded = jsonDecode(jsonData);

      List<dynamic> vaultRows;
      List<dynamic> historyRows = [];
      List<dynamic> customFieldRows = [];

      // Support both old format (plain list) and new format (map)
      if (decoded is List) {
        // Old format: just vault entries
        vaultRows = decoded;
      } else if (decoded is Map) {
        vaultRows = (decoded['vault'] as List?) ?? [];
        historyRows = (decoded['vault_history'] as List?) ?? [];
        customFieldRows = (decoded['vault_custom_fields'] as List?) ?? [];
      } else {
        return false;
      }

      // Delete the existing DB file first to avoid version-downgrade errors.
      // We're replacing all data anyway, so a clean slate is safest.
      final dbPath = await _getDbPath(dbName);
      final existingFile = File(dbPath);
      if (await existingFile.exists()) await existingFile.delete();
      // Also clean up journal/WAL files
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final f = File('$dbPath$suffix');
        if (await f.exists()) await f.delete();
      }

      // Create a fresh encrypted vault DB at version 6 (matches LocalVaultRepository)
      final dbPassword = await _crypto.getOrCreateDbPassword();
      final db = await cipher.openDatabase(
        dbPath,
        password: dbPassword,
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE vault(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              label TEXT,
              value TEXT,
              category TEXT,
              tags TEXT,
              username TEXT,
              website TEXT,
              note TEXT
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
          await db.execute('''
            CREATE TABLE vault_custom_fields(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              vault_item_id INTEGER,
              field_name TEXT,
              field_value TEXT
            )
          ''');
        },
      );

      // We need to track old→new ID mapping so history/custom-field references remain correct
      final Map<int, int> idMapping = {};

      for (final row in vaultRows) {
        final oldId = row['id'] as int?;
        final newId = await db.insert('vault', {
          'label': row['label'] ?? '',
          'value': row['value'] ?? '',
          'category': row['category'] ?? 'Passwords',
          'tags': row['tags'] ?? '',
          'username': row['username'] ?? '',
          'website': row['website'] ?? '',
          'note': row['note'] ?? '',
        });
        if (oldId != null) {
          idMapping[oldId] = newId;
        }
      }

      // Restore history with corrected vault_item_id references
      for (final row in historyRows) {
        final oldVaultItemId = row['vault_item_id'] as int?;
        final newVaultItemId = oldVaultItemId != null
            ? (idMapping[oldVaultItemId] ?? oldVaultItemId)
            : 0;
        await db.insert('vault_history', {
          'vault_item_id': newVaultItemId,
          'old_value': row['old_value'] ?? '',
          'changed_at': row['changed_at'] ?? '',
        });
      }

      // Restore custom fields with corrected vault_item_id references
      for (final row in customFieldRows) {
        final oldVaultItemId = row['vault_item_id'] as int?;
        final newVaultItemId = oldVaultItemId != null
            ? (idMapping[oldVaultItemId] ?? oldVaultItemId)
            : 0;
        await db.insert('vault_custom_fields', {
          'vault_item_id': newVaultItemId,
          'field_name': row['field_name'] ?? '',
          'field_value': row['field_value'] ?? '',
        });
      }

      await db.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  //  Bulk export / import ALL databases
  // ─────────────────────────────────────────────

  @override
  Future<bool> exportAllDatabases(List<String> plainDbNames, String vaultDbName,
      String vaultPassword) async {
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

        List<Map<String, dynamic>> customFieldRows = [];
        try {
          customFieldRows = await db.query('vault_custom_fields');
        } catch (_) {}
        await db.close();

        final exportData = {
          'vault': vaultRows,
          'vault_history': historyRows,
          'vault_custom_fields': customFieldRows,
        };
        final jsonData = jsonEncode(exportData);

        // Encrypt the vault JSON
        final plainBytes = utf8.encode(jsonData);
        final encryptedBytes = await _crypto.encryptBytes(
            Uint8List.fromList(plainBytes), vaultPassword);

        archive.addFile(ArchiveFile(
            'datavault_backup.vault', encryptedBytes.length, encryptedBytes));
      }

      // 3. Encode as ZIP and share
      final zipBytes = ZipEncoder().encode(archive);
      await _clearOldExports();

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr =
          '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
      final zipFile = File('${tempDir.path}/utility_full_backup_$dateStr.zip');
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
  Future<bool> importAllDatabases(List<String> plainDbNames, String vaultDbName,
      String vaultPassword) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty || result.single.path == null) return false;
      return await importAllDatabasesFromPath(
          result.single.path!, plainDbNames, vaultDbName, vaultPassword);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> importEncryptedVaultFromPath(
      String filePath, String dbName, String password) async {
    try {
      final pickedFile = File(filePath);
      return await _importVaultFromFile(pickedFile, dbName, password);
    } catch (e) {
      return false;
    }
  }

  /// Restores everything in the archive, but only after checking all of it: each database must be
  /// a real SQLite file and the vault must decrypt with [vaultPassword]. A wrong password or a bad
  /// file leaves the current data untouched instead of half-restored.
  @override
  Future<bool> importAllDatabasesFromPath(
      String filePath,
      List<String> plainDbNames,
      String vaultDbName,
      String vaultPassword) async {
    try {
      final pickedFile = File(filePath);
      final bytes = await pickedFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Check everything first.
      final plainFiles = <String, List<int>>{};
      for (final dbName in plainDbNames) {
        final archiveFile = archive.findFile(dbName);
        if (archiveFile == null) continue;
        final content = archiveFile.content as List<int>;
        if (!_isSqlite(content)) return false;
        plainFiles[dbName] = content;
      }
      final vaultArchiveFile = archive.findFile('datavault_backup.vault');
      List<int>? vaultBytes;
      if (vaultArchiveFile != null) {
        vaultBytes = vaultArchiveFile.content as List<int>;
        // Throws on a wrong password or tampered data (AES-GCM is authenticated).
        await _crypto.decryptBytes(Uint8List.fromList(vaultBytes), vaultPassword);
      }
      if (plainFiles.isEmpty && vaultBytes == null) return false;

      // 2. Restore the encrypted vault (the step that can still fail).
      if (vaultBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempVaultFile = File('${tempDir.path}/temp_import.vault');
        await tempVaultFile.writeAsBytes(vaultBytes, flush: true);
        final vaultImported = await _importVaultFromFile(
            tempVaultFile, vaultDbName, vaultPassword);
        if (await tempVaultFile.exists()) await tempVaultFile.delete();
        if (!vaultImported) return false;
      }

      // 3. Restore plain DB files
      for (final entry in plainFiles.entries) {
        final dbPath = await _getDbPath(entry.key);
        await File(dbPath).writeAsBytes(entry.value, flush: true);
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
