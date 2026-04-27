import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'datavault_controller.dart';
import '../domain/vault_entities.dart';
import '../data/local_vault_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import 'package:local_auth/local_auth.dart';

class DataVaultPage extends StatefulWidget {
  const DataVaultPage({super.key});

  @override
  State<DataVaultPage> createState() => _DataVaultPageState();
}

class _DataVaultPageState extends State<DataVaultPage> {
  late final DataVaultController _controller;
  final TextEditingController _searchController = TextEditingController();

  bool _isAuthenticated = false;
  bool _isAuthenticating = true;
  final LocalAuthentication auth = LocalAuthentication();

  // Track which items just had their value copied (for checkmark feedback)
  final Set<int> _copiedIds = {};

  @override
  void initState() {
    super.initState();
    _controller = DataVaultController(repository: LocalVaultRepository());
    _controller.init();
    _controller.addListener(_onControllerNotify);
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isAuthenticating = false;
          });
        }
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Fingerprint ki Pattern Bina NoNo...',
      );

      if (mounted) {
        setState(() {
          _isAuthenticated = didAuthenticate;
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  void _onControllerNotify() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerNotify);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard(String value, int itemId) {
    Clipboard.setData(ClipboardData(text: value));
    setState(() { _copiedIds.add(itemId); });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() { _copiedIds.remove(itemId); });
    });
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.slate800,
        title: Text('Delete Entry', style: AppTypography.titleLarge),
        content: Text('Are you sure you want to delete this item?', style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _controller.deleteItem(id);
              if (mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showItemDialog({VaultItem? item}) async {
    final isEditing = item != null;
    final labelController = TextEditingController(text: isEditing ? item.label : '');
    final valueController = TextEditingController(text: isEditing ? item.value : '');
    String selectedCategory = isEditing ? item.category : _controller.categories[0];

    if (!_controller.categories.contains(selectedCategory)) {
      selectedCategory = _controller.categories[0];
    }

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.slate800,
        title: Text(isEditing ? 'Edit Info' : 'Add Info', style: AppTypography.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                dropdownColor: AppColors.slate700,
                items: _controller.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedCategory = val;
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (labelController.text.isNotEmpty &&
                  valueController.text.isNotEmpty) {
                if (isEditing) {
                  await _controller.updateItem(
                    item.id!,
                    labelController.text,
                    valueController.text,
                    selectedCategory,
                  );
                } else {
                  await _controller.addItem(
                    labelController.text,
                    valueController.text,
                    selectedCategory,
                  );
                }
                if (mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Passwords': return Icons.key;
      case 'IDs': return Icons.badge;
      case 'Cards': return Icons.credit_card;
      case 'Bank Accounts': return Icons.account_balance;
      default: return Icons.folder;
    }
  }

  // ─── Card builder ────────────────────────────────────────────────
  Widget _buildVaultCard(VaultItem item) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    final Color surface = isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.95);
    final Color border = isDark ? AppColors.slate600.withOpacity(0.7) : Colors.grey[400]!;
    final Color primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
    final Color secondaryText = isDark ? AppColors.slate300 : Colors.grey[600]!;

    final id = item.id!;
    final isExpanded = _controller.expandedIds.contains(id);
    final isHistoryExpanded = _controller.historyExpandedIds.contains(id);
    final isCopied = _copiedIds.contains(id);
    final history = _controller.getHistory(id);

    return Card(
      elevation: isDark ? 2 : 3,
      shadowColor: isDark ? Colors.black54 : Colors.black26,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border.withOpacity(isDark ? 0.6 : 0.8), width: 1.2),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Label + COPY VALUE ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lock icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lock_outline, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                // Label + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category,
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ),
                // Copy button
                _CopyValueButton(
                  isCopied: isCopied,
                  onPressed: () => _copyToClipboard(item.value, id),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Row 2: Action buttons row ──
            Row(
              children: [
                // Edit
                _ActionChip(
                  icon: Icons.edit,
                  color: AppColors.govGold,
                  onPressed: () => _showItemDialog(item: item),
                ),
                const SizedBox(width: 8),
                // Delete
                _ActionChip(
                  icon: Icons.delete_outline,
                  color: Colors.redAccent,
                  onPressed: () => _confirmDelete(id),
                ),
                const Spacer(),
                // Details expand
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _controller.toggleExpand(id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Details', style: TextStyle(fontSize: 13, color: secondaryText, fontWeight: FontWeight.w500)),
                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: secondaryText),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Expandable: Password value ──
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate900.withOpacity(0.5) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Value:', style: TextStyle(fontSize: 11, color: secondaryText, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
              ),

              // ── History section ──
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _controller.toggleHistoryExpand(id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 15, color: secondaryText),
                      const SizedBox(width: 4),
                      Text('Password History', style: TextStyle(fontSize: 12, color: secondaryText, fontWeight: FontWeight.w500)),
                      Icon(isHistoryExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: secondaryText),
                    ],
                  ),
                ),
              ),

              if (isHistoryExpanded) ...[
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                    child: Text('No previous passwords', style: TextStyle(fontSize: 12, color: secondaryText, fontStyle: FontStyle.italic)),
                  )
                else
                  ...history.map((h) => _buildHistoryTile(h, isDark, primaryText, secondaryText, border)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(VaultHistory h, bool isDark, Color primaryText, Color secondaryText, Color border) {
    final dateStr = DateFormat('MMM dd, yyyy – hh:mm a').format(h.changedAt);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900.withOpacity(0.35) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.oldValue, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primaryText)),
                const SizedBox(height: 2),
                Text(dateStr, style: TextStyle(fontSize: 10, color: secondaryText)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 16, color: secondaryText),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: h.oldValue));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Old password copied'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Main build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color inputFill = isDark ? AppColors.slate900.withOpacity(0.55) : Colors.grey[100]!;
    final Color border = isDark ? AppColors.slate700.withOpacity(0.8) : Colors.grey[300]!;
    final Color primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
    final Color secondaryText = isDark ? AppColors.slate300 : Colors.grey[600]!;

    final filteredItems = _controller.filteredItems;

    return AnimatedBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Data Vault'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.transparent : theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_isAuthenticating && _isAuthenticated)
            IconButton(
              icon: Icon(
                _controller.showAllPasswords ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: _controller.showAllPasswords ? 'Collapse All' : 'Expand All',
              onPressed: () => _controller.toggleShowAll(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isAuthenticating)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isAuthenticating && !_isAuthenticated)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 80, color: isDark ? AppColors.slate500 : Colors.grey[400]),
                    const SizedBox(height: 20),
                    Text('Vault Locked', style: AppTypography.titleLarge.copyWith(color: primaryText)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _authenticate,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Unlock Vault'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isAuthenticating && _isAuthenticated) ...[
            // Search bar
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search your vault...',
                hintStyle: TextStyle(color: secondaryText),
                prefixIcon: Icon(Icons.search, color: secondaryText),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                suffixIcon: _controller.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                         _searchController.clear();
                         _controller.searchQuery = '';
                      },
                    )
                  : null,
              ),
              style: TextStyle(color: primaryText),
              onChanged: (val) => _controller.searchQuery = val,
            ),
          ),
          
          // Items list grouped by category
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open, size: 60, color: isDark ? AppColors.slate500 : Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _controller.items.isEmpty 
                            ? 'Your vault is empty.\nProtect your data now!' 
                            : 'No matches found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: secondaryText, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: _controller.categories.map((category) {
                      final categoryItems = filteredItems
                          .where((i) => i.category == category)
                          .toList();
                      
                      if (categoryItems.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800.withOpacity(0.7) : Colors.grey[200]!.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(color: theme.primaryColor, width: 4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(_categoryIcon(category), size: 18, color: theme.primaryColor),
                                const SizedBox(width: 10),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 15, 
                                    fontWeight: FontWeight.w700, 
                                    color: primaryText,
                                    letterSpacing: 0.5
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${categoryItems.length}',
                                  style: TextStyle(fontSize: 13, color: secondaryText, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          ...categoryItems.map((item) => _buildVaultCard(item)),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          ],
        ],
      ),
      floatingActionButton: (!_isAuthenticating && _isAuthenticated) ? FloatingActionButton.extended(
        onPressed: () => _showItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ) : null,
    ),
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────

class _CopyValueButton extends StatelessWidget {
  final bool isCopied;
  final VoidCallback onPressed;

  const _CopyValueButton({required this.isCopied, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCopied ? Colors.green.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCopied ? Icons.check : Icons.copy,
                size: 14,
                color: isCopied ? Colors.green : AppColors.govGreen,
              ),
              const SizedBox(width: 4),
              Text(
                isCopied ? 'COPIED' : 'COPY VALUE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCopied ? Colors.green : AppColors.govGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionChip({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
