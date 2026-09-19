import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/android_autoclicker_repository.dart';
import '../domain/autoclicker_entities.dart';
import 'autoclicker_controller.dart';

const _accent = Color(0xFFF97316);

const _intervalPresets = [
  (label: '100 ms', ms: 100),
  (label: '250 ms', ms: 250),
  (label: '500 ms', ms: 500),
  (label: '1 s', ms: 1000),
  (label: '2 s', ms: 2000),
  (label: '5 s', ms: 5000),
];

class AutoClickerScreen extends StatefulWidget {
  const AutoClickerScreen({super.key});

  @override
  State<AutoClickerScreen> createState() => _AutoClickerScreenState();
}

class _AutoClickerScreenState extends State<AutoClickerScreen> with WidgetsBindingObserver {
  late final AutoClickerController _controller;
  final _intervalCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  bool _limited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AutoClickerController(repository: AndroidAutoClickerRepository());
    _controller.addListener(_onControllerNotify);
    _controller.init().then((_) {
      if (!mounted) return;
      _intervalCtrl.text = _controller.config.intervalMs.toString();
      _limited = !_controller.config.isUnlimited;
      if (_limited) _limitCtrl.text = _controller.config.maxClicks.toString();
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerNotify);
    _controller.dispose();
    _intervalCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _onControllerNotify() {
    if (mounted) setState(() {});
  }

  // Coming back from Android's accessibility settings: pick up the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refresh();
  }

  void _showError(String? message) {
    if (message != null && mounted) AppToast.show(context, message, isError: true);
  }

  void _onIntervalTyped(String text) {
    final ms = int.tryParse(text.trim());
    if (ms != null && ms >= AutoClickerConfig.minIntervalMs) _controller.setInterval(ms);
  }

  void _onPreset(int ms) {
    _intervalCtrl.text = ms.toString();
    _controller.setInterval(ms);
  }

  void _onLimitTyped(String text) {
    final n = int.tryParse(text.trim());
    if (n != null && n > 0) _controller.setMaxClicks(n);
  }

  void _setLimited(bool limited) {
    setState(() => _limited = limited);
    if (limited) {
      final n = _controller.config.isUnlimited ? 100 : _controller.config.maxClicks;
      _limitCtrl.text = n.toString();
      _controller.setMaxClicks(n);
    } else {
      _controller.setMaxClicks(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Auto Clicker', style: AppTypography.titleLarge),
          backgroundColor: AppColors.slate900.withValues(alpha: 0.85),
        ),
        body: _controller.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildServiceCard(),
                  const SizedBox(height: 12),
                  _buildSettingsCard(),
                  const SizedBox(height: 12),
                  _buildControlCard(),
                  const SizedBox(height: 12),
                  _buildHelpCard(),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  // ── Accessibility service ────────────────────────────────────────────────

  Widget _buildServiceCard() {
    final status = _controller.status;
    final ready = status.serviceConnected;
    final waiting = status.serviceEnabled && !status.serviceConnected;

    final Color color;
    final IconData icon;
    final String title;
    if (ready) {
      color = AppColors.govGreen;
      icon = Icons.verified_user_rounded;
      title = 'Accessibility service is on';
    } else if (waiting) {
      color = AppColors.govGold;
      icon = Icons.hourglass_top_rounded;
      title = 'Enabled, but not running yet';
    } else {
      color = AppColors.govGold;
      icon = Icons.error_outline_rounded;
      title = 'Accessibility service is off';
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppTypography.titleMedium)),
            ],
          ),
          if (waiting) ...[
            const SizedBox(height: 12),
            Text(
              status.isXiaomi
                  ? 'HyperOS closed the app in the background and took the service down with it. '
                      'This is normal on Xiaomi/Redmi/POCO unless Autostart is on — grant it below so '
                      'this stops happening.'
                  : 'Android closed the app in the background and took the service down with it. '
                      'Switch "Utility Auto Clicker" off and on again in Accessibility settings.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
            ),
            const SizedBox(height: 12),
            if (status.isXiaomi)
              CustomButton(
                text: 'Open Autostart Settings',
                icon: Icons.bolt_rounded,
                width: double.infinity,
                onPressed: _controller.busy
                    ? null
                    : () async => _showError(await _controller.openAutostartSettings()),
              ),
            if (status.isXiaomi) const SizedBox(height: 8),
            if (status.isXiaomi)
              Text(
                'Then also set Battery saver to "No restrictions" for Utility, and lock the app card '
                'in Recents (swipe it down) so "Clear all" leaves it alone.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
              ),
            if (status.isXiaomi) const SizedBox(height: 8),
            CustomButton(
              text: 'Open Accessibility Settings',
              icon: Icons.settings_accessibility_rounded,
              variant: status.isXiaomi ? ButtonVariant.outline : ButtonVariant.primary,
              width: double.infinity,
              onPressed: _controller.busy
                  ? null
                  : () async => _showError(await _controller.openAccessibilitySettings()),
            ),
          ] else if (!ready) ...[
            const SizedBox(height: 12),
            Text(
              'Android needs this permission so the app can tap other apps for you. '
              'Open Accessibility settings and switch on "Utility Auto Clicker".',
              style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Open Accessibility Settings',
              icon: Icons.settings_accessibility_rounded,
              width: double.infinity,
              onPressed: _controller.busy
                  ? null
                  : () async => _showError(await _controller.openAccessibilitySettings()),
            ),
            const SizedBox(height: 12),
            Text(
              'Switch greyed out, or says "Restricted setting"? On Android 13+ apps installed from a '
              'file are blocked from this. Open App info, tap the ⋮ menu, choose "Allow restricted '
              'settings", then try again.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Open App Info',
              icon: Icons.info_outline_rounded,
              variant: ButtonVariant.outline,
              width: double.infinity,
              onPressed: _controller.busy ? null : () async => _showError(await _controller.openAppInfo()),
            ),
          ],
        ],
      ),
    );
  }

  // ── Interval / limit ─────────────────────────────────────────────────────

  Widget _buildSettingsCard() {
    final ms = _controller.config.intervalMs;
    final typed = int.tryParse(_intervalCtrl.text.trim());
    final invalid = typed == null || typed < AutoClickerConfig.minIntervalMs;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Click every', style: AppTypography.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _intervalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTypography.bodyLarge,
            onChanged: (v) {
              _onIntervalTyped(v);
              setState(() {});
            },
            decoration: InputDecoration(
              suffixText: 'ms',
              helperText: invalid ? null : _describeInterval(ms),
              errorText: invalid ? 'Minimum ${AutoClickerConfig.minIntervalMs} ms' : null,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _intervalPresets)
                ChoiceChip(
                  label: Text(p.label),
                  selected: !invalid && ms == p.ms,
                  onSelected: (_) {
                    _onPreset(p.ms);
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Stop', style: AppTypography.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Never'),
                selected: !_limited,
                onSelected: (_) => _setLimited(false),
              ),
              ChoiceChip(
                label: const Text('After a set number of clicks'),
                selected: _limited,
                onSelected: (_) => _setLimited(true),
              ),
            ],
          ),
          if (_limited) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _limitCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTypography.bodyLarge,
              onChanged: _onLimitTyped,
              decoration: const InputDecoration(suffixText: 'clicks', isDense: true),
            ),
          ],
        ],
      ),
    );
  }

  String _describeInterval(int ms) {
    if (ms >= 1000) {
      final s = ms / 1000;
      return 'One click every ${s == s.roundToDouble() ? s.round() : s.toStringAsFixed(2)} s';
    }
    return '≈ ${(1000 / ms).toStringAsFixed(1)} clicks per second';
  }

  // ── Start / stop ─────────────────────────────────────────────────────────

  Widget _buildControlCard() {
    final status = _controller.status;

    if (!status.overlayVisible) {
      return CustomButton(
        text: 'Show Floating Controls',
        icon: Icons.ads_click,
        width: double.infinity,
        isLoading: _controller.busy,
        onPressed: () async => _showError(await _controller.showOverlay()),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.running ? Icons.mouse_rounded : Icons.ads_click,
                color: status.running ? AppColors.govGreen : _accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status.running ? 'Clicking · ${status.taps} taps' : 'Floating controls are on screen',
                  style: AppTypography.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.running
                ? 'Stop here, from the notification, or from the bubble.'
                : 'Drag the ring over what you want to click, then start here, from the notification, or from the bubble.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: status.running ? 'Stop Clicking' : 'Start Clicking',
            icon: status.running ? Icons.stop_rounded : Icons.play_arrow_rounded,
            width: double.infinity,
            isLoading: _controller.busy,
            onPressed: () async => _showError(
              status.running ? await _controller.stopClicking() : await _controller.startClicking(),
            ),
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: 'Hide Floating Controls',
            icon: Icons.close_rounded,
            variant: ButtonVariant.secondary,
            width: double.infinity,
            onPressed: _controller.busy ? null : () async => _showError(await _controller.hideOverlay()),
          ),
        ],
      ),
    );
  }

  // ── Help ─────────────────────────────────────────────────────────────────

  Widget _buildHelpCard() {
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.2),
                ),
                child: Text(n, style: AppTypography.bodySmall.copyWith(color: _accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: AppTypography.bodySmall.copyWith(color: AppColors.slate300)),
              ),
            ],
          ),
        );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: AppTypography.titleMedium),
          const SizedBox(height: 12),
          step('1', 'Switch on the accessibility service above (one time).'),
          step('2', 'Tap "Show Floating Controls". This app steps aside.'),
          step('3', 'Open the app you want to click in and drag the small ring over the button.'),
          step('4', 'Tap the small bubble to open its controls, then press ▶. It taps under the ring until you press ■.'),
          step('5', 'Keep the bubble away from the ring, or the bubble will be what gets tapped.'),
          const SizedBox(height: 4),
          Text(
            'The notification also has Start / Stop and Close. On Xiaomi / HyperOS, if '
            'the clicker dies after you swipe the app away, allow Autostart and set battery to '
            '"No restrictions" for this app.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
          ),
        ],
      ),
    );
  }
}
