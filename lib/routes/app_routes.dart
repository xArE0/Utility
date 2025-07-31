import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/expense/expense.dart';
import '../screens/autoclicker/autoclicker_screen.dart';

class AppRoutes {
  static const home = '/';
  static const expense = '/expense';
  static const calculator = '/calculator';
  static const autoclicker = '/autoclicker';
  static const schedule = '/schedule';

  static Map<String, WidgetBuilder> get all => {
    home: (_) => const HomeScreen(),
    expense: (_) => const ExpenseTrackerScreen(),
    autoclicker: (_) => const AutoClickerScreen(),
  };
}
