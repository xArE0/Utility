import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';

class UtilityApp extends StatelessWidget {
  const UtilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Utility App',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.all,
      theme: AppTheme.darkTheme,
      // themeMode: ThemeMode.dark, // Enforce dark theme for now
    );
  }
}
