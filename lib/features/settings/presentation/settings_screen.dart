import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
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
  final _vaultExportPasswordController = TextEditingController();
  final _timer1Controller = TextEditingController();
  final _timer2Controller = TextEditingController();
  final _timer3Controller = TextEditingController();

  bool _obscureSecretPassword = true;
  bool _obscureVaultPassword = true;
  String _selectedDefaultScreen = 'schedule';

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance;
    _sidebarNameController.text = settings.sidebarName;
    _scheduleNameController.text = settings.scheduleName;
    _passwordController.text = settings.secretPassword;
    _vaultExportPasswordController.text = settings.vaultExportPassword;
    _timer1Controller.text = settings.widgetTimer1.toString();
    _timer2Controller.text = settings.widgetTimer2.toString();
    _timer3Controller.text = settings.widgetTimer3.toString();
    _selectedDefaultScreen = settings.defaultScreen;
  }

  @override
  void dispose() {
    _sidebarNameController.dispose();
    _scheduleNameController.dispose();
    _passwordController.dispose();
    _vaultExportPasswordController.dispose();
    _timer1Controller.dispose();
    _timer2Controller.dispose();
    _timer3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
    final secondaryText = isDark ? AppColors.slate300 : Colors.grey[600]!;
    final cardBg = isDark ? AppColors.slate900.withOpacity(0.55) : Colors.grey[100]!;

    return AnimatedBackground(
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
                Column(
                  children: [
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Secret Menu Password',
                      hint: 'Enter a strong password',
                      icon: Icons.lock,
                      isPassword: true,
                      obscure: _obscureSecretPassword,
                      onToggleObscure: () => setState(() {
                        _obscureSecretPassword = !_obscureSecretPassword;
                      }),
                    ),
                    const Divider(height: 32, indent: 40),
                    _buildTextField(
                      controller: _vaultExportPasswordController,
                      label: 'Vault Export Password',
                      hint: 'Default: super123',
                      icon: Icons.shield,
                      isPassword: true,
                      obscure: _obscureVaultPassword,
                      onToggleObscure: () => setState(() {
                        _obscureVaultPassword = !_obscureVaultPassword;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Widget Timers', primaryText),
              _buildCard(
                cardBg,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update the timers on the Home Screen Widget',
                      style: AppTypography.bodySmall.copyWith(color: secondaryText),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimerField(
                            controller: _timer1Controller,
                            label: 'Timer 1',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimerField(
                            controller: _timer2Controller,
                            label: 'Timer 2',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimerField(
                            controller: _timer3Controller,
                            label: 'Timer 3',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('App Behavior', primaryText),
              _buildCard(
                cardBg,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose which screen appears when you open the app',
                      style: AppTypography.bodySmall.copyWith(color: secondaryText),
                    ),
                    const SizedBox(height: 12),
                    _buildDefaultScreenPicker(cardBg),
                  ],
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
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.govBlue),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.slate300,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildTimerField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: AppTypography.titleMedium.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
        suffixText: 'min',
        suffixStyle: AppTypography.bodySmall.copyWith(color: AppColors.slate500),
        filled: true,
        fillColor: AppColors.slate800.withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  void _saveSettings() async {
    final sidebar = _sidebarNameController.text.trim();
    final schedule = _scheduleNameController.text.trim();
    final password = _passwordController.text.trim();

    final finalSidebar = sidebar.isEmpty ? 'Avishek Shrestha' : sidebar;
    final finalSchedule = schedule.isEmpty ? 'xArE0' : schedule;

    final vaultExportPw = _vaultExportPasswordController.text.trim();

    await SettingsService.instance.updateSidebarName(finalSidebar);
    await SettingsService.instance.updateScheduleName(finalSchedule);
    await SettingsService.instance.updateSecretPassword(password);
    await SettingsService.instance.updateVaultExportPassword(vaultExportPw);

    // Save widget timer durations
    final t1 = int.tryParse(_timer1Controller.text.trim()) ?? 5;
    final t2 = int.tryParse(_timer2Controller.text.trim()) ?? 15;
    final t3 = int.tryParse(_timer3Controller.text.trim()) ?? 30;
    await SettingsService.instance.updateWidgetTimers(t1, t2, t3);
    await SettingsService.instance.updateDefaultScreen(_selectedDefaultScreen);

    if (mounted) {
      AppToast.show(context, 'Settings saved');
      Navigator.pop(context);
    }
  }

  static const _screenOptions = [
    {'key': 'schedule', 'label': 'Schedule', 'icon': Icons.calendar_today},
    {'key': 'datavault', 'label': 'Data Vault', 'icon': Icons.lock},
    {'key': 'expense', 'label': 'Expense Tracker', 'icon': Icons.list},
    {'key': 'logbook', 'label': 'Logbook', 'icon': Icons.menu_book},
    {'key': 'cooldown', 'label': 'Cooldown', 'icon': Icons.timer},
    {'key': 'quickcheck', 'label': 'MCQ Practice', 'icon': Icons.assignment_outlined},
    {'key': 'routine', 'label': 'Routine', 'icon': Icons.repeat_rounded},
  ];

  Widget _buildDefaultScreenPicker(Color cardBg) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _screenOptions.map((opt) {
        final key = opt['key'] as String;
        final label = opt['label'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = _selectedDefaultScreen == key;

        return GestureDetector(
          onTap: () => setState(() => _selectedDefaultScreen = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.govBlue.withOpacity(0.15)
                  : AppColors.slate800.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.govBlue.withOpacity(0.6)
                    : AppColors.slate700.withOpacity(0.5),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isSelected ? AppColors.govBlue : AppColors.slate400),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.govBlue : AppColors.slate300,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle, size: 14, color: AppColors.govBlue),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
