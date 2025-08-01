import 'package:flutter/material.dart';
import 'package:utility/screens/Export%20&%20Import/ExportImports.dart';
import '../screens/home/home_screen.dart';
import '../screens/expense/expense.dart';
import '../screens/autoclicker/autoclicker_screen.dart';
import '../screens/Data Vault/DataVault.dart';

class AppRoutes {
  static const home = '/';
  static const expense = '/expense';
  static const importexport = '/importexport';
  static const autoclicker = '/autoclicker';
  static const schedule = '/schedule';
  static const datavault = '/datavault';

  static Map<String, WidgetBuilder> get all => {
    home: (_) => const HomeScreen(),
    expense: (_) => const ExpenseTrackerScreen(),
    autoclicker: (_) => const AutoClickerScreen(),
    importexport: (_) => ExportImportsPage(),
    datavault: (_) => const DataVaultPage(),
  };
}
