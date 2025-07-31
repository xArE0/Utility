import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import 'schedule_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Welcome, xArE0!")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                "Your Widgets",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text("To-Do"),
              onTap: () => Navigator.pushNamed(context, AppRoutes.todo),
            ),
            ListTile(
              leading: const Icon(Icons.touch_app),
              title: const Text("AutoClicker"),
              onTap: () => Navigator.pushNamed(context, AppRoutes.autoclicker),
            ),
          ],
        ),
      ),
      body: const ScheduleScreen(),
    );
  }
}