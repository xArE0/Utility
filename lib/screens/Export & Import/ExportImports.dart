import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';

class ExportImportsPage extends StatelessWidget {
  // Replace with your actual DB file names
  final String scheduleDbName = 'schedule.db';
  final String expenseDbName = 'expense_tracker.db';

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
              icon: const Icon(Icons.file_upload),
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
              icon: const Icon(Icons.file_upload),
              onPressed: () => _importDb(context, expenseDbName),
            ),
          ),
        ],
      ),
    );
  }
}