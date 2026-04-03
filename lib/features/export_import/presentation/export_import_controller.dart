import 'package:flutter/material.dart';
import '../domain/export_import_repository.dart';

class ExportImportController extends ChangeNotifier {
  final IExportImportRepository _repository;

  ExportImportController({required IExportImportRepository repository})
      : _repository = repository;

  Future<void> exportDatabase(BuildContext context, String dbName) async {
    final exists = await _repository.checkDatabaseExists(dbName);
    if (!exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database file not found: $dbName')),
        );
      }
      return;
    }

    final success = await _repository.exportDatabase(dbName);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export database: $dbName')),
      );
    }
  }

  Future<void> importDatabase(BuildContext context, String dbName) async {
    final success = await _repository.importDatabase(dbName);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database imported and overwritten: $dbName')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import database or cancelled: $dbName')),
        );
      }
    }
  }
}
