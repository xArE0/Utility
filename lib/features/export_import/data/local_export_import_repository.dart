import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/export_import_repository.dart';

class LocalExportImportRepository implements IExportImportRepository {
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
}
