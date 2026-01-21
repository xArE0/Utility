import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';

class ExportImportsPage extends StatelessWidget {
  final String scheduleDbName = 'schedule.db';
  final String expenseDbName = 'expense_tracker.db';
  final String dataVaultDbName = 'datavault.db';
  final String potTrackerDbName = 'pottracker_session.db';

  const ExportImportsPage({super.key});

  Future<String> _getDbPath(String dbName) async {
    final dir = await getDatabasesPath();
    return '$dir/$dbName';
  }

  Future<void> _exportDb(BuildContext context, String dbName) async {
    final dbPath = await _getDbPath(dbName);
    if (await File(dbPath).exists()) {
      await Share.shareXFiles([XFile(dbPath)], text: 'Database backup: $dbName');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database file not found: $dbName')),
      );
    }
  }

  Future<void> _importDb(BuildContext context, String dbName) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      final dbPath = await _getDbPath(dbName);
      await pickedFile.copy(dbPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database imported and overwritten: $dbName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export & Import Databases')),
      body: ListView(
        children: [
          const Divider(),
          ListTile(
            title: const Text('Export Schedule Database'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _exportDb(context, scheduleDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Schedule Database'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _importDb(context, scheduleDbName),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Export Expense Database'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _exportDb(context, expenseDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Expense Database'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _importDb(context, expenseDbName),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Export Data Vault'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _exportDb(context, dataVaultDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Data Vault'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _importDb(context, dataVaultDbName),
            ),
          ),
          const Divider(),
          // Pot Tracker export/import entries
          ListTile(
            title: const Text('Export Pot Tracker Session'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _exportDb(context, potTrackerDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Pot Tracker Session'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _importDb(context, potTrackerDbName),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}