import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../services/db_helper.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'dart:ui';
import '../../services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

class ScheduleScreen extends StatefulWidget {
  final bool showNepaliDates;
  final Function(bool)? onToggleNepali;

  const ScheduleScreen({
    super.key,
    this.showNepaliDates = false,
    this.onToggleNepali,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

enum ScheduleView { timeline, week, month }

class _ScheduleScreenState extends State<ScheduleScreen> {
  late bool _showNepaliDates;
  ScheduleView _viewMode = ScheduleView.timeline;

  static const int initialIndex = 10000;
  static final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat dayFormat = DateFormat('EEE');
  static final DateFormat numFormat = DateFormat('d');
  static final DateFormat monthFormat = DateFormat('MMM');

  final double itemExtent = 125.0;

  List<Event> _allEvents = [];
  List<Event> _allBirthdays = [];
  List<Event> _allExams = [];
  Set<String> _eventDates = {};
  Set<String> _birthdayMonthDays = {};
  Set<String> _examMonthDays = {};

  final ScrollController _scrollController = ScrollController();

  DateTime _selectedDate = DateTime.now();
  bool _isDragging = false;

  // Cache for Nepali dates to avoid repeated conversions
  final Map<String, NepaliDateTime> _nepaliDateCache = {};
  final Map<String, String> _nepaliMonthCache = {};
  final Map<String, String> _nepaliDayCache = {};
  
  // Loading state for Nepali date computation
  bool _isLoadingNepaliDates = false;

  Widget _buildViewSwitcher(bool isDark) {
    Color active = AppColors.govGreen;
    Color inactive = isDark ? AppColors.slate400 : AppColors.slate600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: "Timeline view",
          onPressed: () {
            setState(() => _viewMode = ScheduleView.timeline);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final idx = _indexFromDate(_selectedDate);
                _scrollController.jumpTo(idx * itemExtent);
              }
            });
          },
          icon: Icon(Icons.view_agenda,
              size: 20,
              color: _viewMode == ScheduleView.timeline ? active : inactive),
        ),
        IconButton(
          tooltip: "Week view",
          onPressed: () => setState(() => _viewMode = ScheduleView.week),
          icon: Icon(Icons.calendar_view_week,
              size: 20,
              color: _viewMode == ScheduleView.week ? active : inactive),
        ),
        IconButton(
          tooltip: "Month view",
          onPressed: () => setState(() => _viewMode = ScheduleView.month),
          icon: Icon(Icons.calendar_month,
              size: 20,
              color: _viewMode == ScheduleView.month ? active : inactive),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _showNepaliDates = widget.showNepaliDates;
    _preloadEvents().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final idx = _indexFromDate(_selectedDate);
        _scrollController.jumpTo(idx * itemExtent);
        setState(() {});
      });
    });
  }

  Future<void> _preloadEvents() async {
    final db = await DBHelper.database;
    final maps = await db.query('events');
    _allEvents = maps.map((e) => Event.fromMap(e)).toList();
    _allBirthdays = _allEvents.where((e) => e.type == 'birthday').toList();
    _allExams = _allEvents.where((e) => e.type == 'exam').toList();
    // _eventDates includes all non-birthday events (normal and exam)
    _eventDates = _allEvents
        .where((e) => e.type != 'birthday')
        .map((e) => e.date)
        .toSet();
    _birthdayMonthDays = _allBirthdays
        .map((e) {
      final d = DateTime.parse(e.date);
      return '${d.month}-${d.day}';
    })
        .toSet();
    setState(() {});
  }

  DateTime _dateFromIndex(int index) {
    final base = DateTime.now().subtract(Duration(days: initialIndex));
    return base.add(Duration(days: index));
  }

  int _indexFromDate(DateTime date) {
    final base = DateTime.now().subtract(Duration(days: initialIndex));
    return date.difference(base).inDays;
  }

  Map<String, String> _getNepaliDateInfo(DateTime date) {
    if (!_showNepaliDates) return {}; // Skip calculation if not visible

    final dateKey = dateFormat.format(date);

    if (!_nepaliMonthCache.containsKey(dateKey) || !_nepaliDayCache.containsKey(dateKey)) {
      try {
        final nepaliDate = date.toNepaliDateTime();
        _nepaliDateCache[dateKey] = nepaliDate;
        _nepaliMonthCache[dateKey] = NepaliUnicode.convert(NepaliDateFormat('MMMM').format(nepaliDate));
        _nepaliDayCache[dateKey] = NepaliUnicode.convert(NepaliDateFormat('d').format(nepaliDate));
      } catch (e) {
        // Fallback to English date if Nepali conversion fails
        _nepaliMonthCache[dateKey] = monthFormat.format(date);
        _nepaliDayCache[dateKey] = numFormat.format(date);
      }
    }

    return {
      'month': _nepaliMonthCache[dateKey]!,
      'day': _nepaliDayCache[dateKey]!,
    };
  }


  // Clear cache periodically to prevent memory leaks
  void _clearOldCache() {
    if (_nepaliDateCache.length > 200) {
      final keysToRemove = _nepaliDateCache.keys.take(50).toList();
      for (final key in keysToRemove) {
        _nepaliDateCache.remove(key);
        _nepaliMonthCache.remove(key);
        _nepaliDayCache.remove(key);
      }
    }
  }
  
  /// Pre-compute Nepali dates in batch using isolate to avoid UI lag
  Future<void> _precomputeNepaliDates(DateTime centerDate) async {
    setState(() => _isLoadingNepaliDates = true);
    
    try {
      // Generate list of dates to compute (60 days range)
      final datesToCompute = <String>[];
      for (int i = -30; i <= 30; i++) {
        final date = centerDate.add(Duration(days: i));
        final key = dateFormat.format(date);
        if (!_nepaliMonthCache.containsKey(key)) {
          datesToCompute.add(key);
        }
      }
      
      if (datesToCompute.isNotEmpty) {
        // Run conversion in isolate
        final results = await compute(_computeNepaliDatesBatch, datesToCompute);
        
        // Update cache with results
        for (final entry in results.entries) {
          _nepaliMonthCache[entry.key] = entry.value['month']!;
          _nepaliDayCache[entry.key] = entry.value['day']!;
        }
      }
    } catch (e) {
      debugPrint('Error precomputing Nepali dates: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingNepaliDates = false);
      }
    }
  }
  
  /// Static isolate function for batch Nepali date conversion
  static Map<String, Map<String, String>> _computeNepaliDatesBatch(List<String> dateKeys) {
    final results = <String, Map<String, String>>{};
    
    for (final key in dateKeys) {
      try {
        final date = DateTime.parse(key);
        final nepaliDate = date.toNepaliDateTime();
        results[key] = {
          'month': NepaliUnicode.convert(NepaliDateFormat('MMMM').format(nepaliDate)),
          'day': NepaliUnicode.convert(NepaliDateFormat('d').format(nepaliDate)),
        };
      } catch (e) {
        // Fallback to empty if conversion fails
        results[key] = {'month': '', 'day': ''};
      }
    }
    
    return results;
  }

  List<Event> _eventsForDate(DateTime date) {
    final key = dateFormat.format(date);
    List<Event> events = [];

    // Non-repeating events (single day)
    events.addAll(_allEvents.where((e) =>
    e.date == key &&
        e.type != 'birthday' &&
        e.type != 'exam' &&
        (e.repeat == null || e.repeat == "none") &&
        (e.durationDays == null || e.durationDays! <= 1)
    ));
    
    // Multi-day events that span this date
    events.addAll(_allEvents.where((e) {
      if (e.type == 'birthday' || e.type == 'exam') return false;
      if (e.durationDays == null || e.durationDays! <= 1) return false;
      return e.spansDate(date);
    }));

    // Repeating events (except for birthdays/exams)
    events.addAll(_allEvents.where((e) {
      if (e.repeat == null || e.repeat == "none") return false;
      if (e.type == 'birthday' || e.type == 'exam') return false;
      final eventDate = DateTime.parse(e.date);
      if (date.isBefore(eventDate)) return false;
      switch (e.repeat) {
        case "daily":
          return true;
        case "weekly":
          return date.weekday == eventDate.weekday;
        case "monthly":
          return date.day == eventDate.day;
        case "yearly":
          return date.month == eventDate.month && date.day == eventDate.day;
        case "custom":
          final interval = e.repeatInterval ?? 1;
          return date.difference(eventDate).inDays % interval == 0;
        default:
          return false;
      }
    }));

    // Birthdays (always repeating yearly)
    final bdays = _allBirthdays.where((e) {
      final d = DateTime.parse(e.date);
      return d.month == date.month && d.day == date.day;
    }).toList();

    // Exams only show on their exact date
    final exams = _allExams.where((e) => e.date == key).toList();

    return [...events, ...bdays, ...exams];
  }

  int? _findNearestEventIndex(int from, int direction) {
    final Set<int> normalIndices = _eventDates.map((d) {
      return _indexFromDate(DateTime.parse(d));
    }).toSet();

    final birthdayIndices = <int>{};
    for (var e in _allBirthdays) {
      final original = DateTime.parse(e.date);
      for (int y = _selectedDate.year - 2; y <= _selectedDate.year + 2; y++) {
        try {
          final recurring = DateTime(y, original.month, original.day);
          final idx = _indexFromDate(recurring);
          birthdayIndices.add(idx);
        } catch (_) {
          continue;
        }
      }
    }

    // Exams are one-time only - no year looping
    final examIndices = _allExams.map((e) {
      return _indexFromDate(DateTime.parse(e.date));
    }).toSet();

    final allIndices = {...normalIndices, ...birthdayIndices, ...examIndices}..remove(from);
    if (allIndices.isEmpty) return null;

    final sorted = allIndices.toList()..sort();

    if (direction > 0) {
      final found = sorted.where((i) => i > from).toList();
      return found.isNotEmpty ? found.first : null;
    } else {
      final found = sorted.where((i) => i < from).toList();
      return found.isNotEmpty ? found.last : null;
    }
  }

  void _jumpToEvent(int direction) async {
    final currentIndex = _indexFromDate(_selectedDate);
    final idx = _findNearestEventIndex(currentIndex, direction);
    if (idx != null && idx != currentIndex) {
      await _scrollController.animateTo(
        idx * itemExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      final date = _dateFromIndex(idx);
      setState(() => _selectedDate = date);
    }
  }

  void _jumpToDate(DateTime date) {
    final idx = _indexFromDate(date);
    setState(() => _selectedDate = date);
    _scrollController.animateTo(
      idx * itemExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _showAddEventDialog() {
    final taskController = TextEditingController();
    DateTime chosenDate = _selectedDate;
    String selectedType = 'normal';

    bool remindMe = false;
    int remindDaysBefore = 0;
    TimeOfDay? remindTime;

    // Repeat fields
    String repeat = "none";
    int repeatInterval = 1;
    
    // Duration field for multi-day events
    int durationDays = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          final inputFill = cs.surface.withOpacity(0.08);
          final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.primary.withOpacity(0.4), width: 1),
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: cs.surface.withOpacity(0.95),
            title: const Text("Add Schedule"),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: inputFill,
                      title: Text("Date: ${DateFormat('EEE, MMM d, yyyy').format(chosenDate)}"),
                      trailing: Icon(Icons.calendar_today, color: cs.primary),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: chosenDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDialogState(() => chosenDate = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Event Type',
                        filled: true,
                        fillColor: inputFill,
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border.copyWith(
                          borderSide: BorderSide(color: cs.primary, width: 1.2),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
                        DropdownMenuItem(value: 'exam', child: Text('Exam')),
                        DropdownMenuItem(value: 'homework', child: Text('Homework')),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                      ],
                      onChanged: (value) => setDialogState(() => selectedType = value!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: taskController,
                      decoration: InputDecoration(
                        labelText: "Description",
                        filled: true,
                        fillColor: inputFill,
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border.copyWith(
                          borderSide: BorderSide(color: cs.primary, width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: inputFill,
                      title: const Text("Remind Me"),
                      value: remindMe,
                      onChanged: (val) => setDialogState(() => remindMe = val),
                    ),
                    if (remindMe) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text("Days before:"),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: "$remindDaysBefore",
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: inputFill,
                                border: border,
                                enabledBorder: border,
                                focusedBorder: border.copyWith(
                                  borderSide: BorderSide(color: cs.primary, width: 1.2),
                                ),
                              ),
                              onChanged: (v) {
                                final num = int.tryParse(v) ?? 0;
                                setDialogState(() => remindDaysBefore = num.clamp(0, 365));
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("(today included)", style: TextStyle(color: theme.hintColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text("At: "),
                          Text(
                            remindTime == null ? "Select Time" : remindTime!.format(context),
                            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: Icon(Icons.access_time, color: cs.primary),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (t != null) setDialogState(() => remindTime = t);
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Repeat:"),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: repeat,
                            borderRadius: BorderRadius.circular(12),
                            items: const [
                              DropdownMenuItem(value: "none", child: Text("None")),
                              DropdownMenuItem(value: "daily", child: Text("Daily")),
                              DropdownMenuItem(value: "weekly", child: Text("Weekly")),
                              DropdownMenuItem(value: "monthly", child: Text("Monthly")),
                              DropdownMenuItem(value: "yearly", child: Text("Yearly")),
                              DropdownMenuItem(value: "custom", child: Text("Custom...")),
                            ],
                            onChanged: (v) => setDialogState(() => repeat = v!),
                          ),
                          if (repeat == "custom") ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 50,
                              child: TextFormField(
                                initialValue: "$repeatInterval",
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: inputFill,
                                  border: border,
                                  enabledBorder: border,
                                  focusedBorder: border.copyWith(
                                    borderSide: BorderSide(color: cs.primary, width: 1.2),
                                  ),
                                ),
                                onChanged: (v) {
                                  final num = int.tryParse(v) ?? 1;
                                  setDialogState(() => repeatInterval = num.clamp(1, 999));
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text("days"),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Duration field for multi-day events
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Duration:"),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: "$durationDays",
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: inputFill,
                                border: border,
                                enabledBorder: border,
                                focusedBorder: border.copyWith(
                                  borderSide: BorderSide(color: cs.primary, width: 1.2),
                                ),
                              ),
                              onChanged: (v) {
                                final num = int.tryParse(v) ?? 1;
                                setDialogState(() => durationDays = num.clamp(1, 365));
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            durationDays == 1 ? "day" : "days",
                            style: TextStyle(color: theme.hintColor),
                          ),
                          if (durationDays > 1) ...[
                            const SizedBox(width: 8),
                            Text(
                              "(ends ${DateFormat('MMM d').format(chosenDate.add(Duration(days: durationDays - 1)))})",
                              style: TextStyle(fontSize: 12, color: cs.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  final task = taskController.text.trim();
                  if (task.isNotEmpty) {
                    if (remindMe) {
                      await NotificationService().requestPermission();
                    }
                    
                    final newEvent = Event(
                      date: dateFormat.format(chosenDate),
                      task: task,
                      type: selectedType,
                      remindMe: remindMe,
                      remindDaysBefore: remindMe ? remindDaysBefore : null,
                      remindTime: remindMe && remindTime != null
                          ? remindTime!.format(context)
                          : null,
                      repeat: repeat,
                      repeatInterval: repeat == "custom" ? repeatInterval : null,
                      durationDays: durationDays > 1 ? durationDays : null,
                    );
                    
                    final eventId = await DBHelper.insertEvent(newEvent);
                    
                    if (remindMe && remindTime != null) {
                      final eventWithId = Event(
                        id: eventId,
                        date: newEvent.date,
                        task: newEvent.task,
                        type: newEvent.type,
                        remindMe: newEvent.remindMe,
                        remindDaysBefore: newEvent.remindDaysBefore,
                        remindTime: newEvent.remindTime,
                        repeat: newEvent.repeat,
                        repeatInterval: newEvent.repeatInterval,
                        durationDays: newEvent.durationDays,
                      );
                      await NotificationService().scheduleEventNotification(eventWithId);
                    }
                    
                    await _preloadEvents();
                    setState(() => _selectedDate = chosenDate);
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _moveEvent(Event event, DateTime newDate) async {
    final db = await DBHelper.database;
    await db.update(
      'events',
      {'date': dateFormat.format(newDate)},
      where: 'id = ?',
      whereArgs: [event.id],
    );
    await _preloadEvents();
  }

  Future<void> _deleteEvent(Event event) async {
    final db = await DBHelper.database;
    await db.delete('events', where: 'id = ?', whereArgs: [event.id]);
    // Cancel any scheduled notification for this event
    if (event.id != null) {
      await NotificationService().cancelEventNotification(event.id!);
    }
    await _preloadEvents();
  }

  Color _eventColor(Event event) {
    switch (event.type) {
      case 'birthday':
        return const Color(0xFFE91E63); // pink
      case 'exam':
        return const Color(0xFF2563EB); // blue
      case 'homework':
        return const Color(0xFF8B5CF6); // violet
      case 'event':
        return const Color(0xFFFFA000); // amber
      case 'normal':
      default:
        return const Color(0xFF10B981); // teal/green
    }
  }

  Widget _eventTypeIcon(String type) {
    switch (type) {
      case 'birthday':
        return const Row(
          children: [
            Icon(Icons.cake, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text("Birthday", style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        );
      case 'exam':
        return const Row(
          children: [
            Icon(Icons.school, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text("Exam", style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        );
      case 'event':
        return const Row(
          children: [
            Icon(Icons.event, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text("Event", style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        );
      case 'homework':
        return const Row(
          children: [
            Icon(Icons.assignment, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text("Homework", style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEventContainer(Event event, DateTime currentDate) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final base = _eventColor(event);
    // Blend to avoid neon blocks on dark/glass surfaces.
    final Color bg = isDark
        ? Color.alphaBlend(Colors.black.withOpacity(0.35), base).withOpacity(0.92)
        : base.withOpacity(0.92);
    final Color fg = bg.computeLuminance() > 0.55 ? Colors.black : Colors.white;
    final Color subtleFg = fg.withOpacity(0.88);

    final container = Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.task,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (event.type == 'birthday' || event.type == 'exam' || event.type == 'homework')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _eventTypeIcon(event.type),
            ),
          if (event.type == 'event')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _eventTypeIcon(event.type),
            ),
          if (event.remindMe == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.alarm, color: subtleFg, size: 14),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      "${event.remindDaysBefore ?? 0}d, ${event.remindTime ?? ''}",
                      style: TextStyle(color: subtleFg, fontSize: 11),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (event.repeat != null && event.repeat != "none")
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.repeat, color: subtleFg, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    event.repeat == "custom"
                        ? "Every ${event.repeatInterval ?? 1} days"
                        : (event.repeat![0].toUpperCase() + event.repeat!.substring(1)),
                    style: TextStyle(color: subtleFg, fontSize: 11),
                  ),
                ],
              ),
            ),
          // Multi-day indicator
          if (event.durationDays != null && event.durationDays! > 1)
            Builder(
              builder: (context) {
                final dayNum = event.getDayNumber(currentDate);
                if (dayNum != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: subtleFg, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          "Day $dayNum of ${event.durationDays}",
                          style: TextStyle(color: subtleFg, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );

    Widget feedbackContainer = Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120, minWidth: 80),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg.withOpacity(0.95),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.task,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
              if (event.remindMe == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.alarm, color: subtleFg, size: 12),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          "${event.remindDaysBefore ?? 0}d, ${event.remindTime ?? ''}",
                          style: TextStyle(color: subtleFg, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              if (event.repeat != null && event.repeat != "none")
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, color: subtleFg, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        event.repeat == "custom"
                            ? "Every ${event.repeatInterval ?? 1} days"
                            : (event.repeat![0].toUpperCase() + event.repeat!.substring(1)),
                        style: TextStyle(color: subtleFg, fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Widget childWhenDraggingContainer = Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.task,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (event.type == 'birthday' || event.type == 'exam' || event.type == 'homework')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _eventTypeIcon(event.type),
            ),
          if (event.type == 'event')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _eventTypeIcon(event.type),
            ),
          if (event.remindMe == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.alarm, color: subtleFg, size: 14),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      "${event.remindDaysBefore ?? 0}d, ${event.remindTime ?? ''}",
                      style: TextStyle(color: subtleFg, fontSize: 11),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (event.repeat != null && event.repeat != "none")
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.repeat, color: subtleFg, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    event.repeat == "custom"
                        ? "Every ${event.repeatInterval ?? 1} days"
                        : (event.repeat![0].toUpperCase() + event.repeat!.substring(1)),
                    style: TextStyle(color: subtleFg, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (event.type == 'normal' || event.type == 'homework') {
      return Draggable<Map<String, dynamic>>(
        data: {
          'event': event,
          'sourceDate': currentDate,
          'canMove': true,
        },
        feedback: feedbackContainer,
        childWhenDragging: childWhenDraggingContainer,
        onDragStarted: () {
          setState(() => _isDragging = true);
        },
        onDragEnd: (details) {
          setState(() => _isDragging = false);
        },
        child: container,
      );
    } else {
      return Draggable<Map<String, dynamic>>(
        data: {
          'event': event,
          'sourceDate': currentDate,
          'canMove': false,
        },
        feedback: feedbackContainer,
        childWhenDragging: childWhenDraggingContainer,
        onDragStarted: () {
          setState(() => _isDragging = true);
        },
        onDragEnd: (details) {
          setState(() => _isDragging = false);
        },
        child: container,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = dateFormat.format(today);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    // Page-specific surfaces for a nicer dark look.
    final Color headerSurface = (isDark ? AppColors.slate900 : Colors.white).withOpacity(0.55);
    final Color bodySurface = (isDark ? AppColors.slate900 : Colors.white).withOpacity(0.35);
    final Color dividerColor = (isDark ? AppColors.slate800 : AppColors.slate200).withOpacity(0.8);
    final Color secondaryText = isDark ? AppColors.slate400 : AppColors.slate600;

    // Clear old cache periodically
    _clearOldCache();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassCard(
              borderRadius: BorderRadius.circular(24),
              padding: EdgeInsets.zero,
              child: _viewMode == ScheduleView.timeline
                  ? NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          final offset = notification.metrics.pixels;
                          final index = (offset / itemExtent).round();
                          final newDate = _dateFromIndex(index);
                          if (!isSameDay(_selectedDate, newDate)) {
                            setState(() {
                              _selectedDate = newDate;
                            });
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemExtent: itemExtent,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        itemBuilder: (context, index) {
                          final date = _dateFromIndex(index);
                          final key = dateFormat.format(date);
                          final isToday = key == todayKey;
                          final events = _eventsForDate(date);
                          String nepaliMonth = '';
                          String nepaliDay = '';
                          if (_showNepaliDates) {
                            final nepaliInfo = _getNepaliDateInfo(date);
                            nepaliMonth = nepaliInfo['month'] ?? '';
                            nepaliDay = nepaliInfo['day'] ?? '';
                          }
                          final dateOnly = DateTime(date.year, date.month, date.day);
                          final dayDiff = dateOnly.difference(today).inDays;
                          String diffText;
                          if (dayDiff == 0) {
                            diffText = "Today";
                          } else if (dayDiff == -1) {
                            diffText = "Yesterday";
                          } else if (dayDiff == 1) {
                            diffText = "Tomorrow";
                          } else if (dayDiff < 0) {
                            diffText = "${-dayDiff} days ago";
                          } else {
                            diffText = "in $dayDiff days";
                          }

                          return DragTarget<Map<String, dynamic>>(
                            onWillAccept: (data) {
                              return data != null && (data['canMove'] == true);
                            },
                            onAccept: (data) async {
                              final event = data['event'] as Event;
                              final sourceDate = data['sourceDate'] as DateTime;
                              if (!isSameDay(sourceDate, date)) {
                                await _moveEvent(event, date);
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHighlighted = candidateData.isNotEmpty;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: dividerColor, width: 1),
                                  ),
                                  color: isHighlighted
                                      ? AppColors.govGreen.withOpacity(isDark ? 0.18 : 0.12)
                                      : (isToday ? cs.primary.withOpacity(isDark ? 0.12 : 0.06) : null),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.only(top: 12, bottom: 2),
                                      color: headerSurface,
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          Text(
                                            monthFormat.format(date),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isToday ? AppColors.govGreen : secondaryText,
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            numFormat.format(date),
                                            style: TextStyle(
                                              fontSize: 32,
                                              color: isToday ? AppColors.govGreen : (isDark ? AppColors.slate50 : AppColors.slate800),
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            dayFormat.format(date),
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isToday ? AppColors.govGreen : secondaryText,
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            diffText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: Container(
                                        color: bodySurface,
                                        child: events.isEmpty
                                            ? const SizedBox.expand()
                                            : ListView.builder(
                                                itemCount: events.length,
                                                padding: EdgeInsets.zero,
                                                itemBuilder: (context, i) {
                                                  final e = events[i];
                                                  return _buildEventContainer(e, date);
                                                },
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: _showNepaliDates ? 0 : 85),
                                    if (_showNepaliDates)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 85, top: 4),
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                            decoration: BoxDecoration(
                                              color: (isDark ? AppColors.slate800 : Colors.white).withOpacity(isDark ? 0.55 : 0.6),
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(
                                                color: isToday
                                                    ? AppColors.govGreen.withOpacity(0.9)
                                                    : (isDark ? AppColors.slate700 : AppColors.slate200).withOpacity(0.7),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: _isLoadingNepaliDates && nepaliMonth.isEmpty
                                                ? const SizedBox(
                                                    height: 45,
                                                    width: 45,
                                                    child: Center(
                                                      child: SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.teal,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        nepaliMonth,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: isToday
                                                              ? AppColors.govGreen
                                                              : (isDark ? AppColors.slate300 : Colors.grey.shade700),
                                                          fontWeight: FontWeight.w600,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        nepaliDay,
                                                        style: TextStyle(
                                                          fontSize: 25,
                                                          color: isToday
                                                              ? (isDark ? AppColors.slate50 : AppColors.slate900)
                                                              : (isDark ? AppColors.slate50 : Colors.grey.shade900),
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    )
                  : (_viewMode == ScheduleView.week ? _buildWeekView(cs, isDark, today, todayKey) : _buildMonthView(cs, isDark, today, todayKey)),
            ),
          ),
          if (_isDragging)
            Positioned(
              left: 16,
              bottom: 110, // Back down slightly since the row is more compact
              child: DragTarget<Map<String, dynamic>>(
                onWillAccept: (data) {
                  return data != null;
                },
                onAccept: (data) async {
                  final event = data['event'] as Event;
                  await _deleteEvent(event);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHighlighted ? Colors.red.shade600 : Colors.red.shade400,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: isHighlighted ? 32 : 24,
                    ),
                  );
                },
              ),
            ),
          Positioned(
            left: 16,
            bottom: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Navigation Island (First)
                _buildIsland(
                  isDark: isDark,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "Previous event",
                        onPressed: () => _jumpToEvent(-1),
                        icon: const Icon(Icons.chevron_left, size: 20),
                      ),
                      IconButton(
                        tooltip: "Today",
                        onPressed: () => _jumpToDate(DateTime.now()),
                        icon: Icon(Icons.today, color: AppColors.govGreen, size: 20),
                      ),
                      IconButton(
                        tooltip: "Next event",
                        onPressed: () => _jumpToEvent(1),
                        icon: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // View Switcher Island (Second)
                _buildIsland(
                  isDark: isDark,
                  child: _buildViewSwitcher(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(
                color: AppColors.govGreen.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _showAddEventDialog,
              icon: const Icon(Icons.add),
              color: AppColors.govGreen,
              iconSize: 30,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showNepaliDates != oldWidget.showNepaliDates) {
      _showNepaliDates = widget.showNepaliDates;
      if (_showNepaliDates) {
        _precomputeNepaliDates(_selectedDate);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nepaliDateCache.clear();
    _nepaliMonthCache.clear();
    _nepaliDayCache.clear();
    super.dispose();
  }

  Widget _buildIsland({required bool isDark, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.slate800 : Colors.white).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: (isDark ? AppColors.slate700 : AppColors.slate300).withOpacity(0.8),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildEventsListForSelected(ColorScheme cs) {
    final events = _eventsForDate(_selectedDate);
    if (events.isEmpty) {
      return Center(
        child: Text(
          "No events",
          style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          events.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildEventContainer(events[i], _selectedDate),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekView(ColorScheme cs, bool isDark, DateTime today, String todayKey) {
    // startOfWeek should be Sunday
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Week of ${DateFormat('MMM d, yyyy').format(startOfWeek)}",
                style: TextStyle(
                  color: isDark ? AppColors.slate200 : AppColors.slate800,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: "Previous week",
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                      });
                    },
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  IconButton(
                    tooltip: "Next week",
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 7));
                      });
                    },
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: Row(
            children: days.map((date) {
              final key = dateFormat.format(date);
              final isToday = key == todayKey;
              final events = _eventsForDate(date);
              final isSelected = isSameDay(_selectedDate, date);

              String nepaliMonth = '';
              String nepaliDay = '';
              if (_showNepaliDates) {
                final nepaliInfo = _getNepaliDateInfo(date);
                nepaliMonth = nepaliInfo['month'] ?? '';
                nepaliDay = nepaliInfo['day'] ?? '';
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withOpacity(0.15)
                          : (isToday ? cs.primary.withOpacity(0.08) : cs.surface.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? AppColors.govGreen : cs.outline.withOpacity(0.4),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('E').format(date),
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isToday ? AppColors.govGreen : cs.onSurface,
                          ),
                        ),
                        if (_showNepaliDates && nepaliDay.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            nepaliDay,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 20,
                          child: events.isNotEmpty
                              ? Wrap(
                                  spacing: 2,
                                  runSpacing: 2,
                                  alignment: WrapAlignment.center,
                                  children: events.take(2).map((e) {
                                    return Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _eventColor(e),
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }).toList(),
                                )
                              : Center(
                                  child: Opacity(
                                    opacity: 0.3,
                                    child: Icon(Icons.event_note, size: 14, color: cs.onSurface),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
            child: _buildEventsListForSelected(cs),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView(ColorScheme cs, bool isDark, DateTime today, String todayKey) {
    final firstOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    // Adjust start day to Sunday (0 in our grid logic if Sunday is first)
    // firstOfMonth.weekday: 1 (Mon) -> 7 (Sun)
    // We want Mon=1, Tue=2, ..., Sat=6, Sun=0 for 0-indexed Sunday start
    final startWeekday = firstOfMonth.weekday % 7; 
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final cells = rows * 7;
    final dates = List<DateTime?>.generate(cells, (i) {
      final dayNum = i - startWeekday + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return null;
      return DateTime(_selectedDate.year, _selectedDate.month, dayNum);
    });

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(builder: (context) {
                String englishMonth = DateFormat('MMMM yyyy').format(_selectedDate);
                String nepaliMonth = '';
                if (_showNepaliDates) {
                  final info = _getNepaliDateInfo(firstOfMonth);
                  nepaliMonth = info['month'] ?? '';
                }
                return Text(
                  nepaliMonth.isEmpty ? englishMonth : "$englishMonth ($nepaliMonth)",
                  style: TextStyle(
                    color: isDark ? AppColors.slate200 : AppColors.slate800,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }),
              Row(
                children: [
                  IconButton(
                    tooltip: "Previous month",
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
                      });
                    },
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  IconButton(
                    tooltip: "Next month",
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
                      });
                    },
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Sun", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.redAccent)),
              Text("Mon", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text("Tue", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text("Wed", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text("Thu", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text("Fri", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text("Sat", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 3, // Constrain grid to avoid bottom overflow
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cells,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.75, // Decreased to provide more height for Nepali dates
            ),
              itemBuilder: (context, i) {
                final date = dates[i];
                if (date == null) {
                  return const SizedBox.shrink();
                }
                final key = dateFormat.format(date);
                final isToday = key == todayKey;
                final events = _eventsForDate(date);
                final isSelected = isSameDay(_selectedDate, date);

                String nepaliDay = '';
                if (_showNepaliDates) {
                  final nepaliInfo = _getNepaliDateInfo(date);
                  nepaliDay = nepaliInfo['day'] ?? '';
                }

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withOpacity(0.15)
                          : (isToday ? cs.primary.withOpacity(0.08) : cs.surface.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isToday ? AppColors.govGreen : cs.outline.withOpacity(0.4),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('d').format(date),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isToday ? AppColors.govGreen : cs.onSurface,
                                fontSize: 12,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 2),
                              Icon(Icons.circle, size: 4, color: AppColors.govGreen),
                            ]
                          ],
                        ),
                        if (_showNepaliDates && nepaliDay.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            nepaliDay,
                            style: TextStyle(
                              fontSize: 9,
                              color: cs.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        if (events.isNotEmpty)
                          Wrap(
                            spacing: 2,
                            runSpacing: 1,
                            children: events.take(3).map((e) {
                              return Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _eventColor(e),
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
        Expanded(
          flex: 2, // Give more room to the list to avoid overcrowding
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
            child: _buildEventsListForSelected(cs),
          ),
        ),
      ],
    );
  }
}







