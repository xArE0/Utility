import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/static_background.dart';
import '../domain/logbook_entities.dart';
import '../data/local_logbook_repository.dart';
import 'logbook_controller.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  late final LogbookController _controller;
  int? _expandedEntryId;

  static const List<Color> _accentColors = [
    Color(0xFFFF6B35),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFFF43F5E),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _controller = LogbookController(repository: LocalLogbookRepository());
    _controller.init();
    _controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return _accentColors[0];
    }
  }

  // ─── Add / Edit Entry Dialog ───────────────────────────
  Future<void> _showEntryDialog({LogEntry? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    DateTime selectedDate = existing != null
        ? DateTime.parse(existing.startDate)
        : DateTime.now();
    Color selectedColor = existing != null
        ? _parseColor(existing.colorHex)
        : _accentColors[0];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing != null ? 'Edit Entry' : 'New Entry',
            style: AppTypography.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.slate600),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.govGreen),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category (optional)',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.slate600),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.govGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.slate600),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.govGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.slate600),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.govGreen, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMM dd, yyyy').format(selectedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _accentColors.map((c) => GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == c
                              ? Colors.white
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.slate400)),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final colorHex = '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
                final entry = LogEntry(
                  id: existing?.id,
                  title: titleCtrl.text.trim(),
                  startDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  colorHex: colorHex,
                  category: categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                );
                if (existing != null) {
                  _controller.updateEntry(entry);
                } else {
                  _controller.addEntry(entry);
                }
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.govGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(existing != null ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Checkpoint Dialog ─────────────────────────────────
  Future<void> _showCheckpointDialog(LogEntry entry) async {
    final noteCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Checkpoint', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset counter for "${entry.title}" to today?',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.slate300),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                labelStyle: TextStyle(color: AppColors.slate400),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.slate600),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.govGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.slate400)),
          ),
          FilledButton.icon(
            onPressed: () {
              _controller.checkpoint(
                entry,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.flag, size: 18),
            label: const Text('Checkpoint'),
            style: FilledButton.styleFrom(
              backgroundColor: _parseColor(entry.colorHex),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build Entry Card ──────────────────────────────────
  Widget _buildEntryCard(LogEntry entry) {
    final accent = _parseColor(entry.colorHex);
    final isExpanded = _expandedEntryId == entry.id;
    final elapsed = entry.elapsedDays;
    final hero = _controller.formatElapsedHero(elapsed);

    final totalDays = entry.totalDays;
    String totalIntervalText;
    if (totalDays == 0) {
      totalIntervalText = '0 days';
    } else if (totalDays < 7) {
      totalIntervalText = totalDays == 1 ? '1 day' : '$totalDays days';
    } else if (totalDays < 30) {
      final weeks = totalDays ~/ 7;
      final days = totalDays % 7;
      totalIntervalText = days == 0 ? '${weeks}w' : '${weeks}w ${days}d';
    } else if (totalDays < 365) {
      final months = totalDays ~/ 30;
      final remDays = totalDays % 30;
      totalIntervalText = remDays == 0 ? '${months}mo' : '${months}mo ${remDays}d';
    } else {
      final years = totalDays ~/ 365;
      final remDays = totalDays % 365;
      final months = remDays ~/ 30;
      totalIntervalText = months == 0 ? '${years}y' : '${years}y ${months}mo';
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Main card content
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _expandedEntryId = isExpanded ? null : entry.id;
              });
            },
            onLongPress: () => _showEntryDialog(existing: entry),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Row(
                children: [
                  // Accent bar
                  Container(
                    width: 5,
                    height: 80,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Day count — smart scaling
                  SizedBox(
                    width: 56,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hero['value']!,
                          style: AppTypography.displaySmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 34,
                          ),
                        ),
                        Text(
                          hero['unit']!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.slate400,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hero['sub']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              hero['sub']!,
                              style: AppTypography.bodySmall.copyWith(
                                color: accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Running for $totalIntervalText',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.slate400,
                          ),
                        ),
                        if (entry.category != null && entry.category!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entry.category!,
                                style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Checkpoint button
                  IconButton(
                    onPressed: () => _showCheckpointDialog(entry),
                    tooltip: 'Checkpoint',
                    icon: Icon(Icons.flag_outlined, color: accent, size: 22),
                  ),
                  // Delete button
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.slate800,
                          title: Text('Delete "${entry.title}"?', style: AppTypography.titleLarge),
                          content: Text('This will remove the entry and all its checkpoints.',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.slate300)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('Cancel', style: TextStyle(color: AppColors.slate400)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _controller.deleteEntry(entry.id!);
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline, color: AppColors.slate500, size: 20),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          // Expanded timeline detail
          if (isExpanded) ...[
            Divider(color: AppColors.slate700.withOpacity(0.5), height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: AppColors.slate400, size: 14),
                      const SizedBox(width: 6),
                      Text('Timeline',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.slate400,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Render checkpoints if any
                  if (entry.checkpoints.isNotEmpty)
                    ...entry.checkpoints.asMap().entries.map((e) {
                      final i = e.key;
                      final cp = e.value;
                      final cpDate = DateTime.parse(cp.date);
                      final prevDateStr = i < entry.checkpoints.length - 1
                          ? entry.checkpoints[i + 1].date
                          : entry.startDate;
                      final prevDate = DateTime.parse(prevDateStr);
                      final diffDays = DateTime(cpDate.year, cpDate.month, cpDate.day)
                          .difference(DateTime(prevDate.year, prevDate.month, prevDate.day))
                          .inDays;
                      
                      String intervalText;
                      if (diffDays == 0) {
                        intervalText = '0 days';
                      } else if (diffDays < 7) {
                        intervalText = diffDays == 1 ? '1 day' : '$diffDays days';
                      } else if (diffDays < 30) {
                        final weeks = diffDays ~/ 7;
                        final days = diffDays % 7;
                        intervalText = days == 0 ? '${weeks}w' : '${weeks}w ${days}d';
                      } else if (diffDays < 365) {
                        final months = diffDays ~/ 30;
                        final remDays = diffDays % 30;
                        intervalText = remDays == 0 ? '${months}mo' : '${months}mo ${remDays}d';
                      } else {
                        final years = diffDays ~/ 365;
                        final remDays = diffDays % 365;
                        final months = remDays ~/ 30;
                        intervalText = months == 0 ? '${years}y' : '${years}y ${months}mo';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('MMM dd, yyyy').format(cpDate),
                              style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              margin: const EdgeInsets.only(top: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+$intervalText',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (cp.note != null && cp.note!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '— ${cp.note}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.slate500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  // Always show the start date at the bottom to close the timeline
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: AppColors.slate500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('MMM dd, yyyy').format(DateTime.parse(entry.startDate)),
                          style: AppTypography.bodySmall.copyWith(color: AppColors.slate500),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.note != null && entry.note!.isNotEmpty
                                ? '— Started: ${entry.note}'
                                : '— Started log',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.slate600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Logbook', style: AppTypography.titleLarge),
          backgroundColor: AppColors.slate900.withOpacity(0.85),
        ),
        body: !_controller.initialized
            ? const Center(child: CircularProgressIndicator())
            : _controller.entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 64, color: AppColors.slate600),
                        const SizedBox(height: 16),
                        Text(
                          'No entries yet',
                          style: AppTypography.titleMedium.copyWith(color: AppColors.slate500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to start tracking',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.slate600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 80),
                    itemCount: _controller.entries.length,
                    itemBuilder: (context, index) {
                      return _buildEntryCard(_controller.entries[index]);
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showEntryDialog(),
          backgroundColor: AppColors.govGreen,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
