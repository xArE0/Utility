import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/static_background.dart';
import '../../../core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sidebarNameController = TextEditingController();
  final _scheduleNameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance;
    _sidebarNameController.text = settings.sidebarName;
    _scheduleNameController.text = settings.scheduleName;
    _passwordController.text = settings.secretPassword;
  }

  @override
  void dispose() {
    _sidebarNameController.dispose();
    _scheduleNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
    final secondaryText = isDark ? AppColors.slate300 : Colors.grey[600]!;
    final cardBg = isDark ? AppColors.slate900.withOpacity(0.55) : Colors.grey[100]!;

    return StaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Secret Settings'),
          centerTitle: true,
          backgroundColor: isDark ? Colors.transparent : theme.primaryColor,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
          backgroundColor: AppColors.govBlue,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Display Names', primaryText),
              _buildCard(
                cardBg,
                Column(
                  children: [
                    _buildTextField(
                      controller: _sidebarNameController,
                      label: 'Sidebar Display Name',
                      hint: 'e.g. Avishek Shrestha',
                      icon: Icons.person,
                    ),
                    const Divider(height: 32, indent: 40),
                    _buildTextField(
                      controller: _scheduleNameController,
                      label: 'Schedule Greeting Name',
                      hint: 'e.g. xArE0',
                      icon: Icons.waving_hand,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Security', primaryText),
              _buildCard(
                cardBg,
                _buildTextField(
                  controller: _passwordController,
                  label: 'Secret Menu Password',
                  hint: 'Enter a strong password',
                  icon: Icons.lock,
                  isPassword: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.govBlue,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCard(Color bgColor, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate700.withOpacity(0.5)),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.govBlue),
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _saveSettings() async {
    final sidebar = _sidebarNameController.text.trim();
    final schedule = _scheduleNameController.text.trim();
    final password = _passwordController.text.trim();

    final finalSidebar = sidebar.isEmpty ? 'Avishek Shrestha' : sidebar;
    final finalSchedule = schedule.isEmpty ? 'xArE0' : schedule;

    await SettingsService.instance.updateSidebarName(finalSidebar);
    await SettingsService.instance.updateScheduleName(finalSchedule);
    await SettingsService.instance.updateSecretPassword(password);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
      Navigator.pop(context);
    }
  }
}
