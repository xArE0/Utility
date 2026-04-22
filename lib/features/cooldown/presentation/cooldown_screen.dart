import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../domain/cooldown_entities.dart';
import '../data/local_cooldown_repository.dart';
import 'cooldown_controller.dart';

const _accentColors = [
  Color(0xFF06B6D4), 
  Color(0xFF8B5CF6), 
  Color(0xFFF59E0B), 
  Color(0xFFEC4899), 
  Color(0xFF10B981), 
  Color(0xFFEF4444), 
];

class CooldownScreen extends StatefulWidget {
  const CooldownScreen({super.key});

  @override
  State<CooldownScreen> createState() => _CooldownScreenState();
}

class _CooldownScreenState extends State<CooldownScreen>
    with TickerProviderStateMixin {
  late final CooldownController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CooldownController(repository: LocalCooldownRepository());
    _controller.init();
    _controller.addListener(_onControllerNotify);
  }

  void _onControllerNotify() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerNotify);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCooldown(CooldownItem item) async {
    final result = await _showCooldownPicker(context, item.name);
    if (result != null) {
      await _controller.startCooldown(item, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Cooldown", style: AppTypography.titleLarge),
          backgroundColor: AppColors.slate900.withOpacity(0.85),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddSheet(context),
          backgroundColor: const Color(0xFF06B6D4),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _controller.loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
            : _controller.items.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 72,
              color: AppColors.slate500.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text("No cooldowns yet",
              style: AppTypography.titleMedium
                  .copyWith(color: AppColors.slate400)),
          const SizedBox(height: 8),
          Text("Tap + to add your first item",
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.slate500)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final available = _controller.available;
    final cooldown = _controller.onCooldown;
    final cats = _controller.categories;
    final hasCategories = cats.length > 1 || (cats.length == 1 && cats.first != null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildSummaryCard(available.length, cooldown.length),
        const SizedBox(height: 20),
        if (!hasCategories) ...[
          // No categories — flat list like before
          if (cooldown.isNotEmpty) ...[
            _buildSectionHeader("ON COOLDOWN", Icons.timer, AppColors.govGold, cooldown.length),
            const SizedBox(height: 8),
            ...cooldown.map(_buildCooldownTile),
            const SizedBox(height: 20),
          ],
          if (available.isNotEmpty) ...[
            _buildSectionHeader("AVAILABLE", Icons.check_circle_outline, AppColors.govGreen, available.length),
            const SizedBox(height: 8),
            ...available.map(_buildAvailableTile),
          ],
        ] else ...[
          // Grouped by category
          for (final cat in cats) ...[
            _buildCategoryHeader(cat ?? 'General'),
            ..._buildCategoryItems(_controller.itemsForCategory(cat)),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  Widget _buildCategoryHeader(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 16, color: const Color(0xFF06B6D4)),
          const SizedBox(width: 8),
          Text(
            name.toUpperCase(),
            style: AppTypography.labelLarge.copyWith(
              color: const Color(0xFF06B6D4),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF06B6D4).withOpacity(0.4), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryItems(List<CooldownItem> items) {
    final cooldown = items.where((i) => i.isOnCooldown).toList()
      ..sort((a, b) => a.cooldownEnd!.compareTo(b.cooldownEnd!));
    final available = items.where((i) => !i.isOnCooldown).toList();
    return [
      ...cooldown.map(_buildCooldownTile),
      ...available.map(_buildAvailableTile),
    ];
  }

  Widget _buildSummaryCard(int availCount, int coolCount) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildStatChip(
            availCount.toString(),
            "Available",
            AppColors.govGreen,
            Icons.check_circle,
          ),
          const Spacer(),
          Container(width: 1, height: 36, color: AppColors.slate600),
          const Spacer(),
          _buildStatChip(
            coolCount.toString(),
            "Cooling",
            AppColors.govGold,
            Icons.hourglass_bottom_rounded,
          ),
          const Spacer(),
          Container(width: 1, height: 36, color: AppColors.slate600),
          const Spacer(),
          _buildStatChip(
            _controller.items.length.toString(),
            "Total",
            const Color(0xFF06B6D4),
            Icons.inventory_2_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      String value, String label, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(value,
                style: AppTypography.headlineSmall.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.slate400)),
      ],
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: AppTypography.labelLarge
                  .copyWith(color: color, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: AppTypography.bodySmall.copyWith(color: color)),
          ),
          const Spacer(),
          Container(height: 1, width: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.4), Colors.transparent],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCooldownTile(CooldownItem item) {
    final accent = _accentColors[item.colorIndex % _accentColors.length];
    final progress = item.cooldownProgress;
    final progressColor = Color.lerp(AppColors.govGold, AppColors.error, progress)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('cd_${item.id}'),
        direction: DismissDirection.endToStart,
        background: _buildDismissBackground(
            Colors.green, Icons.check, Alignment.centerRight, 'Mark Ready'),
        confirmDismiss: (_) async {
          await _controller.clearCooldown(item);
          return false;
        },
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [progressColor, accent.withOpacity(0.4)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: SizedBox(
                    width: 44, height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: AppColors.slate700,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                        Icon(Icons.hourglass_bottom_rounded,
                            size: 18, color: progressColor),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: AppTypography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              item.readableRemaining,
                              style: AppTypography.bodyMedium.copyWith(
                                color: progressColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '→ ${_formatEnd(item.cooldownEnd!)}',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.slate400),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: AppColors.slate400, size: 20),
                  color: AppColors.slate800,
                  onSelected: (v) {
                    if (v == 'ready') _controller.clearCooldown(item);
                    if (v == 'edit') _showEditSheet(context, item);
                    if (v == 'delete') _confirmDelete(item);
                  },
                  itemBuilder: (_) => [
                    _popupItem('ready', Icons.check_circle, 'Mark Ready',
                        AppColors.govGreen),
                    _popupItem('edit', Icons.edit, 'Edit', AppColors.slate300),
                    _popupItem('delete', Icons.delete_outline, 'Delete',
                        AppColors.error),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableTile(CooldownItem item) {
    final accent = _accentColors[item.colorIndex % _accentColors.length];
    final justReady = _controller.justBecameAvailable.contains(item.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('av_${item.id}'),
        direction: DismissDirection.startToEnd,
        background: _buildDismissBackground(
            const Color(0xFF06B6D4), Icons.timer, Alignment.centerLeft,
            'Start Cooldown'),
        confirmDismiss: (_) async {
          await _startCooldown(item);
          return false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: justReady
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.govGreen.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                )
              : null,
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                      color: AppColors.govGreen.withOpacity(0.7),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.govGreen.withOpacity(0.12),
                      ),
                      child: Icon(Icons.check_rounded,
                          color: AppColors.govGreen, size: 22),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: AppTypography.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.govGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                justReady ? 'Just became ready!' : 'Ready to use',
                                style: AppTypography.bodySmall.copyWith(
                                  color: justReady
                                      ? AppColors.govGreen
                                      : AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                            color: accent.withOpacity(0.5), blurRadius: 6)
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: AppColors.slate400, size: 20),
                    color: AppColors.slate800,
                    onSelected: (v) {
                      if (v == 'cooldown') _startCooldown(item);
                      if (v == 'edit') _showEditSheet(context, item);
                      if (v == 'delete') _confirmDelete(item);
                    },
                    itemBuilder: (_) => [
                      _popupItem('cooldown', Icons.timer, 'Start Cooldown',
                          const Color(0xFF06B6D4)),
                      _popupItem(
                          'edit', Icons.edit, 'Edit', AppColors.slate300),
                      _popupItem('delete', Icons.delete_outline, 'Delete',
                          AppColors.error),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(
      Color color, IconData icon, Alignment align, String label) {
    return Container(
      alignment: align,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (align == Alignment.centerLeft) ...[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: AppTypography.labelLarge.copyWith(color: color)),
          if (align == Alignment.centerRight) ...[
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 22),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label,
              style: AppTypography.bodyMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  String _formatEnd(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final isTomorrow = dt.difference(DateTime(now.year, now.month, now.day)).inDays == 1;

    if (isToday) return 'Today ${DateFormat.jm().format(dt)}';
    if (isTomorrow) return 'Tomorrow ${DateFormat.jm().format(dt)}';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Future<void> _confirmDelete(CooldownItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${item.name}"?',
            style: AppTypography.titleMedium),
        content: Text('This action cannot be undone.',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.slate400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) _controller.deleteItem(item.id!);
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final result = await showModalBottomSheet<CooldownItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditSheet(),
    );
    if (result != null) await _controller.addItem(result);
  }

  Future<void> _showEditSheet(
      BuildContext context, CooldownItem item) async {
    final result = await showModalBottomSheet<CooldownItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditSheet(existing: item),
    );
    if (result != null) await _controller.updateItem(result);
  }

  Future<DateTime?> _showCooldownPicker(
      BuildContext context, String itemName) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CooldownPickerSheet(itemName: itemName),
    );
  }
}

class _AddEditSheet extends StatefulWidget {
  final CooldownItem? existing;
  const _AddEditSheet({this.existing});

  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _categoryCtrl;
  int _colorIndex = 0;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.existing != null;
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _categoryCtrl =
        TextEditingController(text: widget.existing?.category ?? '');
    _colorIndex = widget.existing?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate900.withOpacity(0.97),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isEdit ? 'Edit Item' : 'Add Cooldown Item',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Item name',
                    hintStyle: AppTypography.bodyLarge
                        .copyWith(color: AppColors.slate500),
                    filled: true,
                    fillColor: AppColors.slate800.withOpacity(0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    prefixIcon: Icon(Icons.label_outline,
                        color: _accentColors[_colorIndex]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoryCtrl,
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Category (optional)',
                    hintStyle: AppTypography.bodyLarge
                        .copyWith(color: AppColors.slate500),
                    filled: true,
                    fillColor: AppColors.slate800.withOpacity(0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    prefixIcon: Icon(Icons.folder_outlined,
                        color: AppColors.slate400),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Color Tag',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.slate400)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    _accentColors.length,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32, height: 32,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: _accentColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorIndex == i
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: _colorIndex == i
                              ? [
                                  BoxShadow(
                                    color:
                                        _accentColors[i].withOpacity(0.5),
                                    blurRadius: 10,
                                  )
                                ]
                              : null,
                        ),
                        child: _colorIndex == i
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isEdit ? 'Save Changes' : 'Add Item',
                      style: AppTypography.labelLarge
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final cat = _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();

    final item = widget.existing != null
        ? widget.existing!.copyWith(name: name, colorIndex: _colorIndex, category: cat, clearCategory: cat == null)
        : CooldownItem(name: name, colorIndex: _colorIndex, category: cat);

    Navigator.pop(context, item);
  }
}

enum _PickMode { dateOnly, timeOnly, dateAndTime }

class _CooldownPickerSheet extends StatefulWidget {
  final String itemName;
  const _CooldownPickerSheet({required this.itemName});

  @override
  State<_CooldownPickerSheet> createState() => _CooldownPickerSheetState();
}

class _CooldownPickerSheetState extends State<_CooldownPickerSheet> {
  _PickMode _mode = _PickMode.dateAndTime;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate900.withOpacity(0.97),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Set Cooldown',
                    style: AppTypography.titleLarge),
                const SizedBox(height: 4),
                Text('for "${widget.itemName}"',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.slate400)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildModeChip('Date', _PickMode.dateOnly, Icons.calendar_today),
                    const SizedBox(width: 8),
                    _buildModeChip('Time', _PickMode.timeOnly, Icons.access_time),
                    const SizedBox(width: 8),
                    _buildModeChip('Both', _PickMode.dateAndTime, Icons.date_range),
                  ],
                ),
                const SizedBox(height: 20),
                if (_mode != _PickMode.timeOnly)
                  _buildPickerButton(
                    icon: Icons.calendar_today,
                    label: DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                    onTap: _pickDate,
                  ),
                if (_mode == _PickMode.dateAndTime)
                  const SizedBox(height: 12),
                if (_mode != _PickMode.dateOnly)
                  _buildPickerButton(
                    icon: Icons.access_time,
                    label: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Color(0xFF06B6D4)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cooldown until ${_formatPreview()}',
                          style: AppTypography.bodySmall
                              .copyWith(color: const Color(0xFF06B6D4)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text('Start Cooldown',
                        style: AppTypography.labelLarge
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildModeChip(String label, _PickMode mode, IconData icon) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF06B6D4).withOpacity(0.15)
                : AppColors.slate800.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF06B6D4).withOpacity(0.4)
                  : AppColors.slate700.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected
                      ? const Color(0xFF06B6D4)
                      : AppColors.slate400),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTypography.bodySmall.copyWith(
                    color: selected
                        ? const Color(0xFF06B6D4)
                        : AppColors.slate400,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.slate800.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.slate300),
            const SizedBox(width: 12),
            Text(label, style: AppTypography.bodyLarge),
            const Spacer(),
            Icon(Icons.chevron_right, color: AppColors.slate500, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatPreview() {
    final dt = _buildDateTime();
    return DateFormat('EEE, MMM d, yyyy – h:mm a').format(dt);
  }

  DateTime _buildDateTime() {
    switch (_mode) {
      case _PickMode.dateOnly:
        return DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day,
            23, 59, 59);
      case _PickMode.timeOnly:
        final now = DateTime.now();
        var dt = DateTime(
            now.year, now.month, now.day,
            _selectedTime.hour, _selectedTime.minute);
        if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
        return dt;
      case _PickMode.dateAndTime:
        return DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day,
            _selectedTime.hour, _selectedTime.minute);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF06B6D4),
            onPrimary: Colors.white,
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF06B6D4),
            onPrimary: Colors.white,
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _confirm() {
    final dt = _buildDateTime();
    if (dt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please pick a future date/time',
              style: AppTypography.bodyMedium),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    Navigator.pop(context, dt);
  }
}
