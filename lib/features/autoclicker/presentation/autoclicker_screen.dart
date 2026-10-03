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

const _accent = AppColors.coral;

const _intervalPresets = [
  (label: '100 ms', ms: 100),
  (label: '250 ms', ms: 250),
  (label: '500 ms', ms: 500),
  (label: '1 s', ms: 1000),
  (label: '2 s', ms: 2000),
  (label: '5 s', ms: 5000),
];

const _swipeIntervalPresets = [
  (label: '1 s', ms: 1000),
  (label: '2 s', ms: 2000),
  (label: '3 s', ms: 3000),
  (label: '5 s', ms: 5000),
  (label: '10 s', ms: 10000),
  (label: '30 s', ms: 30000),
];

const _swipeSpeeds = [
  (label: 'Fast', ms: 200),
  (label: 'Normal', ms: 350),
  (label: 'Slow', ms: 700),
];

const _directionIcons = {
  ScrollDirection.up: Icons.arrow_upward_rounded,
  ScrollDirection.down: Icons.arrow_downward_rounded,
  ScrollDirection.left: Icons.arrow_back_rounded,
  ScrollDirection.right: Icons.arrow_forward_rounded,
};

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
                  _buildModeSelector(),
                  const SizedBox(height: 12),
                  switch (_controller.config.mode) {
                    AutoClickerMode.click => _buildSettingsCard(),
                    AutoClickerMode.scroll => _buildScrollCard(),
                    AutoClickerMode.play => _buildReplayCard(),
                  },
                  const SizedBox(height: 12),
                  _buildControlCard(),
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
          ..._buildStopSection(),
        ],
      ),
    );
  }

  /// "Stop: never / after N" — counts clicks, swipes or replay loops by mode.
  List<Widget> _buildStopSection() {
    final unit = _controller.config.mode.unit;
    final replay = _controller.config.mode == AutoClickerMode.play;
    return [
      Text(replay ? 'Repeat' : 'Stop', style: AppTypography.titleMedium),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: Text(replay ? 'Forever' : 'Never'),
            selected: !_limited,
            onSelected: (_) => _setLimited(false),
          ),
          ChoiceChip(
            label: Text(replay ? 'A set number of times' : 'After a set number of $unit'),
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
          decoration: InputDecoration(suffixText: replay ? 'times' : unit, isDense: true),
        ),
      ],
    ];
  }

  // ── Mode ─────────────────────────────────────────────────────────────────

  Widget _buildModeSelector() {
    final status = _controller.status;
    final locked = status.running || status.recording;
    return SegmentedButton<AutoClickerMode>(
      segments: const [
        ButtonSegment(value: AutoClickerMode.click, icon: Icon(Icons.ads_click), label: Text('Click')),
        ButtonSegment(value: AutoClickerMode.scroll, icon: Icon(Icons.swipe_vertical_rounded), label: Text('Scroll')),
        ButtonSegment(value: AutoClickerMode.play, icon: Icon(Icons.replay_rounded), label: Text('Replay')),
      ],
      selected: {_controller.config.mode},
      showSelectedIcon: false,
      onSelectionChanged: locked
          ? null
          : (sel) {
              final mode = sel.first;
              // Each mode has its own sensible pace; keep the user's value if it fits.
              if (mode == AutoClickerMode.scroll && _controller.config.intervalMs < 1000) {
                _onPreset(2000);
              }
              _controller.setMode(mode);
            },
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.govBlue.withValues(alpha: 0.18),
        selectedForegroundColor: AppColors.govBlue,
        foregroundColor: AppColors.slate300,
        side: const BorderSide(color: AppColors.slate600),
        textStyle: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Scroll ───────────────────────────────────────────────────────────────

  Widget _buildScrollCard() {
    final c = _controller.config;
    final typed = int.tryParse(_intervalCtrl.text.trim());
    final minGap = c.swipeMs + 150;
    final tooFast = typed != null && typed < minGap;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Swipe', style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Text('Through the ring. Up moves to the next item, like swiping reels.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.slate400)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in ScrollDirection.values)
                ChoiceChip(
                  avatar: Icon(_directionIcons[d], size: 18,
                      color: c.scrollDirection == d ? AppColors.govBlue : AppColors.slate300),
                  showCheckmark: false,
                  label: Text(d.label),
                  selected: c.scrollDirection == d,
                  onSelected: (_) => _controller.setScrollDirection(d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Length', style: AppTypography.bodyMedium),
              const Spacer(),
              Text('${c.scrollDistancePct}% of the screen',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.slate400)),
            ],
          ),
          Slider(
            value: c.scrollDistancePct.toDouble(),
            min: 20,
            max: 80,
            divisions: 12,
            label: '${c.scrollDistancePct}%',
            onChanged: (v) => _controller.setScrollDistance(v.round()),
          ),
          Text('Speed', style: AppTypography.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final sp in _swipeSpeeds)
                ChoiceChip(
                  label: Text(sp.label),
                  selected: c.swipeMs == sp.ms,
                  onSelected: (_) => _controller.setSwipeMs(sp.ms),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Swipe every', style: AppTypography.titleMedium),
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
              helperText: tooFast
                  ? 'Each swipe needs about $minGap ms, so they run back to back'
                  : _describeEvery(c.intervalMs, 'swipe'),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _swipeIntervalPresets)
                ChoiceChip(
                  label: Text(p.label),
                  selected: c.intervalMs == p.ms,
                  onSelected: (_) {
                    _onPreset(p.ms);
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          ..._buildStopSection(),
        ],
      ),
    );
  }

  String _describeEvery(int ms, String what) {
    final s = ms / 1000;
    return 'One $what every ${s == s.roundToDouble() ? s.round() : s.toStringAsFixed(1)} s';
  }

  // ── Replay ───────────────────────────────────────────────────────────────

  Widget _buildReplayCard() {
    final recs = _controller.recordings;
    final selectedId = _controller.config.recordingId;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Recordings', style: AppTypography.titleMedium)),
              TextButton.icon(
                onPressed: _controller.busy || _controller.status.recording
                    ? null
                    : () async => _showError(await _controller.startRecording()),
                icon: const Icon(Icons.fiber_manual_record, size: 16, color: AppColors.error),
                label: const Text('Record new'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            recs.isEmpty
                ? 'Nothing recorded yet. Tap "Record new", do the taps and swipes in any app, then tap ■ on the bubble.'
                : 'Pick one to replay. Touches are replayed with their original timing.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
          ),
          if (recs.isNotEmpty) const SizedBox(height: 8),
          for (final r in recs) _buildRecordingTile(r, r.id == selectedId),
          const SizedBox(height: 16),
          ..._buildStopSection(),
        ],
      ),
    );
  }

  Widget _buildRecordingTile(AutoClickerRecording r, bool selected) {
    final secs = r.lengthMs / 1000;
    final length = secs < 60
        ? '${secs.toStringAsFixed(secs < 10 ? 1 : 0)} s'
        : '${(secs / 60).floor()} min ${(secs % 60).round()} s';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: selected ? AppColors.govBlue.withValues(alpha: 0.12) : AppColors.slate800.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.govBlue.withValues(alpha: 0.6) : AppColors.slate700),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _controller.selectRecording(r.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20, color: selected ? AppColors.govBlue : AppColors.slate500),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                      Text('${r.steps} ${r.steps == 1 ? 'touch' : 'touches'} · $length',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.slate400)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.slate400),
                  onPressed: () => _renameRecording(r),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  onPressed: () => _deleteRecording(r),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renameRecording(AutoClickerRecording r) async {
    final ctrl = TextEditingController(text: r.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename recording'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      _showError(await _controller.renameRecording(r.id, name));
    }
  }

  Future<void> _deleteRecording(AutoClickerRecording r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${r.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) _showError(await _controller.deleteRecording(r.id));
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
    final mode = _controller.config.mode;

    if (status.recording) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Recording · ${status.recordedCount} touches',
                      style: AppTypography.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Stop with ■ on the bubble, from the notification, or here.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.slate300)),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Stop Recording',
              icon: Icons.stop_rounded,
              width: double.infinity,
              isLoading: _controller.busy,
              onPressed: () async => _showError(await _controller.stopRecording()),
            ),
          ],
        ),
      );
    }

    final startLabel = switch (mode) {
      AutoClickerMode.click => 'Start Clicking',
      AutoClickerMode.scroll => 'Start Scrolling',
      AutoClickerMode.play => 'Play Recording',
    };
    final noRecording = mode == AutoClickerMode.play && _controller.selectedRecording == null;

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
                  status.running
                      ? switch (mode) {
                          AutoClickerMode.click => 'Clicking · ${status.taps} taps',
                          AutoClickerMode.scroll => 'Scrolling · ${status.taps} swipes',
                          AutoClickerMode.play => 'Replaying · loop ${status.taps + 1}',
                        }
                      : 'Floating controls are on screen',
                  style: AppTypography.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.running
                ? 'Stop here, from the notification, or from the bubble.'
                : switch (mode) {
                    AutoClickerMode.click =>
                      'Drag the ring over what you want to click, then start here, from the notification, or from the bubble.',
                    AutoClickerMode.scroll =>
                      'Drag the ring to the middle of what should scroll, then start. ● on the bubble records instead.',
                    AutoClickerMode.play => noRecording
                        ? 'Pick a recording above, or tap ● on the bubble to record one.'
                        : 'Open the app it was recorded in, then start here, from the notification, or from the bubble.',
                  },
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: status.running ? 'Stop' : startLabel,
            icon: status.running ? Icons.stop_rounded : Icons.play_arrow_rounded,
            width: double.infinity,
            isLoading: _controller.busy,
            onPressed: !status.running && noRecording
                ? null
                : () async => _showError(
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
}
