import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'datavault_controller.dart';
import '../domain/vault_entities.dart';
import '../data/local_vault_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
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
    final usernameController = TextEditingController(text: isEditing ? item.username : '');
    final websiteController = TextEditingController(text: isEditing ? item.website : '');
    final noteController = TextEditingController(text: isEditing ? item.note : '');
    final tagsController = TextEditingController(
      text: isEditing ? item.tagList.map((t) => '#$t').join(' ') : '',
    );
    String selectedCategory = isEditing ? item.category : _controller.categories[0];

    if (!_controller.categories.contains(selectedCategory)) {
      selectedCategory = _controller.categories[0];
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final bool isDark = theme.brightness == Brightness.dark;
            final cs = theme.colorScheme;

            final Color sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final Color fieldFill = isDark ? AppColors.slate800.withOpacity(0.6) : Colors.grey[100]!;
            final Color fieldBorder = isDark ? AppColors.slate600.withOpacity(0.5) : Colors.grey[300]!;
            final Color primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
            final Color secondaryText = isDark ? AppColors.slate400 : Colors.grey[500]!;
            final Color hintColor = isDark ? AppColors.slate500 : Colors.grey[400]!;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Drag handle ──
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 20),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: secondaryText.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // ── Header ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isEditing ? Icons.edit_note : Icons.add_circle_outline,
                                color: cs.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing ? 'Edit Entry' : 'New Entry',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEditing ? 'Update your saved credentials' : 'Store a new secret securely',
                                    style: TextStyle(fontSize: 13, color: secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: secondaryText),
                              style: IconButton.styleFrom(
                                backgroundColor: fieldFill,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Category selector ──
                        Text(
                          'CATEGORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryText,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _controller.categories.map((cat) {
                            final isSelected = selectedCategory == cat;
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() { selectedCategory = cat; });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? cs.primary.withOpacity(0.15)
                                      : fieldFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? cs.primary.withOpacity(0.6)
                                        : fieldBorder,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _categoryIcon(cat),
                                      size: 16,
                                      color: isSelected ? cs.primary : secondaryText,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? cs.primary : primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // ── Label field ──
                        Text(
                          'LABEL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryText,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: labelController,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(fontSize: 16, color: primaryText),
                          decoration: InputDecoration(
                            hintText: 'e.g. Gmail, Netflix, Bank PIN',
                            hintStyle: TextStyle(color: hintColor),
                            prefixIcon: Icon(Icons.label_outline, color: secondaryText, size: 20),
                            filled: true,
                            fillColor: fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Username & Value row ──
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'USERNAME',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: secondaryText,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: usernameController,
                                    style: TextStyle(fontSize: 16, color: primaryText),
                                    decoration: InputDecoration(
                                      hintText: 'Username, email...',
                                      hintStyle: TextStyle(color: hintColor),
                                      prefixIcon: Icon(Icons.person_outline, color: secondaryText, size: 20),
                                      filled: true,
                                      fillColor: fieldFill,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: fieldBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PASSWORD',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: secondaryText,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: valueController,
                                    style: TextStyle(fontSize: 16, color: primaryText),
                                    decoration: InputDecoration(
                                      hintText: 'Password...',
                                      hintStyle: TextStyle(color: hintColor),
                                      prefixIcon: Icon(Icons.lock_outline, color: secondaryText, size: 20),
                                      filled: true,
                                      fillColor: fieldFill,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: fieldBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Website field ──
                        Text(
                          'WEBSITE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryText,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: websiteController,
                          style: TextStyle(fontSize: 16, color: primaryText),
                          decoration: InputDecoration(
                            hintText: 'https://example.com',
                            hintStyle: TextStyle(color: hintColor),
                            prefixIcon: Icon(Icons.language, color: secondaryText, size: 20),
                            filled: true,
                            fillColor: fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Note field ──
                        Text(
                          'NOTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryText,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          style: TextStyle(fontSize: 16, color: primaryText),
                          decoration: InputDecoration(
                            hintText: 'Add optional notes...',
                            hintStyle: TextStyle(color: hintColor),
                            prefixIcon: Icon(Icons.note_outlined, color: secondaryText, size: 20),
                            filled: true,
                            fillColor: fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Tags field ──
                        Text(
                          'TAGS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryText,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: tagsController,
                          style: TextStyle(fontSize: 16, color: primaryText),
                          decoration: InputDecoration(
                            hintText: '#share #money #personal',
                            hintStyle: TextStyle(color: hintColor),
                            prefixIcon: Icon(Icons.tag, color: secondaryText, size: 20),
                            filled: true,
                            fillColor: fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Save button ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (labelController.text.isNotEmpty &&
                                  valueController.text.isNotEmpty) {
                                // Parse tags: split by # and whitespace, trim, deduplicate
                                final rawTags = tagsController.text
                                    .split(RegExp(r'[#\s]+'))
                                    .map((t) => t.trim().toLowerCase())
                                    .where((t) => t.isNotEmpty)
                                    .toSet()
                                    .join(',');
                                if (isEditing) {
                                  await _controller.updateItem(
                                    item.id!,
                                    labelController.text,
                                    valueController.text,
                                    selectedCategory,
                                    tags: rawTags,
                                    username: usernameController.text.trim(),
                                    website: websiteController.text.trim(),
                                    note: noteController.text.trim(),
                                  );
                                } else {
                                  await _controller.addItem(
                                    labelController.text,
                                    valueController.text,
                                    selectedCategory,
                                    tags: rawTags,
                                    username: usernameController.text.trim(),
                                    website: websiteController.text.trim(),
                                    note: noteController.text.trim(),
                                  );
                                }
                                if (mounted) Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isEditing ? Icons.save : Icons.add, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isEditing ? 'Save Changes' : 'Add to Vault',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
        child: Stack(
          children: [
            // Vertical connector line from lock icon downward
            Positioned(
              left: 15,
              top: 36,
              bottom: 8,
              child: Container(
                width: 1.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      border.withOpacity(isDark ? 0.45 : 0.3),
                      border.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
            // Main content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Side Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Lock + Label/Category
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Lock icon
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.lock_outline, color: cs.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            // Label + category
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText,
                                    ),
                                    softWrap: true,
                                  ),
                                  Text(
                                    item.category,
                                    style: TextStyle(fontSize: 11, color: secondaryText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Middle Row: Tags (if any)
                        if (item.tagList.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 42),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: item.tagList.map((tag) {
                                return GestureDetector(
                                  onTap: () {
                                    _searchController.text = tag;
                                    _controller.searchQuery = tag;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: cs.primary.withOpacity(0.3), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.tag, size: 12, color: cs.primary.withOpacity(0.7)),
                                        const SizedBox(width: 2),
                                        Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 6),

                        // Bottom Row: Copy Value Button (aligned with label text)
                        Padding(
                          padding: const EdgeInsets.only(left: 42),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _CopyValueButton(
                              isCopied: isCopied,
                              onPressed: () => _copyToClipboard(item.value, id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right Side Actions Column (aligned to match paint mockup exactly)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Edit Button
                      _ActionChip(
                        icon: Icons.edit,
                        color: AppColors.govGold,
                        onPressed: () => _showItemDialog(item: item),
                      ),
                      const SizedBox(height: 8), // Consistent 8px gap between Edit and Delete
                      // Delete Button
                      _ActionChip(
                        icon: Icons.delete_outline,
                        color: Colors.redAccent,
                        onPressed: () => _confirmDelete(id),
                      ),
                      const Spacer(), // Pushes Details to the bottom, keeping Edit/Delete gap consistent
                      // Details Toggle
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _controller.toggleExpand(id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                                color: secondaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Expandable detail sections ──
            if (isExpanded) ...[
              const SizedBox(height: 14),

              // Indented to align with label text (lock icon 32px + 10px gap = 42px)
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;

                    const labelStyle = TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1.1,
                      height: 1.0,
                    );

                    final contentStyle = TextStyle(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const ['Courier New', 'Consolas'],
                      fontSize: 16,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w500,
                      color: primaryText,
                      height: 1.2,
                    );

                    final boxDecor = BoxDecoration(
                      color: isDark ? AppColors.slate900.withOpacity(0.5) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border.withOpacity(0.5)),
                    );

                    // Helper: builds a label-above-box widget
                    Widget buildDetailChip(String label, String value, {VoidCallback? onCopy}) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                            child: Text(label.toUpperCase(), style: labelStyle),
                          ),
                          Container(
                            constraints: BoxConstraints(maxWidth: maxW),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: boxDecor,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    value,
                                    style: contentStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (onCopy != null) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: onCopy,
                                    child: Icon(Icons.copy, size: 15, color: cs.primary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Username + Password in a Wrap (dynamic side-by-side / stacked)
                    final usernameChip = item.username.isNotEmpty
                        ? buildDetailChip('Username', item.username, onCopy: () => _copyToClipboard(item.username, id))
                        : null;

                    final passwordChip = buildDetailChip('Password', item.value, onCopy: () => _copyToClipboard(item.value, id));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username & Password row
                        Wrap(
                          spacing: 10,
                          runSpacing: 12,
                          children: [
                            if (usernameChip != null)
                              IntrinsicWidth(child: usernameChip),
                            IntrinsicWidth(child: passwordChip),
                          ],
                        ),

                        // Website
                        if (item.website.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          buildDetailChip('Website', item.website, onCopy: () => _copyToClipboard(item.website, id)),
                        ],

                        // Note
                        if (item.note.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 2),
                                child: Text('NOTE', style: labelStyle),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: boxDecor,
                                child: Text(
                                  item.note,
                                  style: contentStyle.copyWith(letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

               // ── History section ──
               const SizedBox(height: 12),
               Padding(
                 padding: const EdgeInsets.only(left: 42),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     InkWell(
                       borderRadius: BorderRadius.circular(8),
                       onTap: () => _controller.toggleHistoryExpand(id),
                       child: Padding(
                         padding: const EdgeInsets.symmetric(vertical: 4),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.history, size: 16, color: secondaryText),
                             const SizedBox(width: 6),
                             Text('History', style: TextStyle(fontSize: 13, color: secondaryText, fontWeight: FontWeight.w600)),
                             Icon(isHistoryExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: secondaryText),
                           ],
                         ),
                       ),
                     ),

                     if (isHistoryExpanded) ...[
                       if (history.isEmpty)
                         Padding(
                           padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                           child: Text('No previous entries', style: TextStyle(fontSize: 12, color: secondaryText, fontStyle: FontStyle.italic)),
                         )
                       else
                         ...history.take(5).map((h) => _buildHistoryTile(h, isDark, primaryText, secondaryText, border)),
                     ],
                   ],
                 ),
               ),
            ],
          ],
        ),
          ],
        ),
      ),
    );
  }

   Widget _buildHistoryTile(VaultHistory h, bool isDark, Color primaryText, Color secondaryText, Color border) {
     final dateStr = DateFormat('MMM dd, yyyy – hh:mm a').format(h.changedAt);
     return Container(
       margin: const EdgeInsets.only(top: 8),
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                 Text(h.oldValue, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primaryText)),
                 const SizedBox(height: 4),
                 Text(dateStr, style: TextStyle(fontSize: 11, color: secondaryText)),
               ],
             ),
           ),
           IconButton(
             icon: Icon(Icons.copy, size: 16, color: secondaryText),
             padding: EdgeInsets.zero,
             constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
             onPressed: () {
               Clipboard.setData(ClipboardData(text: h.oldValue));
               AppToast.show(context, 'Copied to clipboard');
             },
           ),
           IconButton(
             icon: Icon(Icons.delete_outline, size: 16, color: Colors.redAccent.withOpacity(0.7)),
             padding: EdgeInsets.zero,
             constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
             onPressed: () {
               showDialog(
                 context: context,
                 builder: (dialogContext) => AlertDialog(
                   backgroundColor: AppColors.slate800,
                   title: Text('Delete History', style: AppTypography.titleLarge),
                   content: Text('Remove this history entry?', style: AppTypography.bodyMedium),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.pop(dialogContext),
                       child: const Text('Cancel'),
                     ),
                     TextButton(
                       onPressed: () async {
                         await _controller.deleteHistory(h.id!, h.vaultItemId);
                         if (mounted) Navigator.pop(dialogContext);
                       },
                       child: const Text('Delete', style: TextStyle(color: Colors.red)),
                     ),
                   ],
                 ),
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
          padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
