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

  // ─────────────────────────────────────────────
  //  Encrypted vault export / import
  // ─────────────────────────────────────────────

  /// Shows a password dialog, then exports the vault as an encrypted .vault file.
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
    final password = await _showPasswordDialog(
      context,
      title: 'Encrypt Vault Export',
      hint: 'Choose a strong password',
      confirmMode: true,
    );
    if (password == null || password.isEmpty) return;

    if (!context.mounted) return;
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _repository.exportEncryptedVault(dbName, password);

    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss loading
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export Data Vault.')),
        );
      }
    }
  }

  /// Shows a password dialog, then imports and decrypts a .vault file.
  Future<void> importEncryptedVault(BuildContext context, String dbName) async {
    if (!context.mounted) return;
    final password = await _showPasswordDialog(
      context,
      title: 'Decrypt Vault Import',
      hint: 'Enter the export password',
      confirmMode: false,
    );
    if (password == null || password.isEmpty) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _repository.importEncryptedVault(dbName, password);

    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss loading
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

  /// Shows a password entry dialog.
  ///
  /// If [confirmMode] is true, requires the user to type the password twice.
  Future<String?> _showPasswordDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required bool confirmMode,
  }) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: hint,
                      errorText: errorText,
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (confirmMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pw = passwordController.text;
                    if (pw.length < 4) {
                      setState(() => errorText = 'Password must be at least 4 characters');
                      return;
                    }
                    if (confirmMode && pw != confirmController.text) {
                      setState(() => errorText = 'Passwords do not match');
                      return;
                    }
                    Navigator.of(dialogContext).pop(pw);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
