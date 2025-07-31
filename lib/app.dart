import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

class UtilityApp extends StatelessWidget {
  const UtilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Utility App',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.all,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
    );
  }
}
