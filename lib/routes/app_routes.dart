import 'package:flutter/material.dart';
import '../features/export_import/presentation/export_import_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/expenses/presentation/expense_screen.dart';
import '../features/autoclicker/presentation/autoclicker_screen.dart';
import '../features/data_vault/presentation/data_vault_screen.dart';
import '../features/pot_tracker/presentation/pot_tracker_screen.dart';
import '../features/cooldown/presentation/cooldown_screen.dart';

class AppRoutes {
  static const home = '/';
  static const expense = '/expense';
  static const importexport = '/importexport';
  static const autoclicker = '/autoclicker';
  static const schedule = '/schedule';
  static const datavault = '/datavault';
  static const pottracker = '/pottracker';
  static const cooldown = '/cooldown';

  static Map<String, WidgetBuilder> get all => {
    home: (_) => const HomeScreen(),
    expense: (_) => const ExpenseTrackerScreen(),
    autoclicker: (_) => const AutoClickerScreen(),
    importexport: (_) => ExportImportsPage(),
    datavault: (_) => const DataVaultPage(),
    pottracker: (_) => const PotTrackerPage(),
    cooldown: (_) => const CooldownScreen(),
  };
}
