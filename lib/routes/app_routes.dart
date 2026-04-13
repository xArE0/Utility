import 'package:flutter/material.dart';
import '../features/export_import/presentation/export_import_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/expenses/presentation/expense_screen.dart';
import '../features/data_vault/presentation/data_vault_screen.dart';
import '../features/cooldown/presentation/cooldown_screen.dart';
import '../features/logbook/presentation/logbook_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

class AppRoutes {
  static const home = '/';
  static const expense = '/expense';
  static const importexport = '/importexport';
  static const schedule = '/schedule';
  static const datavault = '/datavault';
  static const cooldown = '/cooldown';
  static const logbook = '/logbook';
  static const settings = '/settings';

  static Map<String, WidgetBuilder> get all => {
    home: (_) => const HomeScreen(),
    expense: (_) => const ExpenseTrackerScreen(),
    importexport: (_) => ExportImportsPage(),
    datavault: (_) => const DataVaultPage(),
    cooldown: (_) => const CooldownScreen(),
    logbook: (_) => const LogbookScreen(),
    settings: (_) => const SettingsScreen(),
  };
}
