import 'package:flutter/material.dart';
import 'package:utility/features/export_import/export_imports.dart';
import '../features/home/home_screen.dart';
import '../features/expenses/expense.dart';
import '../features/autoclicker/autoclicker_screen.dart';
import '../features/data_vault/data_vault.dart';
import '../features/pot_tracker/pot_tracker.dart';

class AppRoutes {
  static const home = '/';
  static const expense = '/expense';
  static const importexport = '/importexport';
  static const autoclicker = '/autoclicker';
  static const schedule = '/schedule';
  static const datavault = '/datavault';
  static const pottracker = '/pottracker';

  static Map<String, WidgetBuilder> get all => {
    home: (_) => const HomeScreen(),
    expense: (_) => const ExpenseTrackerScreen(),
    autoclicker: (_) => const AutoClickerScreen(),
    importexport: (_) => ExportImportsPage(),
    datavault: (_) => const DataVaultPage(),
    pottracker: (_) => const PotTrackerPage(),
  };
}
