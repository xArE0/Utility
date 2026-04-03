import 'package:flutter/material.dart';
import 'export_import_controller.dart';
import '../data/local_export_import_repository.dart';

class ExportImportsPage extends StatefulWidget {
  const ExportImportsPage({super.key});

  @override
  State<ExportImportsPage> createState() => _ExportImportsPageState();
}

class _ExportImportsPageState extends State<ExportImportsPage> {
  late final ExportImportController _controller;

  final String scheduleDbName = 'schedule.db';
  final String expenseDbName = 'expense_tracker.db';
  final String dataVaultDbName = 'datavault.db';
  final String cooldownDbName = 'cooldown.db';

  @override
  void initState() {
    super.initState();
    _controller = ExportImportController(
      repository: LocalExportImportRepository(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              onPressed: () => _controller.exportDatabase(context, scheduleDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Schedule Database'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _controller.importDatabase(context, scheduleDbName),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Export Expense Database'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _controller.exportDatabase(context, expenseDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Expense Database'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _controller.importDatabase(context, expenseDbName),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Export Data Vault'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _controller.exportDatabase(context, dataVaultDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Data Vault'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _controller.importDatabase(context, dataVaultDbName),
            ),
          ),
          const Divider(),

          // Cooldown export/import entries
          ListTile(
            title: const Text('Export Cooldown Database'),
            trailing: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _controller.exportDatabase(context, cooldownDbName),
            ),
          ),
          ListTile(
            title: const Text('Import Cooldown Database'),
            trailing: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _controller.importDatabase(context, cooldownDbName),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}