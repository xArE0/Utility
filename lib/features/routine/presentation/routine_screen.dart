import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/local_routine_repository.dart';
import '../domain/routine_entities.dart';
import 'routine_controller.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});
  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> with SingleTickerProviderStateMixin {
  late final RoutineController _ctrl;
  late final TabController _tabCtrl;

  static const _emojis = [
    '💪','📖','🧘','🏃','💧','🍎','😴','✍️',
    '🎯','🧹','💊','🎨','🎵','🌅','🧠','🚿',
    '🥗','📵','🐕','🧪','☕','🫁','🦷','✅',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = RoutineController(repository: LocalRoutineRepository());
    _ctrl.init();
    _ctrl.addListener(() { if (mounted) setState(() {}); });
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _ctrl.dispose(); _tabCtrl.dispose(); super.dispose(); }

  // ── Time picker helper ──
  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) => showTimePicker(
    context: context,
    initialTime: initial ?? const TimeOfDay(hour: 8, minute: 0),
  );

  String _fmtTime(String hhmm) {
    final p = hhmm.split(':');
    final h = int.parse(p[0]), m = int.parse(p[1]);
    final tod = TimeOfDay(hour: h, minute: m);
    final hr = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final ampm = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hr.toString()}:${m.toString().padLeft(2,'0')} $ampm';
  }

  // ── Add/Edit dialog ──
  void _showAddEditDialog({int? editId, String? editName, String? editEmoji, String? editTime}) {
    final nameCtrl = TextEditingController(text: editName ?? '');
    String emoji = editEmoji ?? '💪';
    String? time = editTime;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(editId == null ? 'New Habit' : 'Edit Habit', style: AppTypography.titleLarge),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl, autofocus: true,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Habit name', hintStyle: TextStyle(color: AppColors.slate400),
              filled: true, fillColor: AppColors.slate900.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Text('Pick an emoji', style: AppTypography.bodySmall.copyWith(color: AppColors.slate400)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _emojis.map((e) {
            final sel = e == emoji;
            return GestureDetector(
              onTap: () => ss(() => emoji = e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), width: 40, height: 40,
                decoration: BoxDecoration(
                  color: sel ? AppColors.govBlue.withOpacity(0.3) : AppColors.slate700.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: sel ? Border.all(color: AppColors.govBlue, width: 1.5) : null,
                ),
                alignment: Alignment.center,
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),
          // Time row
          Row(children: [
            Icon(Icons.schedule, color: AppColors.slate400, size: 18),
            const SizedBox(width: 8),
            Text('Scheduled time', style: AppTypography.bodySmall.copyWith(color: AppColors.slate400)),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                TimeOfDay? init;
                if (time != null) { final p = time!.split(':'); init = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])); }
                final picked = await _pickTime(init);
                if (picked != null) ss(() => time = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.slate700.withOpacity(0.5), borderRadius: BorderRadius.circular(10),
                ),
                child: Text(time != null ? _fmtTime(time!) : 'None',
                  style: TextStyle(color: time != null ? Colors.white : AppColors.slate500, fontSize: 13)),
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => ss(() => time = null),
                child: Icon(Icons.close, size: 16, color: AppColors.slate500),
              ),
            ],
          ]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              if (editId != null) {
                _ctrl.updateHabit(editId, name, emoji, scheduledTime: time, clearTime: time == null);
              } else {
                _ctrl.addHabit(name, emoji, scheduledTime: time);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.govBlue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(editId == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    ));
  }

  void _confirmDelete(int id, String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.slate800,
      title: Text('Delete "$name"?', style: AppTypography.titleLarge),
      content: Text('This removes all its history too.', style: AppTypography.bodyMedium),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () { Navigator.pop(ctx); _ctrl.deleteHabit(id); AppToast.show(context, 'Habit deleted'); },
          child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Routine', style: AppTypography.titleLarge),
        backgroundColor: AppColors.slate900.withOpacity(0.85),
        bottom: TabBar(controller: _tabCtrl, indicatorColor: AppColors.govBlue,
          labelColor: Colors.white, unselectedLabelColor: AppColors.slate400,
          tabs: const [Tab(text: 'Today'), Tab(text: 'History')]),
      ),
      body: !_ctrl.initialized ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabCtrl, children: [_buildTodayTab(), _buildHistoryTab()]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.govBlue, child: const Icon(Icons.add, color: Colors.white)),
    ));
  }

  // ═══════════════ TODAY TAB ═══════════════
  Widget _buildTodayTab() {
    if (_ctrl.habits.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌱', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text('No habits yet', style: AppTypography.titleLarge.copyWith(color: AppColors.slate300)),
        const SizedBox(height: 8),
        Text('Tap + to add your first habit', style: AppTypography.bodyMedium.copyWith(color: AppColors.slate500)),
      ]));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 80), children: [
      _ProgressRing(progress: _ctrl.todayProgress, completed: _ctrl.completedToday, total: _ctrl.totalHabits),
      const SizedBox(height: 24),
      ..._ctrl.habits.map((h) => _buildHabitCard(h)),
    ]);
  }

  Widget _buildHabitCard(Habit habit) {
    final done = _ctrl.isCompletedToday(habit.id!);
    final streak = _ctrl.getStreak(habit.id!);
    final hasTime = habit.scheduledTime != null;
    final bellOn = _ctrl.isBellArmed(habit.id!);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: done ? const Color(0xFF10B981).withOpacity(0.12) : AppColors.slate800.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? const Color(0xFF10B981).withOpacity(0.35) : AppColors.slate700.withOpacity(0.6)),
      ),
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _ctrl.toggleHabit(habit.id!),
        onLongPress: () => _showBottomOptions(habit),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
          // Checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 250), width: 28, height: 28,
            decoration: BoxDecoration(
              color: done ? const Color(0xFF10B981) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: done ? const Color(0xFF10B981) : AppColors.slate500, width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
          ),
          const SizedBox(width: 14),
          Text(habit.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          // Name + time subtitle
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(habit.name, style: AppTypography.titleMedium.copyWith(
              color: done ? AppColors.slate500 : Colors.white,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.slate400,
              decorationThickness: 2.5,
            )),
            if (hasTime) Text(_fmtTime(habit.scheduledTime!),
              style: TextStyle(fontSize: 11, color: AppColors.slate500)),
          ])),
          // Bell icon (only if time is set)
          if (hasTime)
            GestureDetector(
              onTap: () async {
                final armed = await _ctrl.toggleBell(habit.id!);
                if (mounted) AppToast.show(context, armed ? '🔔 Reminder set for ${_fmtTime(habit.scheduledTime!)}' : '🔕 Reminder cancelled');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bellOn ? const Color(0xFFFFA000).withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(bellOn ? Icons.notifications_active : Icons.notifications_none,
                  size: 20, color: bellOn ? const Color(0xFFFFA000) : AppColors.slate500),
              ),
            ),
          const SizedBox(width: 4),
          // Streak badge
          if (streak > 0) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.slate700.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text('$streak', style: AppTypography.bodySmall.copyWith(color: const Color(0xFFFFA000), fontWeight: FontWeight.bold)),
            ]),
          ),
        ])),
      )),
    );
  }

  void _showBottomOptions(Habit habit) {
    showModalBottomSheet(context: context, backgroundColor: AppColors.slate800,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.slate600, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.edit, color: AppColors.govGold),
          title: const Text('Edit', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(ctx); _showAddEditDialog(editId: habit.id, editName: habit.name, editEmoji: habit.emoji, editTime: habit.scheduledTime); }),
        ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          onTap: () { Navigator.pop(ctx); _confirmDelete(habit.id!, habit.name); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  // ═══════════════ HISTORY TAB ═══════════════
  Widget _buildHistoryTab() {
    if (_ctrl.habits.isEmpty) return Center(child: Text('Add habits to see history', style: AppTypography.bodyMedium.copyWith(color: AppColors.slate500)));
    final heatmap = _ctrl.getHeatmapData();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 80), children: [
      Text('CONSISTENCY', style: AppTypography.labelLarge.copyWith(color: AppColors.slate400, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      _HeatmapCalendar(data: heatmap, maxPerDay: _ctrl.totalHabits),
      const SizedBox(height: 28),
      Text('HABITS', style: AppTypography.labelLarge.copyWith(color: AppColors.slate400, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      ..._ctrl.habits.map((h) => _HabitHistoryRow(
        habit: h, streak: _ctrl.getStreak(h.id!), bestStreak: _ctrl.getBestStreak(h.id!),
        completionDates: _ctrl.getCompletionDates(h.id!))),
    ]);
  }
}

// ═══════════════ PROGRESS RING ═══════════════
class _ProgressRing extends StatelessWidget {
  final double progress; final int completed, total;
  const _ProgressRing({required this.progress, required this.completed, required this.total});
  @override
  Widget build(BuildContext context) {
    return Center(child: SizedBox(width: 120, height: 120, child: Stack(alignment: Alignment.center, children: [
      SizedBox(width: 120, height: 120, child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic,
        builder: (_, v, __) => CustomPaint(painter: _RingPainter(v)),
      )),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$completed/$total', style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(progress >= 1.0 ? '🎉 All done!' : 'today',
          style: AppTypography.bodySmall.copyWith(color: progress >= 1.0 ? const Color(0xFF10B981) : AppColors.slate400)),
      ]),
    ])));
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    canvas.drawCircle(center, radius, Paint()..color = AppColors.slate700.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 10);
    if (progress > 0) {
      final sweep = 2 * pi * progress;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(startAngle: -pi/2, endAngle: -pi/2+sweep, colors: const [Color(0xFF06B6D4), Color(0xFF10B981)]);
      canvas.drawArc(rect, -pi/2, sweep, false, Paint()..shader = gradient.createShader(rect)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

// ═══════════════ HEATMAP ═══════════════
class _HeatmapCalendar extends StatelessWidget {
  final Map<String, int> data; final int maxPerDay;
  const _HeatmapCalendar({required this.data, required this.maxPerDay});
  @override
  Widget build(BuildContext context) {
    const weeks = 15, cellSize = 16.0, gap = 3.0;
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final start = startOfWeek.subtract(Duration(days: (weeks - 1) * 7));
    // Month labels
    final monthLabels = <int, String>{};
    String? last;
    for (int w = 0; w < weeks; w++) {
      final m = DateFormat('MMM').format(start.add(Duration(days: w * 7)));
      if (m != last) { monthLabels[w] = m; last = m; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 16, child: Row(children: [
        const SizedBox(width: 24),
        ...List.generate(weeks, (w) => SizedBox(width: cellSize + gap,
          child: monthLabels.containsKey(w) ? Text(monthLabels[w]!, style: TextStyle(fontSize: 9, color: AppColors.slate500)) : null)),
      ])),
      ...List.generate(7, (di) {
        final labels = ['M','','W','','F','','S'];
        return Row(children: [
          SizedBox(width: 24, child: Text(labels[di], style: TextStyle(fontSize: 9, color: AppColors.slate500))),
          ...List.generate(weeks, (w) {
            final date = start.add(Duration(days: w * 7 + di));
            if (date.isAfter(today)) return SizedBox(width: cellSize + gap, height: cellSize + gap);
            final ds = DateFormat('yyyy-MM-dd').format(date);
            final count = data[ds] ?? 0;
            final intensity = maxPerDay > 0 ? (count / maxPerDay).clamp(0.0, 1.0) : 0.0;
            return Padding(padding: const EdgeInsets.all(gap / 2), child: Tooltip(message: '$ds: $count/$maxPerDay',
              child: Container(width: cellSize, height: cellSize, decoration: BoxDecoration(
                color: count == 0 ? AppColors.slate700.withOpacity(0.3) : Color.lerp(const Color(0xFF065F46), const Color(0xFF10B981), intensity),
                borderRadius: BorderRadius.circular(3)))));
          }),
        ]);
      }),
    ]);
  }
}

// ═══════════════ HABIT HISTORY ROW ═══════════════
class _HabitHistoryRow extends StatelessWidget {
  final Habit habit; final int streak, bestStreak; final Set<String> completionDates;
  const _HabitHistoryRow({required this.habit, required this.streak, required this.bestStreak, required this.completionDates});
  @override
  Widget build(BuildContext context) {
    const weeks = 8;
    final today = DateTime.now();
    final start = today.subtract(Duration(days: weeks * 7 - 1));
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.slate800.withOpacity(0.7), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate700.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(habit.emoji, style: const TextStyle(fontSize: 20)), const SizedBox(width: 10),
          Expanded(child: Text(habit.name, style: AppTypography.titleMedium.copyWith(color: Colors.white))),
          _badge('🔥', streak, const Color(0xFFFFA000)), const SizedBox(width: 8),
          _badge('⭐', bestStreak, AppColors.govGold),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 3, runSpacing: 3, children: List.generate(weeks * 7, (i) {
          final date = start.add(Duration(days: i));
          if (date.isAfter(today)) return const SizedBox(width: 6, height: 6);
          final done = completionDates.contains(DateFormat('yyyy-MM-dd').format(date));
          return Container(width: 6, height: 6, decoration: BoxDecoration(
            color: done ? const Color(0xFF10B981) : AppColors.slate700.withOpacity(0.4), borderRadius: BorderRadius.circular(2)));
        })),
      ]),
    );
  }
  Widget _badge(String icon, int value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 11)), const SizedBox(width: 3),
      Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}
