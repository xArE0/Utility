import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/export_import_repository.dart';
import '../../../core/services/settings_service.dart';

class ExportImportController extends ChangeNotifier {
  final IExportImportRepository _repository;

  ExportImportController({required IExportImportRepository repository})
      : _repository = repository;

  /// All plain (unencrypted) database names.
  static const List<String> plainDbNames = [
    'schedule.db',
    'expense_tracker.db',
    'cooldown.db',
    'logbook.db',
  ];

  /// The vault database name.
  static const String vaultDbName = 'datavault.db';

  /// Gets the vault export password from settings (default: super123).
  String get _vaultPassword => SettingsService.instance.vaultExportPassword;

  /// Shows a dialog prompting the user to enter the vault password for import.
  Future<String?> _askVaultPassword(BuildContext context) async {
    final controller = TextEditingController();
    bool obscure = true;
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Vault Password'),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter vault password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Decrypt'),
            ),
          ],
        ),
      ),
    );
    return password;
  }

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

  // ─────────────────────────────────────────────
  //  Encrypted vault export / import
  // ─────────────────────────────────────────────

  /// Exports the vault as an encrypted .vault file using the stored password.
  Future<void> exportEncryptedVault(BuildContext context, String dbName) async {
    final exists = await _repository.checkDatabaseExists(dbName);
    if (!exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data Vault not found. Add some entries first.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _repository.exportEncryptedVault(dbName, _vaultPassword);

    if (context.mounted) {
      Navigator.of(context).pop();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export Data Vault.')),
        );
      }
    }
  }

  /// Imports and decrypts a .vault file — prompts the user for the password.
  Future<void> importEncryptedVault(BuildContext context, String dbName) async {
    if (!context.mounted) return;

    final password = await _askVaultPassword(context);
    if (password == null || password.isEmpty) return;

    // Pick file BEFORE showing the loading dialog to avoid InheritedWidget crash
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool success = false;
    try {
      success = await _repository.importEncryptedVaultFromPath(
          filePath, dbName, password);
    } catch (e) {
      debugPrint('Import vault error: $e');
      success = false;
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Data Vault imported successfully! Restart the app to see changes.'
                : 'Failed to import. Wrong password or corrupted file.',
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  //  Bulk export / import ALL databases
  // ─────────────────────────────────────────────

  /// Exports all databases as a single .zip file using the stored vault password.
  Future<void> exportAll(BuildContext context) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success =
        await _repository.exportAllDatabases(plainDbNames, vaultDbName, _vaultPassword);

    if (context.mounted) {
      Navigator.of(context).pop();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export all databases.')),
        );
      }
    }
  }

  /// Imports all databases from a single .zip file — prompts for vault password.
  Future<void> importAll(BuildContext context) async {
    if (!context.mounted) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore All Databases?'),
        content: const Text(
          'This will overwrite ALL existing data (schedules, expenses, '
          'logbook, cooldowns, and your Data Vault) with the backup.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Overwrite All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Ask for vault password
    if (!context.mounted) return;
    final password = await _askVaultPassword(context);
    if (password == null || password.isEmpty) return;

    // Pick file BEFORE showing the loading dialog
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool success = false;
    try {
      success = await _repository.importAllDatabasesFromPath(
          filePath, plainDbNames, vaultDbName, password);
    } catch (_) {
      success = false;
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'All databases restored! Restart the app to see changes.'
                : 'Failed to restore. Wrong vault password or corrupted backup.',
          ),
        ),
      );
    }
  }
}
