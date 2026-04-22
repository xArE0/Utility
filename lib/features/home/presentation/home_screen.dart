import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../schedule/presentation/schedule_screen.dart';
import '../../schedule/presentation/schedule_controller.dart';
import '../../schedule/domain/schedule_entities.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../utils/api_services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../../../services/notification_service.dart';
import '../../../core/services/settings_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum SyncState { idle, syncing, success, error }

class _HomeScreenState extends State<HomeScreen> {

  final GlobalKey<ScheduleScreenState> _scheduleKey = GlobalKey<ScheduleScreenState>();
  String? _dailyQuote;
  SyncState _syncState = SyncState.idle;

  int _secretTapCount = 0;
  DateTime? _lastSecretTapTime;

  @override
  void initState() {
    super.initState();
    _fetchDailyQuote();
    SettingsService.instance.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _fetchDailyQuote() async {
    final quote = await ApiServices.fetchDailyQuote();
    if (quote != null && mounted) {
      setState(() => _dailyQuote = quote);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleKey.currentState?.controller.addListener(() {
        if (mounted) setState(() {});
      });
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = SettingsService.instance.scheduleName;
    if (hour < 12) return "Good Morning, $name!";
    if (hour < 17) return "Good Afternoon, $name!";
    return "Good Evening, $name!";
  }

  void _onSidebarNameTap() {
    final now = DateTime.now();
    if (_lastSecretTapTime == null || now.difference(_lastSecretTapTime!).inSeconds > 2) {
      _secretTapCount = 1;
    } else {
      _secretTapCount++;
    }
    _lastSecretTapTime = now;

    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showSecretAuthDialog();
    }
  }

  void _showSecretAuthDialog() async {
    final currentPassword = SettingsService.instance.secretPassword;
    final isSetup = currentPassword.isEmpty;
    final controller = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            void handleSubmit(String input) async {
              if (isSetup) {
                if (input.length < 4) {
                  setStateBuilder(() => errorText = 'Password must be at least 4 chars');
                  return;
                }
                await SettingsService.instance.updateSecretPassword(input);
                if (mounted) {
                  Navigator.pop(dialogContext); // close dialog
                  Navigator.pop(this.context); // close drawer
                  Navigator.pushNamed(this.context, AppRoutes.settings);
                }
              } else {
                if (input == currentPassword) {
                  Navigator.pop(dialogContext); // close dialog
                  Navigator.pop(this.context); // close drawer
                  Navigator.pushNamed(this.context, AppRoutes.settings);
                } else {
                  setStateBuilder(() => errorText = 'Incorrect password');
                }
              }
            }

            return AlertDialog(
              title: Text(isSetup ? 'Setup Password' : 'Enter  Password'),
              content: TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: errorText,
                ),
                onSubmitted: handleSubmit,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => handleSubmit(controller.text),
                  child: Text(isSetup ? 'Save & Enter' : 'Enter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSyncIcon() {
    switch (_syncState) {
      case SyncState.syncing:
        return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.govGreen),
        );
      case SyncState.success:
        return const Icon(Icons.check_circle, color: AppColors.govGreen, size: 22);
      case SyncState.error:
        return const Icon(Icons.error, color: Colors.orangeAccent, size: 22);
      case SyncState.idle:
      default:
        return const Icon(Icons.cloud_download_outlined, color: AppColors.govGreen, size: 22);
    }
  }

  /// Compute a compact height for the quote area based on estimated line count.
  double _computeQuoteHeight(String quote) {
    // Rough estimate: ~45 chars per line on typical phone width
    final lineCount = (quote.length / 45).ceil().clamp(1, 4);
    if (lineCount <= 1) return 16.0;
    if (lineCount <= 2) return 28.0;
    return 44.0;
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void performSearch(String query) {
              final ctrl = _scheduleKey.currentState?.controller;
              if (ctrl == null || query.trim().isEmpty) {
                setDialogState(() => results = []);
                return;
              }
              final q = query.trim().toLowerCase();
              final Set<String> seen = {};
              final List<Map<String, dynamic>> found = [];
              final center = ctrl.selectedDate;

              // 1. Search raw database for non-recurring events so we can find them instantly regardless of date
              for (final e in ctrl.allEvents) {
                if (e.task.toLowerCase().contains(q) || e.type.toLowerCase().contains(q)) {
                  bool isRecurring = e.type == 'birthday' || e.type == 'exam' || (e.repeat != null && e.repeat != "none") || (e.durationDays != null && e.durationDays! > 1);
                  if (!isRecurring) {
                    final uniqueKey = '${e.date}_${e.task}_${e.type}';
                    if (!seen.contains(uniqueKey)) {
                      try {
                        found.add({'event': e, 'targetDate': DateTime.parse(e.date)});
                        seen.add(uniqueKey);
                      } catch (_) {}
                    }
                  }
                }
              }

              // 2. Scan +- 1 year for occurrences of recurring events
              for (int i = -365; i <= 365; i++) {
                final date = center.add(Duration(days: i));
                final events = ctrl.eventsForDate(date);
                for (final e in events) {
                  bool isRecurring = e.type == 'birthday' || e.type == 'exam' || (e.repeat != null && e.repeat != "none") || (e.durationDays != null && e.durationDays! > 1);
                  if (!isRecurring) continue; // Already handled above

                  final targetDateStr = '${date.year}-${date.month}-${date.day}';
                  final uniqueKey = '${targetDateStr}_${e.task}_${e.type}';
                  if (seen.contains(uniqueKey)) continue;

                  if (e.task.toLowerCase().contains(q) || e.type.toLowerCase().contains(q)) {
                    found.add({'event': e, 'targetDate': date});
                    seen.add(uniqueKey);
                  }
                }
              }

              // Sort by closest to currently selected date
              found.sort((a, b) {
                final dateA = a['targetDate'] as DateTime;
                final dateB = b['targetDate'] as DateTime;
                final diffA = dateA.difference(center).inDays.abs();
                final diffB = dateB.difference(center).inDays.abs();
                return diffA.compareTo(diffB);
              });

              setDialogState(() => results = found);
            }

            final theme = Theme.of(context);
            final cs = theme.colorScheme;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: cs.surface.withOpacity(0.95),
              title: const Text("Search Events"),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Type to search...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: cs.surface.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                        ),
                      ),
                      onChanged: performSearch,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: results.isEmpty
                          ? Center(
                              child: Text(
                                searchController.text.isEmpty
                                    ? "Search for events by name or type"
                                    : "No events found",
                                style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                              ),
                            )
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final item = results[i];
                                final event = item['event'] as Event;
                                final targetDate = item['targetDate'] as DateTime;
                                final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

                                Color typeColor;
                                IconData typeIcon;
                                switch (event.type) {
                                  case 'birthday': typeColor = const Color(0xFFE91E63); typeIcon = Icons.cake; break;
                                  case 'reminder': typeColor = const Color(0xFF14B8A6); typeIcon = Icons.notifications_active; break;
                                  case 'exam': typeColor = const Color(0xFF2563EB); typeIcon = Icons.school; break;
                                  case 'homework': typeColor = const Color(0xFF8B5CF6); typeIcon = Icons.assignment; break;
                                  case 'festival': typeColor = Colors.deepOrange; typeIcon = Icons.celebration; break;
                                  case 'event': typeColor = const Color(0xFFFFA000); typeIcon = Icons.event; break;
                                  case 'normal': default: typeColor = const Color(0xFF10B981); typeIcon = Icons.task_alt; break;
                                }
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: typeColor.withOpacity(0.15),
                                    child: Icon(typeIcon, color: typeColor, size: 20),
                                  ),
                                  title: Text(event.task, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    "$dateStr  •  ${event.type[0].toUpperCase()}${event.type.substring(1)}",
                                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                                  ),
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    final ctrl = _scheduleKey.currentState?.controller;
                                    if (ctrl != null) {
                                      ctrl.jumpToDate(targetDate);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: 65.0,
          leading: Builder(
            builder: (context) {
              return Align(
                alignment: Alignment.topCenter,
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              );
            },
          ),
          title: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 0.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getGreeting(),
                      style: AppTypography.titleLarge,
                    ),
                  Builder(
                    builder: (context) {
                      final ctrl = _scheduleKey.currentState?.controller;
                      final aqi = ctrl?.currentAqi;
                      
                      String aqiText;
                      String icon;
                      if (aqi == null) {
                        aqiText = '--';
                        icon = '🌞';
                      } else {
                        aqiText = '$aqi';
                        icon = '🌞';
                        if (aqi > 50) icon = '😐';
                        if (aqi > 100) icon = '😷';
                        if (aqi > 150) icon = '🤢';
                        if (aqi > 200) icon = '☠️';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          "AQI: $aqiText $icon", 
                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.slate300, fontSize: 13),
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    constraints: const BoxConstraints(),
                    tooltip: "Search Events",
                    onPressed: _showSearchDialog,
                    icon: const Icon(Icons.search, color: AppColors.slate300, size: 22),
                  ),
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    constraints: const BoxConstraints(),
                    tooltip: _syncState == SyncState.syncing ? "Syncing..." : "Sync All API Data",
                    onPressed: _syncState != SyncState.idle ? null : () async {
                      setState(() => _syncState = SyncState.syncing);
                      // Pull Schedule APIs
                      final success = await _scheduleKey.currentState?.triggerSyncApiData() ?? false;
                      // Pull Quote
                      await _fetchDailyQuote();
                      
                      setState(() => _syncState = success ? SyncState.success : SyncState.error);
                      
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) setState(() => _syncState = SyncState.idle);
                    },
                    icon: _buildSyncIcon(),
                  ),

                ],
              ),
            ),
          ],
          bottom: (_dailyQuote != null && (_scheduleKey.currentState?.controller.viewMode == ScheduleView.timeline || _scheduleKey.currentState == null))
            ? PreferredSize(
                preferredSize: Size.fromHeight(_computeQuoteHeight(_dailyQuote!)),
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, right: 16, bottom: 4, top: 0.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dailyQuote!,
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.slate400,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
            : null,
          flexibleSpace: Container(
            color: AppColors.slate900.withOpacity(0.5),
          ),
          backgroundColor: Colors.transparent,
        ),
        drawer: _buildGlassDrawer(context),
        body: ScheduleScreen(
          key: _scheduleKey,
        ),
      ),
    );
  }

  Widget _buildGlassDrawer(BuildContext context) {
    return RepaintBoundary(
      child: Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate900.withOpacity(0.85),
          border: const Border(right: BorderSide(color: AppColors.slate700)),
        ),
        child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      SettingsService.instance.sidebarName,
                      style: AppTypography.headlineSmall.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _onSidebarNameTap,
                      child: Text(
                        DateFormat('hh:mm a').format(DateTime.now()),
                        style: AppTypography.titleMedium.copyWith(color: AppColors.slate200),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.slate300),
                    ),
                    Builder(
                      builder: (context) {
                        final ctrl = _scheduleKey.currentState?.controller;
                        if (ctrl == null) return const SizedBox.shrink();
                        
                        // We use the same formatting key used in ScheduleController
                        final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
                        final w = ctrl.weatherMap[todayKey];
                        if (w == null || (w['sunrise'] ?? '').isEmpty) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Text("🌅 ", style: TextStyle(fontSize: 14)),
                              Text(w['sunrise']!, style: AppTypography.bodySmall.copyWith(color: AppColors.slate300)),
                              const SizedBox(width: 12),
                              const Text("🌇 ", style: TextStyle(fontSize: 14)),
                              Text(w['sunset']!, style: AppTypography.bodySmall.copyWith(color: AppColors.slate300)),
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.list,
                title: "Expense Tracker",
                route: AppRoutes.expense,
                color: AppColors.govBlue,
              ),
              _buildDrawerItem(
                context,
                icon: Icons.lock,
                title: "Data Vault",
                route: AppRoutes.datavault,
                color: AppColors.govGreen,
              ),
              _buildDrawerItem(
                context,
                icon: Icons.menu_book,
                title: "Logbook",
                route: AppRoutes.logbook,
                color: const Color(0xFFF59E0B),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.timer,
                title: "Cooldown",
                route: AppRoutes.cooldown,
                color: const Color(0xFF06B6D4),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.import_export_sharp,
                title: "Import/Export",
                route: AppRoutes.importexport,
                color: AppColors.info,
              ),
              const _SidebarActiveTimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? route,
    required Color color,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? color : AppColors.slate600,
        shadows: enabled ? AppColors.glowShadow : null,
      ),
      title: Text(
        title,
        style: enabled
            ? AppTypography.titleMedium
            : AppTypography.titleMedium.copyWith(color: AppColors.slate600),
      ),
      onTap: enabled && route != null ? () => Navigator.pushNamed(context, route) : null,
      hoverColor: AppColors.govBlue.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }
}

class _SidebarActiveTimer extends StatefulWidget {
  const _SidebarActiveTimer({super.key});

  @override
  State<_SidebarActiveTimer> createState() => _SidebarActiveTimerState();
}

class _SidebarActiveTimerState extends State<_SidebarActiveTimer> {
  Timer? _timer;
  Map<int, int> _activeTimers = {}; // key: mins, value: remainingMs

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _checkTimers(); // Initial immediate check
    
    // Continuous 1-second polling loop active only while drawer is open
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkTimers();
    });
  }

  Future<void> _checkTimers() async {
    // We must invoke getInstance and reload() constantly because the Android background
    // widget process writes to the shared preferences disk asynchronously. 
    // Without reload(), the foreground app cache never realizes a new timer started.
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); 
    
    Map<int, int> active = {};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    
    for (final durationMins in [5, 15, 30]) {
      final startMs = prefs.getInt('active_timer_${durationMins}_start_ms');
      if (startMs != null) {
        final totalDurationMs = durationMins * 60 * 1000;
        final elapsedMs = nowMs - startMs;
        if (elapsedMs < totalDurationMs) {
          active[durationMins] = totalDurationMs - elapsedMs;
        } else {
          // Self-cleaning: destroy stale records to prevent minimal storage bloat
          prefs.remove('active_timer_${durationMins}_start_ms');
        }
      }
    }

    if (mounted) {
      setState(() {
        _activeTimers = active;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelTimer(int durationMins) async {
    // 1. Storage Scrub
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_timer_${durationMins}_start_ms');

    // 2. Kill Android Notification Instantly
    final timerId = 100000 + durationMins;
    await NotificationService().cancelEventNotification(timerId);

    // 3. Reset Android Widget RemoteViews configuration manually
    final btnId = "btn_${durationMins}m_tick";
    await HomeWidget.saveWidgetData<bool>(btnId, false);
    await HomeWidget.updateWidget(name: 'ScheduleWidgetProvider', androidName: 'ScheduleWidgetProvider');

    // Force synchronization locally to trigger instantaneous UI deletion
    _checkTimers();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTimers.isEmpty) return const SizedBox.shrink();

    // Sort keys so smaller duration timers appear first (5m, then 15m, then 30m)
    final activeKeys = _activeTimers.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: activeKeys.map((duration) {
          final remainingMs = _activeTimers[duration]!;
          final remainingSeconds = remainingMs ~/ 1000;
          final mins = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
          final secs = (remainingSeconds % 60).toString().padLeft(2, '0');

          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center alignment box using full width wrapper
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Color(0xFF06B6D4), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "$mins:$secs",
                        style: AppTypography.headlineSmall.copyWith(
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -4,
                  left: 2,
                  child: Text(
                    "${duration}m",
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.slate400,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                Positioned(
                  top: -12,
                  bottom: -12,
                  right: -12,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.slate400,
                    splashRadius: 20,
                    tooltip: "Cancel Timer",
                    onPressed: () => _cancelTimer(duration),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}