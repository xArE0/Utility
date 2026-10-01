import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'datavault_controller.dart';
import '../domain/vault_entities.dart';
import '../domain/vault_repository.dart';
import '../data/local_vault_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/system_service.dart';
import 'package:local_auth/local_auth.dart';

class DataVaultPage extends StatefulWidget {
  const DataVaultPage({super.key, this.repository});

  /// Defaults to the encrypted on-device vault; tests pass their own.
  final IVaultRepository? repository;

  @override
  State<DataVaultPage> createState() => _DataVaultPageState();
}

class _DataVaultPageState extends State<DataVaultPage>
    with WidgetsBindingObserver {
  late final DataVaultController _controller;
  final TextEditingController _searchController = TextEditingController();

  bool _isAuthenticated = false;
  bool _isAuthenticating = true;
  final LocalAuthentication auth = LocalAuthentication();

  /// Set when the phone has no screen lock: the vault stays locked until one is set up.
  bool _noDeviceLock = false;

  /// Away from the app longer than this and the vault locks again.
  static const _relockAfter = Duration(seconds: 60);
  DateTime? _backgroundedAt;

  // Copy buttons showing their checkmark right now ("<id>:<field>").
  final Set<String> _copiedKeys = {};

  @override
  void initState() {
    super.initState();
    _controller = DataVaultController(
        repository: widget.repository ?? LocalVaultRepository());
    _controller.addListener(_onControllerNotify);
    WidgetsBinding.instance.addObserver(this);
    // No screenshots, screen recording or recents preview while the vault is open.
    SystemService.setSecure(true);
    _authenticate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The PIN/pattern screen of the unlock prompt itself pauses the app; ignore that.
    if (_isAuthenticating) return;
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final away = DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (_isAuthenticated && away > _relockAfter) {
        _controller.hideAll();
        setState(() => _isAuthenticated = false);
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (mounted) setState(() => _isAuthenticating = true);
    try {
      // Biometrics or the screen lock PIN/pattern/password. Without any screen lock there is
      // nothing to check against, so the vault stays locked rather than opening for anyone.
      final bool canAuthenticate = await auth.isDeviceSupported();
      if (!canAuthenticate) {
        if (mounted) {
          setState(() {
            _noDeviceLock = true;
            _isAuthenticated = false;
            _isAuthenticating = false;
          });
        }
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Fingerprint ki Pattern Bina NoNo...',
      );

      // The database is opened only once the user is through.
      if (didAuthenticate && !_controller.initialized) {
        await _controller.init();
      }

      if (mounted) {
        setState(() {
          _noDeviceLock = false;
          _isAuthenticated = didAuthenticate;
          _isAuthenticating = false;
        });
      }
    } on LocalAuthException catch (e) {
      if (mounted) {
        setState(() {
          _noDeviceLock = e.code == LocalAuthExceptionCode.noCredentialsSet;
          _isAuthenticated = false;
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
    WidgetsBinding.instance.removeObserver(this);
    SystemService.setSecure(false);
    _controller.removeListener(_onControllerNotify);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Flagged sensitive (hidden from clipboard previews) and cleared again after 30 s.
  /// [key] identifies the button that copied, for its brief checkmark.
  void _copyToClipboard(String value, String key) {
    SystemService.copySensitive(value);
    HapticFeedback.selectionClick();
    setState(() => _copiedKeys.add(key));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedKeys.remove(key));
    });
  }

  void _confirmDelete(VaultItem item) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.slate800,
        title: Text('Delete "${item.label}"?', style: AppTypography.titleLarge),
        content: Text('This entry and its history will be removed for good.',
            style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _controller.deleteItem(item.id!);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) AppToast.show(context, 'Deleted ${item.label}');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// A strong random password: 20 characters from letters, digits and symbols.
  static String _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*?-_=+';
    final rng = Random.secure();
    return List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ─── Add / edit sheet ────────────────────────────────────────────
  void _showItemDialog({VaultItem? item}) async {
    final isEditing = item != null;
    final labelController = TextEditingController(text: item?.label ?? '');
    final valueController = TextEditingController(text: item?.value ?? '');
    final usernameController =
        TextEditingController(text: item?.username ?? '');
    final websiteController = TextEditingController(text: item?.website ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');
    final tagsController = TextEditingController(
      text: item?.tagList.map((t) => '#$t').join(' ') ?? '',
    );
    final customFieldControllers = <_CustomFieldControllers>[
      if (isEditing)
        for (final f in item.customFields)
          _CustomFieldControllers(name: f.name, value: f.value),
    ];
    String selectedCategory = item?.category ??
        _controller.categoryFilter ??
        _controller.categories[0];
    if (!_controller.categories.contains(selectedCategory)) {
      selectedCategory = _controller.categories[0];
    }
    bool obscureSecret = isEditing;
    String? labelError;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cs = Theme.of(context).colorScheme;
            final fieldFill = AppColors.slate800.withValues(alpha: 0.6);
            final fieldBorder = AppColors.slate600.withValues(alpha: 0.5);

            InputDecoration deco(String label,
                {String? hint, IconData? icon, Widget? suffix, String? error}) {
              OutlineInputBorder outline(Color c, [double w = 1]) =>
                  OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c, width: w),
                  );
              return InputDecoration(
                labelText: label,
                hintText: hint,
                errorText: error,
                labelStyle: const TextStyle(color: AppColors.slate400),
                hintStyle: const TextStyle(color: AppColors.slate500),
                prefixIcon: icon == null
                    ? null
                    : Icon(icon, color: AppColors.slate400, size: 20),
                suffixIcon: suffix,
                filled: true,
                fillColor: fieldFill,
                border: outline(fieldBorder),
                enabledBorder: outline(fieldBorder),
                focusedBorder: outline(cs.primary, 1.5),
                errorBorder: outline(Colors.redAccent),
                focusedErrorBorder: outline(Colors.redAccent, 1.5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              );
            }

            const fieldStyle =
                TextStyle(fontSize: 16, color: AppColors.slate50);
            const gap = SizedBox(height: 14);

            Future<void> save() async {
              if (saving) return;
              final label = labelController.text.trim();
              if (label.isEmpty) {
                setSheetState(() => labelError = 'Give the entry a name');
                return;
              }
              saving = true;
              // Parse tags: split by # and whitespace, trim, deduplicate
              final rawTags = tagsController.text
                  .split(RegExp(r'[#\s,]+'))
                  .map((t) => t.trim().toLowerCase())
                  .where((t) => t.isNotEmpty)
                  .toSet()
                  .join(',');
              final customFields = customFieldControllers
                  .where((c) => c.nameController.text.trim().isNotEmpty)
                  .map((c) => VaultCustomField(
                        name: c.nameController.text.trim(),
                        value: c.valueController.text.trim(),
                      ))
                  .toList();
              if (isEditing) {
                await _controller.updateItem(
                  item.id!,
                  label,
                  valueController.text,
                  selectedCategory,
                  tags: rawTags,
                  username: usernameController.text.trim(),
                  website: websiteController.text.trim(),
                  note: noteController.text.trim(),
                  customFields: customFields,
                );
              } else {
                await _controller.addItem(
                  label,
                  valueController.text,
                  selectedCategory,
                  tags: rawTags,
                  username: usernameController.text.trim(),
                  website: websiteController.text.trim(),
                  note: noteController.text.trim(),
                  customFields: customFields,
                );
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              if (mounted) {
                AppToast.show(
                    this.context, isEditing ? 'Saved' : 'Added $label');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.92),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: AppColors.slate700)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Handle + header ──
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEditing ? 'Edit Entry' : 'New Entry',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate50),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close,
                                color: AppColors.slate400),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    // ── Category ──
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          for (final cat in _controller.categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _Pill(
                                icon: _categoryIcon(cat),
                                label: cat,
                                selected: selectedCategory == cat,
                                onTap: () =>
                                    setSheetState(() => selectedCategory = cat),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Fields ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: labelController,
                              autofocus: !isEditing,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              style: fieldStyle,
                              onChanged: (_) {
                                if (labelError != null) {
                                  setSheetState(() => labelError = null);
                                }
                              },
                              decoration: deco('Name *',
                                  hint: 'e.g. Gmail, Netflix, Bank PIN',
                                  icon: Icons.label_outline,
                                  error: labelError),
                            ),
                            gap,
                            TextField(
                              controller: usernameController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              style: fieldStyle,
                              decoration: deco('Username / email',
                                  icon: Icons.person_outline),
                            ),
                            gap,
                            TextField(
                              controller: valueController,
                              obscureText: obscureSecret,
                              autocorrect: false,
                              enableSuggestions: false,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.next,
                              style:
                                  fieldStyle.copyWith(fontFamily: 'monospace'),
                              decoration: deco(
                                'Password / secret',
                                icon: Icons.lock_outline,
                                suffix: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Generate strong password',
                                      icon: const Icon(Icons.auto_fix_high,
                                          size: 20, color: AppColors.slate400),
                                      onPressed: () => setSheetState(() {
                                        valueController.text =
                                            _generatePassword();
                                        obscureSecret = false;
                                      }),
                                    ),
                                    IconButton(
                                      tooltip: obscureSecret ? 'Show' : 'Hide',
                                      icon: Icon(
                                          obscureSecret
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                          color: AppColors.slate400),
                                      onPressed: () => setSheetState(
                                          () => obscureSecret = !obscureSecret),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            gap,
                            TextField(
                              controller: websiteController,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              style: fieldStyle,
                              decoration: deco('Website',
                                  hint: 'example.com', icon: Icons.language),
                            ),
                            gap,
                            TextField(
                              controller: noteController,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              style: fieldStyle,
                              decoration: deco('Note', icon: Icons.notes),
                            ),
                            gap,
                            TextField(
                              controller: tagsController,
                              autocorrect: false,
                              style: fieldStyle,
                              decoration: deco('Tags',
                                  hint: '#share #money', icon: Icons.tag),
                            ),

                            // ── Custom fields ──
                            for (final entry
                                in customFieldControllers.asMap().entries)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: entry.value.nameController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        style: fieldStyle,
                                        decoration:
                                            deco('Field', hint: 'e.g. CVV'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: entry.value.valueController,
                                        autocorrect: false,
                                        style: fieldStyle,
                                        decoration: deco('Value'),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove field',
                                      onPressed: () => setSheetState(() =>
                                          customFieldControllers
                                              .removeAt(entry.key)),
                                      icon: Icon(Icons.remove_circle_outline,
                                          color: Colors.redAccent
                                              .withValues(alpha: 0.85),
                                          size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () => setSheetState(() =>
                                  customFieldControllers
                                      .add(_CustomFieldControllers())),
                              icon:
                                  Icon(Icons.add, size: 18, color: cs.primary),
                              label: Text('Add custom field',
                                  style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Save (always visible) ──
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: save,
                            icon: Icon(isEditing ? Icons.check : Icons.add,
                                size: 20),
                            label: Text(
                                isEditing ? 'Save Changes' : 'Add to Vault',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
      case 'Passwords':
        return Icons.key;
      case 'IDs':
        return Icons.badge;
      case 'Cards':
        return Icons.credit_card;
      case 'Bank Accounts':
        return Icons.account_balance;
      default:
        return Icons.folder;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Passwords':
        return AppColors.govBlue;
      case 'IDs':
        return AppColors.govGold;
      case 'Cards':
        return const Color(0xFFA78BFA);
      case 'Bank Accounts':
        return AppColors.govGreen;
      default:
        return AppColors.slate400;
    }
  }

  /// One line under the name: who it's for, else where it's for.
  String? _subtitle(VaultItem item) {
    if (item.username.isNotEmpty) return item.username;
    if (item.website.isNotEmpty) {
      return item.website.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    }
    if (item.customFields.isNotEmpty) {
      return item.customFields.map((f) => f.name).join(' · ');
    }
    if (item.note.isNotEmpty) return item.note.split('\n').first;
    return null;
  }

  // ─── Card ────────────────────────────────────────────────────────
  Widget _buildVaultCard(VaultItem item) {
    final id = item.id!;
    final isExpanded = _controller.expandedIds.contains(id);
    final isRevealed = _controller.visibleIds.contains(id);
    final accent = _categoryColor(item.category);
    final subtitle = _subtitle(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.slate800.withValues(alpha: isExpanded ? 0.92 : 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: isExpanded
                  ? accent.withValues(alpha: 0.5)
                  : AppColors.slate700.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _controller.toggleExpand(id),
          onLongPress: () => _showItemDialog(item: item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary row ──
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.label.isEmpty
                            ? '?'
                            : item.label.characters.first.toUpperCase(),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate50),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.slate400),
                            ),
                        ],
                      ),
                    ),
                    // Quick copies, no need to open the entry.
                    if (item.username.isNotEmpty)
                      _CopyIcon(
                        icon: Icons.person_outline,
                        tooltip: 'Copy username',
                        copied: _copiedKeys.contains('$id:user'),
                        onPressed: () =>
                            _copyToClipboard(item.username, '$id:user'),
                      ),
                    if (item.value.isNotEmpty)
                      _CopyIcon(
                        icon: Icons.key,
                        tooltip: 'Copy password',
                        copied: _copiedKeys.contains('$id:value'),
                        onPressed: () =>
                            _copyToClipboard(item.value, '$id:value'),
                      ),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20, color: AppColors.slate500),
                  ],
                ),

                // ── Details ──
                if (isExpanded) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.slate700),
                  const SizedBox(height: 4),
                  if (item.username.isNotEmpty)
                    _DetailRow(
                      label: 'Username',
                      value: item.username,
                      copied: _copiedKeys.contains('$id:user'),
                      onCopy: () => _copyToClipboard(item.username, '$id:user'),
                    ),
                  if (item.value.isNotEmpty)
                    _DetailRow(
                      label:
                          item.category == 'Passwords' ? 'Password' : 'Secret',
                      value: item.value,
                      secret: true,
                      revealed: isRevealed,
                      onToggleReveal: () => _controller.toggleVisibility(id),
                      copied: _copiedKeys.contains('$id:value'),
                      onCopy: () => _copyToClipboard(item.value, '$id:value'),
                    ),
                  if (item.website.isNotEmpty)
                    _DetailRow(
                      label: 'Website',
                      value: item.website,
                      copied: _copiedKeys.contains('$id:web'),
                      onCopy: () => _copyToClipboard(item.website, '$id:web'),
                    ),
                  for (final (i, field) in item.customFields.indexed)
                    _DetailRow(
                      label: field.name,
                      value: field.value,
                      copied: _copiedKeys.contains('$id:f$i'),
                      onCopy: () => _copyToClipboard(field.value, '$id:f$i'),
                    ),
                  if (item.note.isNotEmpty)
                    _DetailRow(
                        label: 'Note', value: item.note, multiline: true),
                  if (item.tagList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in item.tagList)
                            ActionChip(
                              label: Text('#$tag'),
                              labelStyle:
                                  TextStyle(fontSize: 12, color: accent),
                              backgroundColor: accent.withValues(alpha: 0.1),
                              side: BorderSide(
                                  color: accent.withValues(alpha: 0.3)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onPressed: () {
                                _searchController.text = '#$tag';
                                _controller.searchQuery = '#$tag';
                              },
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  // ── Actions ── (wraps onto two lines with large text instead of overflowing)
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => _controller.toggleHistoryExpand(id),
                          icon: const Icon(Icons.history, size: 18),
                          label: Text(
                              _controller.historyExpandedIds.contains(id)
                                  ? 'Hide history'
                                  : 'History'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.slate400),
                        ),
                        Wrap(children: [
                          TextButton.icon(
                            onPressed: () => _showItemDialog(item: item),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.govGold),
                          ),
                          TextButton.icon(
                            onPressed: () => _confirmDelete(item),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  if (_controller.historyExpandedIds.contains(id))
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 4),
                      child: _controller.getHistory(id).isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('No earlier values',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slate500,
                                      fontStyle: FontStyle.italic)),
                            )
                          : Column(
                              children: _controller
                                  .getHistory(id)
                                  .take(5)
                                  .map((h) => _buildHistoryTile(h, isRevealed))
                                  .toList(),
                            ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(VaultHistory h, bool revealed) {
    final dateStr = DateFormat('MMM d, yyyy · h:mm a').format(h.changedAt);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    revealed
                        ? h.oldValue
                        : '•' * h.oldValue.length.clamp(6, 16),
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.slate200)),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.slate500)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 16, color: AppColors.slate400),
            onPressed: () {
              SystemService.copySensitive(h.oldValue);
              AppToast.show(context, 'Copied — clears in 30 s');
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline,
                size: 16, color: Colors.redAccent.withValues(alpha: 0.7)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: AppColors.slate800,
                  title:
                      Text('Delete History', style: AppTypography.titleLarge),
                  content: Text('Remove this history entry?',
                      style: AppTypography.bodyMedium),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _controller.deleteHistory(h.id!, h.vaultItemId);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
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

  Widget _buildCategoryChips() {
    final selected = _controller.categoryFilter;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Pill(
            label: 'All ${_controller.items.length}',
            selected: selected == null,
            onTap: () => _controller.categoryFilter = null,
          ),
          for (final cat in _controller.categories)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Pill(
                icon: _categoryIcon(cat),
                label: '$cat ${_controller.countFor(cat)}',
                selected: selected == cat,
                onTap: () =>
                    _controller.categoryFilter = selected == cat ? null : cat,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String category, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Icon(_categoryIcon(category),
              size: 16, color: _categoryColor(category)),
          const SizedBox(width: 8),
          Text(
            category.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.slate300),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final vaultEmpty = _controller.items.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(vaultEmpty ? Icons.shield_outlined : Icons.search_off,
                size: 56, color: AppColors.slate500),
            const SizedBox(height: 14),
            Text(
              vaultEmpty ? 'Your vault is empty' : 'No matches',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate200),
            ),
            const SizedBox(height: 6),
            Text(
              vaultEmpty
                  ? 'Passwords, IDs, cards and accounts — encrypted on this phone.'
                  : 'Try another word, or #tag to search tags.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.slate400),
            ),
            if (!vaultEmpty &&
                (_controller.searchQuery.isNotEmpty ||
                    _controller.categoryFilter != null)) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _controller.searchQuery = '';
                  _controller.categoryFilter = null;
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Main build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredItems = _controller.filteredItems;
    final unlocked = !_isAuthenticating && _isAuthenticated;

    // Grouped by category when showing all; flat when one category is picked.
    final listChildren = <Widget>[];
    if (_controller.categoryFilter != null) {
      listChildren.add(const SizedBox(height: 8));
      listChildren.addAll(filteredItems.map(_buildVaultCard));
    } else {
      for (final category in _controller.categories) {
        final categoryItems =
            filteredItems.where((i) => i.category == category).toList();
        if (categoryItems.isEmpty) continue;
        listChildren.add(_buildSectionHeader(category, categoryItems.length));
        listChildren.addAll(categoryItems.map(_buildVaultCard));
      }
    }

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Data Vault'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: [
            if (unlocked && _controller.items.isNotEmpty)
              IconButton(
                icon: Icon(_controller.showAllPasswords
                    ? Icons.visibility_off
                    : Icons.visibility),
                tooltip: _controller.showAllPasswords ? 'Hide all' : 'Show all',
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
                      const Icon(Icons.lock,
                          size: 80, color: AppColors.slate500),
                      const SizedBox(height: 20),
                      Text('Vault Locked',
                          style: AppTypography.titleLarge
                              .copyWith(color: AppColors.slate50)),
                      if (_noDeviceLock)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                          child: Text(
                            'Set a screen lock (PIN, pattern, password or fingerprint) '
                            'in your phone settings to use the vault.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.slate400),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock Vault'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (unlocked) ...[
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search names, usernames, sites, #tags',
                    hintStyle: const TextStyle(color: AppColors.slate400),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.slate400),
                    filled: true,
                    fillColor: AppColors.slate900.withValues(alpha: 0.55),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                          color: AppColors.slate700.withValues(alpha: 0.8)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
                  style: const TextStyle(color: AppColors.slate50),
                  onChanged: (val) => _controller.searchQuery = val,
                ),
              ),
              if (_controller.items.isNotEmpty) _buildCategoryChips(),
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        // Room for the add button over the last card.
                        padding: const EdgeInsets.only(bottom: 96),
                        children: listChildren,
                      ),
              ),
            ],
          ],
        ),
        floatingActionButton: unlocked
            ? FloatingActionButton.extended(
                onPressed: () => _showItemDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Entry'),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              )
            : null,
      ),
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────

/// One labelled value in an opened entry: tap-to-copy, with show/hide for secrets.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool secret;
  final bool revealed;
  final bool multiline;
  final bool copied;
  final VoidCallback? onCopy;
  final VoidCallback? onToggleReveal;

  const _DetailRow({
    required this.label,
    required this.value,
    this.secret = false,
    this.revealed = false,
    this.multiline = false,
    this.copied = false,
    this.onCopy,
    this.onToggleReveal,
  });

  @override
  Widget build(BuildContext context) {
    final masked = secret && !revealed;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onCopy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        child: Row(
          crossAxisAlignment:
              multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.slate500)),
                  const SizedBox(height: 2),
                  Text(
                    masked ? '•' * value.length.clamp(8, 16) : value,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.slate100,
                      fontFamily: secret ? 'monospace' : null,
                      letterSpacing: secret ? 1.2 : null,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (secret)
              IconButton(
                tooltip: revealed ? 'Hide' : 'Show',
                icon: Icon(
                    revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.slate400),
                onPressed: onToggleReveal,
              ),
            if (onCopy != null)
              _CopyIcon(
                  icon: Icons.copy,
                  tooltip: 'Copy $label',
                  copied: copied,
                  onPressed: onCopy!),
          ],
        ),
      ),
    );
  }
}

/// Copy button that turns into a green check for a moment.
class _CopyIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool copied;
  final VoidCallback onPressed;

  const _CopyIcon(
      {required this.icon,
      required this.tooltip,
      required this.copied,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: copied
            ? const Icon(Icons.check,
                key: ValueKey('ok'), size: 20, color: AppColors.govGreen)
            : Icon(icon,
                key: const ValueKey('copy'),
                size: 20,
                color: AppColors.slate300),
      ),
    );
  }
}

/// Rounded filter/selection pill.
class _Pill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill(
      {this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.primary : AppColors.slate300;
    return Material(
      color: selected
          ? cs.primary.withValues(alpha: 0.15)
          : AppColors.slate800.withValues(alpha: 0.6),
      shape: StadiumBorder(
        side: BorderSide(
            color: selected
                ? cs.primary.withValues(alpha: 0.6)
                : AppColors.slate700),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Holds the name/value text controllers for one custom-field row in the
/// add/edit sheet.
class _CustomFieldControllers {
  final TextEditingController nameController;
  final TextEditingController valueController;

  _CustomFieldControllers({String name = '', String value = ''})
      : nameController = TextEditingController(text: name),
        valueController = TextEditingController(text: value);
}
