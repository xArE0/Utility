import 'package:flutter/material.dart';
import 'export_import_controller.dart';
import '../data/local_export_import_repository.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/theme/app_colors.dart';

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
  final String logbookDbName = 'logbook.db';

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
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Export & Import')),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            // ── Full Backup Section ──
            _sectionLabel('Full Backup'),
            const SizedBox(height: 6),
            Card(
              color: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.backup,
                          color: Colors.greenAccent, size: 22),
                    ),
                    title: const Text('Export All Databases',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Bundle everything into a .zip'),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _controller.exportAll(context),
                  ),
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.white.withValues(alpha: 0.1)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            Colors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.restore,
                          color: Colors.orangeAccent, size: 22),
                    ),
                    title: const Text('Import All Databases',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Restore from a .zip backup'),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _controller.importAll(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Individual Databases ──
            _sectionLabel('Individual Databases'),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: [
                _dbCard(
                  name: 'Schedule',
                  icon: Icons.calendar_month,
                  color: AppColors.govBlue,
                  dbName: scheduleDbName,
                  isEncrypted: false,
                ),
                _dbCard(
                  name: 'Expenses',
                  icon: Icons.account_balance_wallet,
                  color: AppColors.govGreen,
                  dbName: expenseDbName,
                  isEncrypted: false,
                ),
                _dbCard(
                  name: 'Data Vault',
                  icon: Icons.shield,
                  color: Colors.amberAccent,
                  dbName: dataVaultDbName,
                  isEncrypted: true,
                ),
                _dbCard(
                  name: 'Cooldown',
                  icon: Icons.timer,
                  color: Colors.cyanAccent,
                  dbName: cooldownDbName,
                  isEncrypted: false,
                ),
                _dbCard(
                  name: 'Logbook',
                  icon: Icons.menu_book,
                  color: Colors.purpleAccent,
                  dbName: logbookDbName,
                  isEncrypted: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Section label ──
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white54,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Individual DB card ──
  Widget _dbCard({
    required String name,
    required IconData icon,
    required Color color,
    required String dbName,
    required bool isEncrypted,
  }) {
    return Card(
      color: Colors.white.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            // Name
            Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (isEncrypted)
              const Text(
                'Encrypted',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            if (!isEncrypted) const SizedBox(height: 14), // balance height difference
            const SizedBox(height: 12),
            // Export / Import buttons
            Row(
              children: [
                Expanded(
                  child: _miniButton(
                    label: 'Export',
                    icon: Icons.upload,
                    color: color,
                    onTap: () {
                      if (isEncrypted) {
                        _controller.exportEncryptedVault(context, dbName);
                      } else {
                        _controller.exportDatabase(context, dbName);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _miniButton(
                    label: 'Import',
                    icon: Icons.download,
                    color: Colors.white54,
                    onTap: () {
                      if (isEncrypted) {
                        _controller.importEncryptedVault(context, dbName);
                      } else {
                        _controller.importDatabase(context, dbName);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Small action button inside DB card ──
  Widget _miniButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}