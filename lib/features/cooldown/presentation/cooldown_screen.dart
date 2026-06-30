import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
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

const _categoryIcons = [
  Icons.folder_outlined,
  Icons.rocket_launch_outlined,
  Icons.science_outlined,
  Icons.sports_esports_outlined,
  Icons.fitness_center_outlined,
  Icons.restaurant_outlined,
  Icons.shopping_bag_outlined,
  Icons.code_outlined,
  Icons.palette_outlined,
  Icons.music_note_outlined,
  Icons.favorite_outline,
  Icons.star_outline,
  Icons.bolt_outlined,
  Icons.auto_awesome_outlined,
  Icons.diamond_outlined,
  Icons.local_fire_department_outlined,
];

IconData _getCategoryIcon(int codePoint) {
  return _categoryIcons.firstWhere(
    (ic) => ic.codePoint == codePoint,
    orElse: () => Icons.folder_outlined,
  );
}

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

  Future<void> _startCooldown(CooldownItem item, {bool forceManual = false}) async {
    final cat = _controller.categoryForItem(item);
    if (cat != null && !forceManual) {
      // Has a category and not forcing manual — auto-start with category duration
      await _controller.startCategoryCooldown(item);
      if (mounted) {
        AppToast.show(context, '${item.name} → ${cat.readableDuration} cooldown',
            icon: Icons.timer);
      }
    } else {
      // No category or forcing manual — show manual picker
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      final result = await _showCooldownPicker(context, item.name);
      if (result != null) {
        await _controller.startCooldown(item, result);
      }
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
          actions: [
            IconButton(
              onPressed: () => _showCategoryManager(context),
              icon: const Icon(Icons.category_outlined, size: 22),
              tooltip: 'Manage Categories',
              color: const Color(0xFF06B6D4),
            ),
          ],
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
          if (_controller.allCategories.isEmpty) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showCategoryManager(context),
              icon: const Icon(Icons.category_outlined, size: 18),
              label: const Text('Set up categories first'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF06B6D4),
                side: BorderSide(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    final allCats = _controller.allCategories;
    final uncategorized = _controller.items.where((i) => i.categoryId == null).toList();
    final hasCategories = allCats.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildSummaryCard(
          _controller.available.length,
          _controller.onCooldown.length,
        ),
        const SizedBox(height: 20),
        if (hasCategories) ...[
          // Grouped by category
          for (final cat in allCats) ...[
            _buildCategoryGroupHeader(cat),
            ..._buildCategoryGroupItems(cat),
            const SizedBox(height: 16),
          ],
          // Uncategorized items
          if (uncategorized.isNotEmpty) ...[
            _buildUncategorizedHeader(),
            ..._buildItemList(uncategorized),
            const SizedBox(height: 16),
          ],
        ] else ...[
          // No categories — flat list
          ..._buildFlatList(),
        ],
      ],
    );
  }

  Widget _buildCategoryGroupHeader(CooldownCategory cat) {
    final accent = _accentColors[cat.colorIndex % _accentColors.length];
    final icon = _getCategoryIcon(cat.iconCodePoint);
    final itemsInCat = _controller.items
        .where((i) => i.categoryId == cat.id)
        .toList();
    final onCooldownCount = itemsInCat.where((i) => i.isOnCooldown).length;
    final availableCount = itemsInCat.length - onCooldownCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.name.toUpperCase(),
                    style: AppTypography.labelLarge.copyWith(
                      color: accent,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 12, color: AppColors.slate400),
                      const SizedBox(width: 4),
                      Text(
                        cat.readableDuration,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.slate400,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.slate600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$availableCount ready · $onCooldownCount cooling',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Swipe hint for available items
            if (availableCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.govGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_right_outlined, size: 14, color: AppColors.govGreen),
                    const SizedBox(width: 4),
                    Text(
                      'swipe',
                      style: AppTypography.micro.copyWith(
                        color: AppColors.govGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryGroupItems(CooldownCategory cat) {
    final itemsInCat = _controller.items
        .where((i) => i.categoryId == cat.id)
        .toList();
    if (itemsInCat.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'No items in this category',
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate600),
          ),
        ),
      ];
    }
    return _buildItemList(itemsInCat);
  }

  Widget _buildUncategorizedHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, size: 16, color: AppColors.slate500),
          const SizedBox(width: 8),
          Text(
            'UNCATEGORIZED',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.slate500,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.slate600.withOpacity(0.4), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFlatList() {
    final cooldown = _controller.onCooldown;
    final available = _controller.available;
    return [
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
    ];
  }

  List<Widget> _buildItemList(List<CooldownItem> items) {
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
    final cat = _controller.categoryForItem(item);

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
                        if (cat != null) ...[
                          const SizedBox(height: 4),
                          _buildCategoryBadge(cat),
                        ],
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: AppColors.slate400, size: 20),
                  color: AppColors.slate800,
                  onSelected: (v) async {
                    if (v == 'ready') _controller.clearCooldown(item);
                    if (v == 'edit') {
                      await Future.delayed(const Duration(milliseconds: 250));
                      _showEditSheet(context, item);
                    }
                    if (v == 'delete') {
                      await Future.delayed(const Duration(milliseconds: 250));
                      _confirmDelete(item);
                    }
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

  Widget _buildCategoryBadge(CooldownCategory cat) {
    final accent = _accentColors[cat.colorIndex % _accentColors.length];
    final icon = _getCategoryIcon(cat.iconCodePoint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 4),
          Text(
            cat.name,
            style: AppTypography.micro.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '· ${cat.readableDuration}',
            style: AppTypography.micro.copyWith(
              color: accent.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTile(CooldownItem item) {
    final accent = _accentColors[item.colorIndex % _accentColors.length];
    final justReady = _controller.justBecameAvailable.contains(item.id);
    final cat = _controller.categoryForItem(item);
    final hasCat = cat != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('av_${item.id}'),
        direction: DismissDirection.startToEnd,
        background: _buildDismissBackground(
            const Color(0xFF06B6D4),
            Icons.timer,
            Alignment.centerLeft,
            hasCat ? '${cat.readableDuration} Cooldown' : 'Start Cooldown'),
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
                          if (cat != null) ...[
                            const SizedBox(height: 4),
                            _buildCategoryBadge(cat),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (hasCat)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.swipe_right_outlined,
                        size: 16,
                        color: AppColors.slate600,
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
                    onSelected: (v) async {
                      if (v == 'cooldown') {
                        await Future.delayed(const Duration(milliseconds: 250));
                        _startCooldown(item, forceManual: true);
                      }
                      if (v == 'edit') {
                        await Future.delayed(const Duration(milliseconds: 250));
                        _showEditSheet(context, item);
                      }
                      if (v == 'delete') {
                        await Future.delayed(const Duration(milliseconds: 250));
                        _confirmDelete(item);
                      }
                    },
                    itemBuilder: (_) => [
                      _popupItem('cooldown', Icons.timer,
                          hasCat ? 'Cooldown (${cat.readableDuration})' : 'Start Cooldown',
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
      builder: (ctx) => _AddEditSheet(
        categories: _controller.allCategories,
      ),
    );
    if (result != null) await _controller.addItem(result);
  }

  Future<void> _showEditSheet(
      BuildContext context, CooldownItem item) async {
    final result = await showModalBottomSheet<CooldownItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditSheet(
        existing: item,
        categories: _controller.allCategories,
      ),
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

  Future<void> _showCategoryManager(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryManagerSheet(
        controller: _controller,
      ),
    );
    setState(() {}); // Refresh after managing categories
  }
}

// ─────────────────────────────────────────────
//  Category Manager Sheet
// ─────────────────────────────────────────────

class _CategoryManagerSheet extends StatefulWidget {
  final CooldownController controller;
  const _CategoryManagerSheet({required this.controller});

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.controller.allCategories;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.slate900.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Text('Categories', style: AppTypography.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => _showAddCategorySheet(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Color(0xFF06B6D4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Items in a category auto-cooldown when you swipe right',
              style: AppTypography.bodySmall.copyWith(color: AppColors.slate500),
            ),
          ),
          const SizedBox(height: 16),
          // List
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.category_outlined, size: 48,
                      color: AppColors.slate600),
                  const SizedBox(height: 12),
                  Text('No categories yet',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.slate500)),
                  const SizedBox(height: 8),
                  Text('Tap + to create one',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.slate600)),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildCategoryTile(cats[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(CooldownCategory cat) {
    final accent = _accentColors[cat.colorIndex % _accentColors.length];
    final icon = _getCategoryIcon(cat.iconCodePoint);
    final itemCount = widget.controller.items
        .where((i) => i.categoryId == cat.id)
        .length;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.2), accent.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name,
                    style: AppTypography.titleMedium.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 11, color: accent),
                          const SizedBox(width: 3),
                          Text(cat.readableDuration,
                              style: AppTypography.micro.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$itemCount items',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.slate500)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditCategorySheet(context, cat),
            icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.slate400),
          ),
          IconButton(
            onPressed: () => _confirmDeleteCategory(cat),
            icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategorySheet(BuildContext context) async {
    final result = await showModalBottomSheet<CooldownCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddEditCategorySheet(),
    );
    if (result != null) {
      await widget.controller.addCategory(result);
    }
  }

  Future<void> _showEditCategorySheet(BuildContext context, CooldownCategory cat) async {
    final result = await showModalBottomSheet<CooldownCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditCategorySheet(existing: cat),
    );
    if (result != null) {
      await widget.controller.updateCategoryData(result);
    }
  }

  Future<void> _confirmDeleteCategory(CooldownCategory cat) async {
    final itemCount = widget.controller.items
        .where((i) => i.categoryId == cat.id)
        .length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${cat.name}"?',
            style: AppTypography.titleMedium),
        content: Text(
            itemCount > 0
                ? '$itemCount items will become uncategorized. They won\'t be deleted.'
                : 'This action cannot be undone.',
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
    if (confirmed == true) {
      await widget.controller.deleteCategory(cat.id!);
    }
  }
}

// ─────────────────────────────────────────────
//  Add/Edit Category Sheet
// ─────────────────────────────────────────────

class _AddEditCategorySheet extends StatefulWidget {
  final CooldownCategory? existing;
  const _AddEditCategorySheet({this.existing});

  @override
  State<_AddEditCategorySheet> createState() => _AddEditCategorySheetState();
}

class _AddEditCategorySheetState extends State<_AddEditCategorySheet> {
  late TextEditingController _nameCtrl;
  int _colorIndex = 0;
  int _selectedIconIndex = 0;
  int _days = 0;
  int _hours = 0;
  int _minutes = 30;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.existing != null;
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _colorIndex = widget.existing?.colorIndex ?? 0;

    if (widget.existing != null) {
      final dur = widget.existing!.cooldownDuration;
      _days = dur.inDays;
      _hours = dur.inHours % 24;
      _minutes = dur.inMinutes % 60;

      // Find icon index
      final cp = widget.existing!.iconCodePoint;
      final idx = _categoryIcons.indexWhere((ic) => ic.codePoint == cp);
      _selectedIconIndex = idx >= 0 ? idx : 0;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final accent = _accentColors[_colorIndex % _accentColors.length];

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
        child: SingleChildScrollView(
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
                  _isEdit ? 'Edit Category' : 'New Category',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Set a name and default cooldown duration',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.slate500),
                ),
                const SizedBox(height: 20),
                // Name
                TextField(
                  controller: _nameCtrl,
                  autofocus: !_isEdit,
                  style: AppTypography.bodyLarge,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Category name (e.g. Antigravity)',
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
                    prefixIcon: Icon(
                      _categoryIcons[_selectedIconIndex],
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Duration
                Text('Cooldown Duration',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.slate300,
                    )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDurationSpinner('Days', _days, (v) => setState(() => _days = v), 365),
                    const SizedBox(width: 12),
                    _buildDurationSpinner('Hours', _hours, (v) => setState(() => _hours = v), 23),
                    const SizedBox(width: 12),
                    _buildDurationSpinner('Mins', _minutes, (v) => setState(() => _minutes = v), 59),
                  ],
                ),
                const SizedBox(height: 8),
                // Duration preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Swipe right on any item → auto ${_previewDuration()}',
                        style: AppTypography.bodySmall.copyWith(color: accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Icon picker
                Text('Icon',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.slate400)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    _categoryIcons.length,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _selectedIconIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _selectedIconIndex == i
                              ? accent.withOpacity(0.2)
                              : AppColors.slate800.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedIconIndex == i
                                ? accent.withOpacity(0.5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _categoryIcons[i],
                          size: 18,
                          color: _selectedIconIndex == i
                              ? accent
                              : AppColors.slate500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Color picker
                Text('Color',
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
                      _isEdit ? 'Save Changes' : 'Create Category',
                      style: AppTypography.labelLarge
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSpinner(String label, int value, ValueChanged<int> onChanged, int max) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.slate800.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () { if (value < max) onChanged(value + 1); },
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.slate300, size: 22),
              ),
            ),
            Text(
              value.toString().padLeft(2, '0'),
              style: AppTypography.headlineSmall.copyWith(
                color: const Color(0xFF06B6D4),
              ),
            ),
            Text(label,
                style: AppTypography.micro.copyWith(color: AppColors.slate500)),
            GestureDetector(
              onTap: () { if (value > 0) onChanged(value - 1); },
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.slate300, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewDuration() {
    final parts = <String>[];
    if (_days > 0) parts.add('$_days day${_days > 1 ? 's' : ''}');
    if (_hours > 0) parts.add('$_hours hour${_hours > 1 ? 's' : ''}');
    if (_minutes > 0) parts.add('$_minutes min${_minutes > 1 ? 's' : ''}');
    return parts.isEmpty ? '0 mins' : parts.join(' ');
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.show(context, 'Please enter a category name', isError: true);
      return;
    }

    final totalMinutes = (_days * 24 * 60) + (_hours * 60) + _minutes;
    if (totalMinutes <= 0) {
      AppToast.show(context, 'Duration must be greater than 0', isError: true);
      return;
    }

    final cat = widget.existing != null
        ? widget.existing!.copyWith(
            name: name,
            cooldownDuration: Duration(minutes: totalMinutes),
            colorIndex: _colorIndex,
            iconCodePoint: _categoryIcons[_selectedIconIndex].codePoint,
          )
        : CooldownCategory(
            name: name,
            cooldownDuration: Duration(minutes: totalMinutes),
            colorIndex: _colorIndex,
            iconCodePoint: _categoryIcons[_selectedIconIndex].codePoint,
          );

    Navigator.pop(context, cat);
  }
}

// ─────────────────────────────────────────────
//  Add/Edit Item Sheet (updated with category picker)
// ─────────────────────────────────────────────

class _AddEditSheet extends StatefulWidget {
  final CooldownItem? existing;
  final List<CooldownCategory> categories;
  const _AddEditSheet({this.existing, this.categories = const []});

  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  late TextEditingController _nameCtrl;
  int _colorIndex = 0;
  int? _selectedCategoryId;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.existing != null;
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _colorIndex = widget.existing?.colorIndex ?? 0;
    _selectedCategoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
                const SizedBox(height: 16),
                // Category picker
                if (widget.categories.isNotEmpty) ...[
                  Text('Category',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.slate400)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // "None" chip
                      _buildCategoryChip(null, 'None', Icons.inbox_outlined, AppColors.slate500),
                      // Category chips
                      ...widget.categories.map((cat) {
                        final accent = _accentColors[cat.colorIndex % _accentColors.length];
                        final icon = _getCategoryIcon(cat.iconCodePoint);
                        return _buildCategoryChip(cat.id, cat.name, icon, accent);
                      }),
                    ],
                  ),
                  if (_selectedCategoryId != null) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (ctx) {
                      final cat = widget.categories
                          .where((c) => c.id == _selectedCategoryId)
                          .firstOrNull;
                      if (cat == null) return const SizedBox.shrink();
                      final accent = _accentColors[cat.colorIndex % _accentColors.length];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Swipe right → auto ${cat.readableDuration} cooldown',
                                style: AppTypography.bodySmall.copyWith(color: accent),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                ],
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

  Widget _buildCategoryChip(int? catId, String label, IconData icon, Color color) {
    final isSelected = _selectedCategoryId == catId;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = catId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.slate800.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : AppColors.slate700.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppColors.slate500),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? color : AppColors.slate500,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    // Find category name for backward compat
    String? categoryName;
    if (_selectedCategoryId != null) {
      final cat = widget.categories
          .where((c) => c.id == _selectedCategoryId)
          .firstOrNull;
      categoryName = cat?.name;
    }

    final item = widget.existing != null
        ? widget.existing!.copyWith(
            name: name,
            colorIndex: _colorIndex,
            categoryId: _selectedCategoryId,
            clearCategoryId: _selectedCategoryId == null,
            category: categoryName,
            clearCategory: categoryName == null,
          )
        : CooldownItem(
            name: name,
            colorIndex: _colorIndex,
            categoryId: _selectedCategoryId,
            category: categoryName,
          );

    Navigator.pop(context, item);
  }
}

// ─────────────────────────────────────────────
//  Cooldown Picker Sheet (unchanged from original)
// ─────────────────────────────────────────────

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
      AppToast.show(context, 'Please pick a future date/time', isError: true);
      return;
    }
    Navigator.pop(context, dt);
  }
}
