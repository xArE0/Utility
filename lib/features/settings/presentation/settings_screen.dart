import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _sidebarNameController = TextEditingController();
  final _scheduleNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vaultExportPasswordController = TextEditingController();
  final _timer1Controller = TextEditingController();
  final _timer2Controller = TextEditingController();
  final _awakeController = TextEditingController();

  bool _obscureSecretPassword = true;
  bool _obscureVaultPassword = true;
  String _selectedDefaultScreen = 'schedule';

  /// Local copy of hidden sidebar keys — mutated by toggles, flushed on Save.
  late Set<String> _hiddenItems;

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
    _awakeController.text = settings.widgetAwakeMinutes.toString();
    _selectedDefaultScreen = settings.defaultScreen;
    _hiddenItems = Set.from(settings.sidebarHiddenItems);
    WidgetsBinding.instance.addObserver(this);
    HomeWidgetService.instance.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the "Modify system settings" screen: re-check the permission.
    if (state == AppLifecycleState.resumed) HomeWidgetService.instance.refresh();
  }

  @override
  void dispose() {
    _sidebarNameController.dispose();
    _scheduleNameController.dispose();
    _passwordController.dispose();
    _vaultExportPasswordController.dispose();
    _timer1Controller.dispose();
    _timer2Controller.dispose();
    _awakeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.slate50 : AppColors.slate900;
    final secondaryText = isDark ? AppColors.slate300 : Colors.grey[600]!;
    final cardBg =
        isDark ? AppColors.slate900.withValues(alpha: 0.55) : Colors.grey[100]!;

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
              _buildSectionTitle('Home Screen Widget', primaryText),
              _buildCard(
                cardBg,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timer buttons, and how long the screen stays on while ☀ is lit',
                      style: AppTypography.bodySmall
                          .copyWith(color: secondaryText),
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
                            controller: _awakeController,
                            label: 'Stay awake',
                          ),
                        ),
                      ],
                    ),
                    ListenableBuilder(
                      listenable: HomeWidgetService.instance,
                      builder: (context, _) {
                        if (HomeWidgetService.instance.state.canWriteSettings) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: Color(0xFFFBBF24)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Stay awake needs "Modify system settings"',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: secondaryText),
                                ),
                              ),
                              TextButton(
                                onPressed: HomeWidgetService
                                    .instance.openWriteSettings,
                                child: const Text('Allow'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // ── Merged App Behavior card ──────────────────────────────────
              _buildSectionTitle('App Behavior', primaryText),
              _buildCard(
                cardBg,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apps_outlined,
                            size: 16, color: AppColors.govBlue),
                        const SizedBox(width: 6),
                        Text(
                          'Screens & sidebar',
                          style: AppTypography.labelLarge
                              .copyWith(color: secondaryText),
                        ),
                        const Spacer(),
                        Text(
                          '${_screenOptions.length - _hiddenItems.length} visible',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.slate500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the screen that opens at launch, then choose which screens appear in the sidebar.',
                      style: AppTypography.bodySmall.copyWith(
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildScreenAccessList(),
                  ],
                ),
              ),
              // FAB clearance
              const SizedBox(height: 80),
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
        border: Border.all(color: AppColors.slate700.withValues(alpha: 0.5)),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        suffixStyle:
            AppTypography.bodySmall.copyWith(color: AppColors.slate500),
        filled: true,
        fillColor: AppColors.slate800.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

    // Save widget timer and stay-awake durations
    final t1 = int.tryParse(_timer1Controller.text.trim()) ?? 5;
    final t2 = int.tryParse(_timer2Controller.text.trim()) ?? 15;
    final awake = int.tryParse(_awakeController.text.trim()) ?? 10;
    await SettingsService.instance.updateWidgetSettings(t1, t2, awake);
    await SettingsService.instance.updateDefaultScreen(_selectedDefaultScreen);
    await SettingsService.instance.updateSidebarHiddenItems(_hiddenItems);

    if (mounted) {
      AppToast.show(context, 'Settings saved');
      Navigator.pop(context);
    }
  }

  // ── Screen / sidebar options ─────────────────────────────────────────────

  static const _screenOptions = [
    {'key': 'schedule', 'label': 'Schedule', 'icon': Icons.calendar_today},
    {'key': 'datavault', 'label': 'Data Vault', 'icon': Icons.lock},
    {'key': 'expense', 'label': 'Expense Tracker', 'icon': Icons.list},
    {'key': 'logbook', 'label': 'Logbook', 'icon': Icons.menu_book},
    {'key': 'cooldown', 'label': 'Cooldown', 'icon': Icons.timer},
    {
      'key': 'quickcheck',
      'label': 'MCQ Practice',
      'icon': Icons.assignment_outlined
    },
    {'key': 'routine', 'label': 'Routine', 'icon': Icons.repeat_rounded},
    {'key': 'autoclicker', 'label': 'Auto Clicker', 'icon': Icons.ads_click},
    {
      'key': 'volume',
      'label': 'Volume Schedule',
      'icon': Icons.volume_up_rounded
    },
    {
      'key': 'importexport',
      'label': 'Import/Export',
      'icon': Icons.import_export_sharp
    },
  ];

  // ── Unified launch screen and sidebar visibility controls ────────────────

  Widget _buildScreenAccessList() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: _screenOptions.map((opt) {
        final key = opt['key'] as String;
        final label = opt['label'] as String;
        final icon = opt['icon'] as IconData;
        final isLaunchScreen = _selectedDefaultScreen == key;
        final isVisible = !_hiddenItems.contains(key);
        final isSchedule = key == 'schedule';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isLaunchScreen
                ? AppColors.govBlue.withValues(alpha: 0.12)
                : (isVisible
                    ? AppColors.govGreen.withValues(alpha: 0.07)
                    : AppColors.slate800.withValues(alpha: 0.28)),
            border: Border(
              bottom: BorderSide(
                color: AppColors.slate700.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8, right: 4),
            leading: Icon(
              icon,
              color: isVisible ? AppColors.govGreen : AppColors.slate600,
            ),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: isLaunchScreen ? FontWeight.w700 : FontWeight.w500,
                color: isVisible ? AppColors.slate200 : AppColors.slate600,
                decoration: isVisible ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: isLaunchScreen || isSchedule
                ? Text(
                    isLaunchScreen ? 'Launch screen' : 'Always available',
                    style: AppTypography.bodySmall.copyWith(
                        color: isLaunchScreen
                            ? AppColors.govBlue
                            : AppColors.slate500),
                  )
                : null,
            onTap: () => setState(() => _selectedDefaultScreen = key),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: key,
                  groupValue: _selectedDefaultScreen,
                  activeColor: AppColors.govBlue,
                  onChanged: (value) =>
                      setState(() => _selectedDefaultScreen = value!),
                ),
                if (isSchedule)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.visibility, size: 20),
                  )
                else
                  Switch(
                    value: isVisible,
                    activeThumbColor: AppColors.govGreen,
                    onChanged: (visible) => setState(() {
                      if (visible) {
                        _hiddenItems.remove(key);
                      } else {
                        _hiddenItems.add(key);
                      }
                    }),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
      ),
    );
  }
}
