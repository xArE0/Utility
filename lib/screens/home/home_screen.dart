import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import 'schedule_screen.dart';
import 'package:intl/intl.dart';

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
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Avishek Shrestha",
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    DateFormat('hh:mm a').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text("Expense Tracker"),
              onTap: () => Navigator.pushNamed(context, AppRoutes.expense),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text("Data Vault"),
              onTap: () => Navigator.pushNamed(context, AppRoutes.datavault),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text("Pot Tracker"),
              onTap: () => Navigator.pushNamed(context, AppRoutes.pottracker),
            ),
            // ListTile(
            //   leading: const Icon(Icons.touch_app),
            //   title: const Text("AutoClicker"),
            //   onTap: () => Navigator.pushNamed(context, AppRoutes.autoclicker),
            // ),
            ListTile(
              leading: Icon(Icons.touch_app, color: Colors.grey),
              title: Text("AutoClicker", style: TextStyle(color: Colors.grey)),
              enabled: false,
              onTap: null,
            ),
            ListTile(
              leading: const Icon(Icons.import_export_sharp),
              title: const Text("Import/Export"),
              onTap: () => Navigator.pushNamed(context, AppRoutes.importexport),
            ),
          ],
        ),
      ),
      body: const ScheduleScreen(),
    );
  }
}