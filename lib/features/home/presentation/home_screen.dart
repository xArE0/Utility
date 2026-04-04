import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../schedule/presentation/schedule_screen.dart';
import '../../schedule/presentation/schedule_controller.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/static_background.dart';
import '../../../utils/api_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum SyncState { idle, syncing, success, error }

class _HomeScreenState extends State<HomeScreen> {
  bool _showNepaliDates = false;
  final GlobalKey<ScheduleScreenState> _scheduleKey = GlobalKey<ScheduleScreenState>();
  String? _dailyQuote;
  SyncState _syncState = SyncState.idle;

  @override
  void initState() {
    super.initState();
    _fetchDailyQuote();
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
    if (hour < 12) return "Good Morning, xArE0!";
    if (hour < 17) return "Good Afternoon, xArE0!";
    return "Good Evening, xArE0!";
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

  @override
  Widget build(BuildContext context) {
    return StaticBackground(
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
                      if (aqi == null) return const SizedBox.shrink();
                      
                      String icon = '🌞';
                      if (aqi > 50) icon = '😐';
                      if (aqi > 100) icon = '😷';
                      if (aqi > 150) icon = '🤢';
                      if (aqi > 200) icon = '☠️';

                      return Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          "AQI: $aqi $icon", 
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
                  IconButton(
                    tooltip: "Toggle Nepali Date",
                    onPressed: () {
                      setState(() => _showNepaliDates = !_showNepaliDates);
                    },
                    icon: Icon(
                      _showNepaliDates ? Icons.calendar_today : Icons.calendar_month,
                      color: _showNepaliDates ? AppColors.govGreen : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
          bottom: (_dailyQuote != null && (_scheduleKey.currentState?.controller.viewMode == ScheduleView.timeline || _scheduleKey.currentState == null))
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36.0),
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, right: 16, bottom: 8, top: 0.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dailyQuote!,
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.slate400,
                      ),
                      maxLines: 2,
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
          showNepaliDates: _showNepaliDates,
          onToggleNepali: (val) => setState(() => _showNepaliDates = val),
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
                      "Avishek Shrestha",
                      style: AppTypography.headlineSmall.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('hh:mm a').format(DateTime.now()),
                      style: AppTypography.titleMedium.copyWith(color: AppColors.slate200),
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