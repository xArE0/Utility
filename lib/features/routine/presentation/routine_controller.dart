import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/routine_entities.dart';
import '../data/local_routine_repository.dart';
import '../../../services/notification_service.dart';

class RoutineController extends ChangeNotifier {
  final LocalRoutineRepository _repo;

  RoutineController({required LocalRoutineRepository repository})
      : _repo = repository;

  List<Habit> _habits = [];
  Set<int> _todayCompletedIds = {};
  Map<int, List<String>> _allLogsByHabit = {}; // habitId → list of date strings
  Set<int> _bellArmedIds = {}; // habits with notification armed for today
  bool _initialized = false;

  List<Habit> get habits => _habits;
  bool get initialized => _initialized;
  int get totalHabits => _habits.length;
  int get completedToday => _todayCompletedIds.length;
  double get todayProgress =>
      totalHabits == 0 ? 0 : completedToday / totalHabits;

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool isCompletedToday(int habitId) => _todayCompletedIds.contains(habitId);
  bool isBellArmed(int habitId) => _bellArmedIds.contains(habitId);

  Future<void> init() async {
    await _repo.init();
    await _loadBellState();
    await _refresh();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadBellState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('routine_bell_date');
    if (savedDate == _todayStr) {
      final ids = prefs.getStringList('routine_bell_ids') ?? [];
      _bellArmedIds = ids.map((s) => int.parse(s)).toSet();
    } else {
      // New day — clear bell state
      _bellArmedIds = {};
      await prefs.setString('routine_bell_date', _todayStr);
      await prefs.setStringList('routine_bell_ids', []);
    }
  }

  Future<void> _saveBellState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('routine_bell_date', _todayStr);
    await prefs.setStringList(
        'routine_bell_ids', _bellArmedIds.map((id) => id.toString()).toList());
  }

  Future<void> _refresh() async {
    _habits = await _repo.getAllHabits();

    // Today's completions
    final todayLogs = await _repo.getLogsForDate(_todayStr);
    _todayCompletedIds = todayLogs.map((l) => l.habitId).toSet();

    // All logs for streak / heatmap calculations
    final allLogs = await _repo.getAllLogs();
    _allLogsByHabit = {};
    for (final log in allLogs) {
      _allLogsByHabit.putIfAbsent(log.habitId, () => []).add(log.date);
    }

    notifyListeners();
  }

  // ── Streak calculation ──

  int getStreak(int habitId) {
    final dates = _allLogsByHabit[habitId];
    if (dates == null || dates.isEmpty) return 0;

    final sorted = dates.map((d) => DateTime.parse(d)).toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    final today = DateTime.parse(_todayStr);
    int streak = 0;

    // Start from today or yesterday
    DateTime expected = today;
    if (sorted.first.isBefore(today)) {
      // Didn't do it today yet — check from yesterday
      expected = today.subtract(const Duration(days: 1));
    }

    for (final d in sorted) {
      if (d == expected ||
          (d.year == expected.year &&
              d.month == expected.month &&
              d.day == expected.day)) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (d.isBefore(expected)) {
        break;
      }
    }
    return streak;
  }

  int getBestStreak(int habitId) {
    final dates = _allLogsByHabit[habitId];
    if (dates == null || dates.isEmpty) return 0;

    final sorted = dates.map((d) => DateTime.parse(d)).toList()..sort();
    int best = 1, current = 1;

    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > best) best = current;
      } else if (diff > 1) {
        current = 1;
      }
    }
    return best;
  }

  // ── Heatmap data ──

  Map<String, int> getHeatmapData() {
    final Map<String, int> map = {};
    for (final logs in _allLogsByHabit.values) {
      for (final date in logs) {
        map[date] = (map[date] ?? 0) + 1;
      }
    }
    return map;
  }

  Set<String> getCompletionDates(int habitId) {
    return (_allLogsByHabit[habitId] ?? []).toSet();
  }

  // ── Actions ──

  Future<void> toggleHabit(int habitId) async {
    await _repo.toggleLog(habitId, _todayStr);
    await _refresh();
  }

  Future<void> addHabit(String name, String emoji, {String? scheduledTime}) async {
    final habit = Habit(
      name: name,
      emoji: emoji,
      sortOrder: _habits.length,
      scheduledTime: scheduledTime,
    );
    await _repo.addHabit(habit);
    await _refresh();
  }

  Future<void> updateHabit(int id, String name, String emoji, {String? scheduledTime, bool clearTime = false}) async {
    final existing = _habits.firstWhere((h) => h.id == id);
    await _repo.updateHabit(existing.copyWith(
      name: name,
      emoji: emoji,
      scheduledTime: scheduledTime,
      clearTime: clearTime,
    ));
    await _refresh();
  }

  Future<void> deleteHabit(int id) async {
    await NotificationService().cancelHabitReminder(id);
    _bellArmedIds.remove(id);
    await _saveBellState();
    await _repo.deleteHabit(id);
    await _refresh();
  }

  // ── Bell / Notification ──

  /// Toggle the bell for a habit: arm → schedule notif, disarm → cancel notif
  Future<bool> toggleBell(int habitId) async {
    final habit = _habits.firstWhere((h) => h.id == habitId);
    if (habit.scheduledTime == null) return false;

    final parts = habit.scheduledTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    if (_bellArmedIds.contains(habitId)) {
      // Disarm
      _bellArmedIds.remove(habitId);
      await NotificationService().cancelHabitReminder(habitId);
      await _saveBellState();
      notifyListeners();
      return false;
    } else {
      // Arm — schedule for today
      _bellArmedIds.add(habitId);
      await NotificationService().scheduleHabitReminder(
          habitId, habit.name, habit.emoji, hour, minute);
      await _saveBellState();
      notifyListeners();
      return true;
    }
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }
}
