import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/todo/todo_screen.dart';
import '../screens/autoclicker/autoclicker_screen.dart';

class AppRoutes {
  static const home = '/';
  static const todo = '/todo';
  static const calculator = '/calculator';
  static const autoclicker = '/autoclicker';
  static const schedule = '/schedule';

  static Map<String, WidgetBuilder> get all => {
    home: (_) => const HomeScreen(),
    todo: (_) => const TodoScreen(),
    autoclicker: (_) => const AutoClickerScreen(),
  };
}
