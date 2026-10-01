import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/export_import_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/app_toast.dart';

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
    'routine.db',
  ];

  /// The vault database name.
  static const String vaultDbName = 'datavault.db';

  /// The vault export password; asks the user to choose one (and saves it) if none is set yet.
  Future<String?> _exportPassword(BuildContext context) async {
    final stored = SettingsService.instance.vaultExportPassword;
    if (stored.isNotEmpty) return stored;

    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    final chosen = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Set Export Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The vault in your backup is encrypted with this password. '
                  "You'll need it to restore — it can't be recovered."),
              const SizedBox(height: 12),
              TextField(
                controller: first,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password (min 8 chars)'),
              ),
              TextField(
                controller: second,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Repeat password', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = first.text.trim();
                if (value.length < 8) {
                  setDialogState(() => error = 'At least 8 characters');
                } else if (value != second.text.trim()) {
                  setDialogState(() => error = "Passwords don't match");
                } else {
                  Navigator.of(ctx).pop(value);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return null;
    await SettingsService.instance.updateVaultExportPassword(chosen);
    return chosen;
  }

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
        AppToast.show(context, 'Database file not found: $dbName', isError: true);
      }
      return;
    }

    final success = await _repository.exportDatabase(dbName);
    if (!success && context.mounted) {
      AppToast.show(context, 'Failed to export: $dbName', isError: true);
    }
  }

  Future<void> importDatabase(BuildContext context, String dbName) async {
    final success = await _repository.importDatabase(dbName);
    if (context.mounted) {
      if (success) {
        AppToast.show(context, 'Database imported: $dbName');
      } else {
        AppToast.show(context, 'Failed to import: $dbName', isError: true);
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
        AppToast.show(context, 'Data Vault not found', isError: true);
      }
      return;
    }

    if (!context.mounted) return;
    final password = await _exportPassword(context);
    if (password == null || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _repository.exportEncryptedVault(dbName, password);

    if (context.mounted) {
      Navigator.of(context).pop();
      if (!success) {
        AppToast.show(context, 'Failed to export Data Vault', isError: true);
      }
    }
  }

  /// Imports and decrypts a .vault file — prompts the user for the password.
  Future<void> importEncryptedVault(BuildContext context, String dbName) async {
    if (!context.mounted) return;

    final password = await _askVaultPassword(context);
    if (password == null || password.isEmpty) return;

    // Pick file BEFORE showing the loading dialog to avoid InheritedWidget crash
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty || result.single.path == null) return;
    final filePath = result.single.path!;

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
      AppToast.show(
        context,
        success
            ? 'Data Vault imported! Restart to see changes.'
            : 'Failed to import. Wrong password or corrupted file.',
        isError: !success,
      );
    }
  }

  // ─────────────────────────────────────────────
  //  Bulk export / import ALL databases
  // ─────────────────────────────────────────────

  /// Exports all databases as a single .zip file using the stored vault password.
  Future<void> exportAll(BuildContext context) async {
    if (!context.mounted) return;
    final password = await _exportPassword(context);
    if (password == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success =
        await _repository.exportAllDatabases(plainDbNames, vaultDbName, password);

    if (context.mounted) {
      Navigator.of(context).pop();
      if (!success) {
        AppToast.show(context, 'Failed to export all databases', isError: true);
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty || result.single.path == null) return;
    final filePath = result.single.path!;

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
      AppToast.show(
        context,
        success
            ? 'All databases restored! Restart to see changes.'
            : 'Failed to restore. Wrong password or corrupted backup.',
        isError: !success,
      );
    }
  }
}
