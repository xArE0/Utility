import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import 'schedule_screen.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // For ImageFilter
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glass_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Welcome, xArE0!",
            style: AppTypography.titleLarge,
          ),
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: AppColors.slate900.withOpacity(0.5),
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
        ),
        drawer: _buildGlassDrawer(context),
        body: const ScheduleScreen(),
      ),
    );
  }

  Widget _buildGlassDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate900.withOpacity(0.85),
          border: const Border(right: BorderSide(color: AppColors.slate700)),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                icon: Icons.account_balance_wallet,
                title: "Pot Tracker",
                route: AppRoutes.pottracker,
                color: AppColors.govGold,
              ),
              _buildDrawerItem(
                context,
                icon: Icons.touch_app,
                title: "AutoClicker",
                route: AppRoutes.autoclicker,
                color: AppColors.slate500,
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