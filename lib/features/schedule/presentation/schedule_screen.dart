import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../domain/schedule_entities.dart';
import '../data/local_schedule_repository.dart';
import 'schedule_controller.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
  });

  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  late final ScheduleController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = ScheduleController(
      repository: LocalScheduleRepository(),
    );
    _controller.setScrollController(_scrollController);
    _controller.init();
    _controller.addListener(_onControllerNotify);
  }

  Future<bool> triggerSyncApiData() {
    return _controller.syncAllApiData();
  }

  ScheduleController get controller => _controller;

  void _onControllerNotify() {
    if (mounted) {
      setState(() {});
    }
  }



  @override
  void dispose() {
    _controller.removeListener(_onControllerNotify);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildViewSwitcher(bool isDark) {
    Color active = AppColors.govGreen;
    Color inactive = isDark ? AppColors.slate400 : AppColors.slate600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
          padding: EdgeInsets.zero,
          tooltip: "Timeline view",
          onPressed: () {
            _controller.viewMode = ScheduleView.timeline;
          },
          icon: Icon(Icons.view_agenda,
              size: 22,
              color: _controller.viewMode == ScheduleView.timeline ? active : inactive),
        ),
        IconButton(
          constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
          padding: EdgeInsets.zero,
          tooltip: "Week view",
          onPressed: () => _controller.viewMode = ScheduleView.week,
          icon: Icon(Icons.calendar_view_week,
              size: 22,
              color: _controller.viewMode == ScheduleView.week ? active : inactive),
        ),
        IconButton(
          constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
          padding: EdgeInsets.zero,
          tooltip: "Month view",
          onPressed: () => _controller.viewMode = ScheduleView.month,
          icon: Icon(Icons.calendar_month,
              size: 22,
              color: _controller.viewMode == ScheduleView.month ? active : inactive),
        ),
      ],
    );
  }

  void _showAddEventDialog() {
    final taskController = TextEditingController();
    DateTime chosenDate = _controller.selectedDate;
    String selectedType = 'normal';

    bool remindMe = false;
    int remindDaysBefore = 0;
    TimeOfDay? remindTime;

    String repeat = "none";
    int repeatInterval = 1;
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            content: SizedBox(
              width: 500,
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
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("Event Type", style: TextStyle(color: theme.hintColor, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'normal', 'reminder', 'birthday', 'exam', 'homework', 'festival', 'event'
                      ].map((type) {
                        final isSelected = selectedType == type;
                        Color baseColor;
                        IconData icon;
                        switch (type) {
                          case 'birthday': baseColor = const Color(0xFFE91E63); icon = Icons.cake; break;
                          case 'reminder': baseColor = const Color(0xFF14B8A6); icon = Icons.notifications_active; break;
                          case 'exam': baseColor = const Color(0xFF2563EB); icon = Icons.school; break;
                          case 'homework': baseColor = const Color(0xFF8B5CF6); icon = Icons.assignment; break;
                          case 'festival': baseColor = Colors.deepOrange; icon = Icons.celebration; break;
                          case 'event': baseColor = const Color(0xFFFFA000); icon = Icons.event; break;
                          case 'normal': default: baseColor = const Color(0xFF10B981); icon = Icons.task_alt; break;
                        }
                        final labelText = type[0].toUpperCase() + type.substring(1);
                        
                        return ActionChip(
                          backgroundColor: isSelected ? baseColor.withOpacity(0.15) : inputFill,
                          side: BorderSide(
                            color: isSelected ? baseColor : cs.primary.withOpacity(0.15),
                            width: isSelected ? 1.5 : 1,
                          ),
                          avatar: Icon(isSelected ? Icons.check : icon, size: 16, color: isSelected ? baseColor : theme.hintColor),
                          label: Text(
                            labelText,
                            style: TextStyle(
                              color: isSelected ? baseColor : theme.hintColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            )
                          ),
                          onPressed: () {
                            setDialogState(() {
                              selectedType = type;
                              if (type == 'birthday') {
                                remindMe = true;
                                remindDaysBefore = 1;
                                remindTime = const TimeOfDay(hour: 6, minute: 0);
                                repeat = 'yearly';
                              } else if (type == 'reminder') {
                                remindMe = true;
                                remindDaysBefore = 0;
                                remindTime = const TimeOfDay(hour: 6, minute: 0);
                                repeat = 'none';
                              } else {
                                // normal, exam, homework, festival, event -> reset to defaults
                                remindMe = false;
                                remindDaysBefore = 0;
                                remindTime = null;
                                repeat = 'none';
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                          const Spacer(),
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
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Repeat", style: TextStyle(color: theme.hintColor, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: ["none", "daily", "weekly", "monthly", "yearly", "custom"].map((r) {
                              final isSelected = repeat == r;
                              final labelText = r == "custom" ? "Custom..." : (r[0].toUpperCase() + r.substring(1));
                              return ChoiceChip(
                                label: Text(labelText, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                selectedColor: cs.primary.withOpacity(0.15),
                                checkmarkColor: cs.primary,
                                backgroundColor: inputFill,
                                side: BorderSide(color: isSelected ? cs.primary : cs.primary.withOpacity(0.15), width: isSelected ? 1.5 : 1),
                                onSelected: (b) {
                                  if (b) setDialogState(() => repeat = r);
                                },
                              );
                            }).toList(),
                          ),
                          if (repeat == "custom") ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text("Every:"),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
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
                                const SizedBox(width: 8),
                                const Text("days"),
                              ],
                            ),
                          ],
                        ]
                      )
                    ),
                    const SizedBox(height: 12),
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
                      date: ScheduleController.dateFormat.format(chosenDate),
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
                    
                    await _controller.addEvent(newEvent, context);
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

  Color _eventColor(Event event) {
    switch (event.type) {
      case 'birthday':
        return const Color(0xFFE91E63);
      case 'reminder':
        return const Color(0xFF14B8A6);
      case 'exam':
        return const Color(0xFF2563EB);
      case 'homework':
        return const Color(0xFF8B5CF6);
      case 'festival':
        return Colors.deepOrange;
      case 'event':
        return const Color(0xFFFFA000);
      case 'normal':
      default:
        return const Color(0xFF10B981);
    }
  }

  Widget _eventTypeIcon(String type) {
    IconData icon;
    String label;
    switch (type) {
      case 'birthday':
        icon = Icons.cake;
        label = "Birthday";
        break;
      case 'reminder':
        icon = Icons.notifications_active;
        label = "Reminder";
        break;
      case 'exam':
        icon = Icons.school;
        label = "Exam";
        break;
      case 'event':
        icon = Icons.event;
        label = "Event";
        break;
      case 'homework':
        icon = Icons.assignment;
        label = "Homework";
        break;
      case 'festival':
        icon = Icons.celebration;
        label = "Festival";
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildEventContainer(Event event, DateTime currentDate) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final base = _eventColor(event);
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
          if (event.type != 'normal')
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
                      "${event.remindDaysBefore == 0 ? 'Now' : '${event.remindDaysBefore ?? 0}d'}, ${event.remindTime ?? ''}",
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
                          "${event.remindDaysBefore == 0 ? 'Today' : '${event.remindDaysBefore ?? 0}d'}, ${event.remindTime ?? ''}",
                          style: TextStyle(color: subtleFg, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    bool canMove = event.type == 'normal' || event.type == 'homework' || event.type == 'reminder';

    return Draggable<Map<String, dynamic>>(
      data: {
        'event': event,
        'sourceDate': currentDate,
        'canMove': canMove,
      },
      feedback: feedbackContainer,
      childWhenDragging: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg.withOpacity(0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Opacity(opacity: 0.0, child: container),
      ),
      onDragStarted: () => _controller.isDragging = true,
      onDragEnd: (details) => _controller.isDragging = false,
      child: container,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = ScheduleController.dateFormat.format(today);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color headerSurface = (isDark ? AppColors.slate900 : Colors.white).withOpacity(0.55);
    final Color bodySurface = (isDark ? AppColors.slate900 : Colors.white).withOpacity(0.35);
    final Color dividerColor = (isDark ? AppColors.slate800 : AppColors.slate200).withOpacity(0.8);
    final Color secondaryText = isDark ? AppColors.slate400 : AppColors.slate600;

    _controller.clearOldCache();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 10),
            child: GlassCard(
              borderRadius: BorderRadius.circular(24),
              padding: EdgeInsets.zero,
              child: _controller.viewMode == ScheduleView.timeline
                  ? NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          final offset = notification.metrics.pixels;
                          final index = (offset / _controller.itemExtent).round();
                          final newDate = _controller.dateFromIndex(index);
                          _controller.selectedDate = newDate;
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemExtent: _controller.itemExtent,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (context, index) {
                          final date = _controller.dateFromIndex(index);
                          final key = ScheduleController.dateFormat.format(date);
                          final isToday = key == todayKey;
                          final events = _controller.eventsForDate(date);
                          final nepaliInfo = _controller.getNepaliDateInfo(date);
                          final nepaliMonth = nepaliInfo['month'] ?? '';
                          final nepaliDay = nepaliInfo['day'] ?? '';
                          final dateOnly = DateTime(date.year, date.month, date.day);
                          final dayDiff = dateOnly.difference(today).inDays;
                          String diffText;
                          if (dayDiff == 0) diffText = "Today";
                          else if (dayDiff == -1) diffText = "Yesterday";
                          else if (dayDiff == 1) diffText = "Tomorrow";
                          else if (dayDiff < 0) diffText = "${-dayDiff} days ago";
                          else diffText = "in $dayDiff days";

                          final weatherEmoji = _controller.weatherMap[key]?['emoji'];
                          final Color colBorderColor = isDark
                              ? AppColors.slate600.withOpacity(0.9)
                              : AppColors.slate400.withOpacity(0.7);

                          return DragTarget<Map<String, dynamic>>(
                            onWillAccept: (data) => data != null && (data['canMove'] == true),
                            onAccept: (data) async {
                              final event = data['event'] as Event;
                              final sourceDate = data['sourceDate'] as DateTime;
                              if (!_controller.isSameDay(sourceDate, date)) {
                                await _controller.moveEvent(event, date);
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHighlighted = candidateData.isNotEmpty;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  border: Border(right: BorderSide(color: colBorderColor.withOpacity(0.3), width: 1)),
                                  color: isHighlighted
                                      ? AppColors.govGreen.withOpacity(isDark ? 0.18 : 0.12)
                                      : (isToday ? cs.primary.withOpacity(isDark ? 0.12 : 0.06) : null),
                                ),
                                child: Column(
                                  children: [
                                    // ── Dual-date header ──
                                    Container(
                                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                                      decoration: BoxDecoration(
                                        color: headerSurface,
                                        border: Border(right: BorderSide(color: colBorderColor, width: 2)),
                                      ),
                                      width: double.infinity,
                                      child: Column(
                                        children: [
                                          // English + Nepali side-by-side
                                          Row(
                                            children: [
                                              // Left: English date
                                              Expanded(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(ScheduleController.monthFormat.format(date),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: isToday ? AppColors.govGreen : secondaryText,
                                                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                                        )),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(ScheduleController.numFormat.format(date),
                                                            style: TextStyle(
                                                              fontSize: 28,
                                                              color: isToday ? AppColors.govGreen : (isDark ? AppColors.slate50 : AppColors.slate800),
                                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                            )),
                                                      ],
                                                    ),
                                                    Text(ScheduleController.dayFormat.format(date),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: isToday ? AppColors.govGreen : secondaryText,
                                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                        )),
                                                  ],
                                                ),
                                              ),
                                              // Vertical divider
                                              Container(
                                                width: 1.5,
                                                height: 55,
                                                color: isDark ? AppColors.slate500 : AppColors.slate400,
                                              ),
                                              // Right: Nepali date
                                              Expanded(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (weatherEmoji != null && weatherEmoji.isNotEmpty)
                                                      Text(weatherEmoji, style: const TextStyle(fontSize: 14))
                                                    else
                                                      Icon(Icons.account_balance, size: 14,
                                                          color: isToday ? AppColors.govGreen : (isDark ? const Color(0xFF7EB8E0) : const Color(0xFF4A90B8))),
                                                    Text(nepaliMonth,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isToday ? AppColors.govGreen : (isDark ? const Color(0xFF7EB8E0) : const Color(0xFF4A90B8)),
                                                          fontWeight: FontWeight.w600,
                                                        )),
                                                    Text(nepaliDay,
                                                        style: TextStyle(
                                                          fontSize: 22,
                                                          color: isToday ? (isDark ? AppColors.slate50 : AppColors.slate900) : (isDark ? const Color(0xFF9DC8E8) : const Color(0xFF3A7CA5)),
                                                          fontWeight: FontWeight.w400,
                                                        )),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          // diffText
                                          Text(diffText, style: TextStyle(fontSize: 11, color: secondaryText)),
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
                                                padding: const EdgeInsets.only(bottom: 85),
                                                itemBuilder: (context, i) => _buildEventContainer(events[i], date),
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
                  : (_controller.viewMode == ScheduleView.week ? _buildWeekView(cs, isDark, today, todayKey) : _buildMonthView(cs, isDark, today, todayKey)),
            ),
          ),
          if (_controller.isDragging)
            Positioned(
              left: 16,
              bottom: 110,
              child: DragTarget<Map<String, dynamic>>(
                onWillAccept: (data) => data != null,
                onAccept: (data) async {
                  final event = data['event'] as Event;
                  await _controller.deleteEvent(event);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHighlighted ? Colors.red.shade600 : Colors.red.shade400,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Icon(Icons.delete, color: Colors.white, size: isHighlighted ? 32 : 24),
                  );
                },
              ),
            ),
          Positioned(
            left: 14,
            bottom: 24,
            child: _buildIsland(
              isDark: isDark,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
                    padding: EdgeInsets.zero,
                    tooltip: "Previous event",
                    onPressed: () => _controller.jumpToEvent(-1),
                    icon: const Icon(Icons.chevron_left, size: 22),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
                    padding: EdgeInsets.zero,
                    tooltip: "Today",
                    onPressed: () => _controller.jumpToDate(DateTime.now()),
                    icon: Icon(Icons.today, color: AppColors.govGreen, size: 22),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
                    padding: EdgeInsets.zero,
                    tooltip: "Next event",
                    onPressed: () => _controller.jumpToEvent(1),
                    icon: const Icon(Icons.chevron_right, size: 22),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Container(height: 20, width: 1, color: (isDark ? AppColors.slate700 : AppColors.slate300).withOpacity(0.3)),
                  ),
                  _buildViewSwitcher(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.slate800.withOpacity(0.95),
          border: Border.all(color: AppColors.govGreen.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: IconButton(onPressed: _showAddEventDialog, icon: const Icon(Icons.add), color: AppColors.govGreen, iconSize: 30),
      ),
    );
  }

  Widget _buildIsland({required bool isDark, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.slate800 : Colors.white).withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: (isDark ? AppColors.slate700 : AppColors.slate300).withOpacity(0.8), width: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _buildEventsListForSelected(ColorScheme cs) {
    final events = _controller.eventsForDate(_controller.selectedDate);
    if (events.isEmpty) {
      return Center(child: Text("No events", style: TextStyle(color: cs.onSurface.withOpacity(0.6))));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(events.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildEventContainer(events[i], _controller.selectedDate))),
      ),
    );
  }

  Widget _buildWeekView(ColorScheme cs, bool isDark, DateTime today, String todayKey) {
    final startOfWeek = _controller.selectedDate.subtract(Duration(days: _controller.selectedDate.weekday % 7));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Week of ${DateFormat('MMM d, yyyy').format(startOfWeek)}", style: TextStyle(color: isDark ? AppColors.slate200 : AppColors.slate800, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  IconButton(tooltip: "Previous week", onPressed: () => _controller.selectedDate = _controller.selectedDate.subtract(const Duration(days: 7)), icon: const Icon(Icons.chevron_left, size: 20)),
                  IconButton(tooltip: "Next week", onPressed: () => _controller.selectedDate = _controller.selectedDate.add(const Duration(days: 7)), icon: const Icon(Icons.chevron_right, size: 20)),
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
              final key = ScheduleController.dateFormat.format(date);
              final isToday = key == todayKey;
              final events = _controller.eventsForDate(date);
              final isSelected = _controller.isSameDay(_controller.selectedDate, date);

              String nepaliDay = '';
              final nepaliInfo = _controller.getNepaliDateInfo(date);
              nepaliDay = nepaliInfo['day'] ?? '';

              return Expanded(
                child: GestureDetector(
                  onTap: () => _controller.selectedDate = date,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary.withOpacity(0.15) : (isToday ? cs.primary.withOpacity(0.08) : cs.surface.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isToday ? AppColors.govGreen : cs.outline.withOpacity(0.4), width: isSelected ? 1.5 : 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('E').format(date), style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(DateFormat('d').format(date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isToday ? AppColors.govGreen : cs.onSurface)),
                        if (nepaliDay.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(nepaliDay, style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600)),
                        ],
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 20,
                          child: events.isNotEmpty
                              ? Wrap(spacing: 2, runSpacing: 2, alignment: WrapAlignment.center, children: events.take(2).map((e) => Container(width: 6, height: 6, decoration: BoxDecoration(color: _eventColor(e), shape: BoxShape.circle))).toList())
                              : Center(child: Opacity(opacity: 0.3, child: Icon(Icons.event_note, size: 14, color: cs.onSurface))),
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
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0), child: _buildEventsListForSelected(cs))),
      ],
    );
  }

  Widget _buildMonthView(ColorScheme cs, bool isDark, DateTime today, String todayKey) {
    final firstOfMonth = DateTime(_controller.selectedDate.year, _controller.selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_controller.selectedDate.year, _controller.selectedDate.month);
    final startWeekday = firstOfMonth.weekday % 7; 
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final cells = rows * 7;
    final dates = List<DateTime?>.generate(cells, (i) {
      final dayNum = i - startWeekday + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return null;
      return DateTime(_controller.selectedDate.year, _controller.selectedDate.month, dayNum);
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
                String englishMonth = DateFormat('MMMM yyyy').format(_controller.selectedDate);
                String nepaliMonth = '';
                final infoStart = _controller.getNepaliDateInfo(firstOfMonth);
                final lastOfMonth = DateTime(_controller.selectedDate.year, _controller.selectedDate.month, daysInMonth);
                final infoEnd = _controller.getNepaliDateInfo(lastOfMonth);
                
                final m1 = infoStart['month'] ?? '';
                final m2 = infoEnd['month'] ?? '';
                
                if (m1.isNotEmpty && m2.isNotEmpty && m1 != m2) {
                  nepaliMonth = "$m1/$m2";
                } else {
                  nepaliMonth = m1.isNotEmpty ? m1 : m2;
                }
                return Text(nepaliMonth.isEmpty ? englishMonth : "$englishMonth ($nepaliMonth)", style: TextStyle(color: isDark ? AppColors.slate200 : AppColors.slate800, fontWeight: FontWeight.w700));
              }),
              Row(
                children: [
                  IconButton(tooltip: "Previous month", onPressed: () => _controller.selectedDate = DateTime(_controller.selectedDate.year, _controller.selectedDate.month - 1, _controller.selectedDate.day), icon: const Icon(Icons.chevron_left, size: 20)),
                  IconButton(tooltip: "Next month", onPressed: () => _controller.selectedDate = DateTime(_controller.selectedDate.year, _controller.selectedDate.month + 1, _controller.selectedDate.day), icon: const Icon(Icons.chevron_right, size: 20)),
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
          flex: 3,
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cells,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.75),
            itemBuilder: (context, i) {
              final date = dates[i];
              if (date == null) return const SizedBox.shrink();
              final key = ScheduleController.dateFormat.format(date);
              final isToday = key == todayKey;
              final events = _controller.eventsForDate(date);
              final isSelected = _controller.isSameDay(_controller.selectedDate, date);

              String nepaliDay = '';
              final nepaliInfo = _controller.getNepaliDateInfo(date);
              nepaliDay = nepaliInfo['day'] ?? '';

              return GestureDetector(
                onTap: () => _controller.selectedDate = date,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary.withOpacity(0.15) : (isToday ? cs.primary.withOpacity(0.08) : cs.surface.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isToday ? AppColors.govGreen : cs.outline.withOpacity(0.4), width: isSelected ? 1.2 : 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(DateFormat('d').format(date), style: TextStyle(fontWeight: FontWeight.w700, color: isToday ? AppColors.govGreen : cs.onSurface, fontSize: 12)),
                          if (isToday) ...[const SizedBox(width: 2), Icon(Icons.circle, size: 4, color: AppColors.govGreen)]
                        ],
                      ),
                      if (nepaliDay.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(nepaliDay, style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.5), fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 3),
                      if (events.isNotEmpty)
                        Wrap(spacing: 2, runSpacing: 1, children: events.take(3).map((e) => Container(width: 5, height: 5, decoration: BoxDecoration(color: _eventColor(e), shape: BoxShape.circle))).toList()),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(flex: 2, child: Padding(padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0), child: _buildEventsListForSelected(cs))),
      ],
    );
  }
}
