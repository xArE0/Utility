import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/android_volume_repository.dart';
import '../domain/volume_entities.dart';
import 'volume_controller.dart';

const _accent = AppColors.teal;

/// Week starts on Sunday (Nepal). Values are [DateTime.weekday] numbers.
const _weekdays = [
  (day: 7, short: 'Sun'),
  (day: 1, short: 'Mon'),
  (day: 2, short: 'Tue'),
  (day: 3, short: 'Wed'),
  (day: 4, short: 'Thu'),
  (day: 5, short: 'Fri'),
  (day: 6, short: 'Sat'),
];

class VolumeScreen extends StatefulWidget {
  const VolumeScreen({super.key});

  @override
  State<VolumeScreen> createState() => _VolumeScreenState();
}

class _VolumeScreenState extends State<VolumeScreen>
    with WidgetsBindingObserver {
  late final VolumeController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VolumeController(repository: AndroidVolumeRepository());
    _controller.addListener(_onControllerNotify);
    _controller.init().then(_showError);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerNotify);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerNotify() {
    if (mounted) setState(() {});
  }

  // Live updates only while visible; catch up on anything that changed while we were away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.startListening();
      _controller.refresh();
    } else if (state == AppLifecycleState.paused) {
      _controller.stopListening();
    }
  }

  void _showError(String? message) {
    if (message != null && mounted) {
      AppToast.show(context, message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Volume Schedule', style: AppTypography.titleLarge),
          backgroundColor: AppColors.slate900.withValues(alpha: 0.85),
        ),
        floatingActionButton: _controller.loading
            ? null
            : FloatingActionButton.extended(
                backgroundColor: _accent,
                foregroundColor: AppColors.onAccent,
                onPressed: () => _openEditor(null),
                icon: const Icon(Icons.add),
                label: const Text('Add change'),
              ),
        body: _controller.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _buildNowCard(),
                    // Hidden once granted; still shown if the ROM won't report it.
                    if (_controller.state.isXiaomi &&
                        _controller.state.autostart != 'allowed') ...[
                      const SizedBox(height: 12),
                      _buildAutostartCard(),
                    ],
                    const SizedBox(height: 16),
                    ..._buildRules(),
                    const SizedBox(height: 16),
                    _buildLogCard(),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Current levels ───────────────────────────────────────────────────────

  Widget _buildNowCard() {
    final state = _controller.state;
    final next = state.nextChange;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: _accent),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Right now', style: AppTypography.titleMedium)),
              if (state.ringerMode != 'normal')
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    state.ringerMode == 'vibrate'
                        ? Icons.vibration
                        : Icons.volume_off,
                    size: 16,
                    color: AppColors.govGold,
                  ),
                  label: Text(
                      state.ringerMode == 'vibrate' ? 'Vibrate' : 'Silent'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final stream in VolumeStream.values)
            if (state.streams[stream] != null)
              _levelRow(stream, state.streams[stream]!),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'No changes scheduled.'
                : 'Next change: ${_describeWhen(next)}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
          ),
          if (state.ringerMode != 'normal') ...[
            const SizedBox(height: 4),
            Text(
              'Ring and notification changes are skipped while the phone is on '
              '${state.ringerMode}, so the schedule never takes it off silent.',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.slate400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutostartCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.govGold),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Allow Autostart',
                      style: AppTypography.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'On Xiaomi/Redmi/POCO, scheduled changes won\'t run after you swipe the app away or '
            'restart the phone unless Autostart is on for Utility.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Open Autostart Settings',
            icon: Icons.bolt_rounded,
            variant: ButtonVariant.outline,
            width: double.infinity,
            onPressed: () async =>
                _showError(await _controller.openAutostartSettings()),
          ),
        ],
      ),
    );
  }

  Widget _levelRow(VolumeStream stream, StreamInfo info) {
    final fraction = info.max == 0 ? 0.0 : info.current / info.max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 96,
              child: Text(stream.label, style: AppTypography.bodyMedium)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                color: _accent,
                backgroundColor: AppColors.slate700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(
              '${info.current}/${info.max} · ${info.percentOf(info.current)}%',
              textAlign: TextAlign.end,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.slate300),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rules ────────────────────────────────────────────────────────────────

  List<Widget> _buildRules() {
    final rules = _controller.rules;
    if (rules.isEmpty) {
      return [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No scheduled changes yet',
                  style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Each change sets one or more volumes at a time of day. For "quiet at the '
                'office", add two: e.g. 9:00 AM → Notification 30%, and 6:00 PM → Notification 90%.',
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.slate300),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      for (final rule in rules) ...[
        _ruleCard(rule),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _ruleCard(VolumeRule rule) {
    final muted = !rule.enabled;
    return Opacity(
      opacity: muted ? 0.5 : 1,
      child: GlassCard(
        onTap: () => _openEditor(rule),
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(_formatTime(rule.hour, rule.minute),
                          style: AppTypography.headlineSmall),
                      if (rule.label.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            rule.label,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.slate300),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rule.once ? _describeOnce(rule) : _describeDays(rule.days),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.slate400),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final stream in VolumeStream.values)
                        if (rule.levels[stream] != null)
                          _levelChip(stream, rule.levels[stream]!),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: rule.enabled,
                  activeTrackColor: _accent,
                  onChanged: (v) async =>
                      _showError(await _controller.setEnabled(rule, v)),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) async {
                    if (action == 'apply') {
                      final error = await _controller.applyNow(rule);
                      _showError(error);
                      if (error == null && mounted) {
                        AppToast.show(context, 'Applied');
                      }
                    } else if (action == 'delete') {
                      _showError(await _controller.delete(rule.id));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'apply', child: Text('Apply now')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelChip(VolumeStream stream, int percent) {
    final info = _controller.state.streams[stream];
    final step = info?.stepFor(percent, isRinger: stream.isRinger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        step == null
            ? '${stream.label} $percent%'
            : '${stream.label} $percent% · $step/${info!.max}',
        style: AppTypography.bodySmall.copyWith(color: AppColors.slate200),
      ),
    );
  }

  // ── Run log ──────────────────────────────────────────────────────────────

  Widget _buildLogCard() {
    final log = _controller.state.log;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent runs', style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Recorded even while the app is closed, so you can check the schedule actually fired.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
          ),
          const SizedBox(height: 8),
          if (log.isEmpty)
            Text('Nothing yet.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.slate300)),
          for (final entry in log.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('EEE d MMM, h:mm a').format(entry.at)}'
                    '${entry.label.isEmpty ? '' : ' · ${entry.label}'}'
                    '${entry.manual ? ' · manual' : ''}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.slate200),
                  ),
                  Text(
                    entry.result.isEmpty
                        ? 'No volumes set'
                        : entry.result.join(', '),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.slate400),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Editor ───────────────────────────────────────────────────────────────

  Future<void> _openEditor(VolumeRule? existing) async {
    final rule = await showModalBottomSheet<VolumeRule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.slate800,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _RuleEditor(existing: existing, streams: _controller.state.streams),
    );
    if (rule != null) _showError(await _controller.upsert(rule));
  }

  // ── Formatting ───────────────────────────────────────────────────────────

  String _describeOnce(VolumeRule rule) {
    final at = rule.onceRunAt;
    if (at == null || !at.isAfter(DateTime.now())) {
      return 'Once · off, switch on to run again';
    }
    return 'Once · runs ${_describeWhen(at)}';
  }

  String _describeWhen(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = day.difference(today).inDays;
    final time = DateFormat('h:mm a').format(at);
    if (diff == 0) return 'today at $time';
    if (diff == 1) return 'tomorrow at $time';
    return '${DateFormat('EEEE').format(at)} at $time';
  }
}

String _formatTime(int hour, int minute) =>
    DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour, minute));

String _describeDays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.isEmpty) return 'No days selected';
  if (days.length == 6 && !days.contains(6)) return 'Sun – Fri';
  if (days.length == 5 && days.containsAll(const [1, 2, 3, 4, 5])) {
    return 'Mon – Fri';
  }
  return _weekdays
      .where((w) => days.contains(w.day))
      .map((w) => w.short)
      .join(', ');
}

class _RuleEditor extends StatefulWidget {
  final VolumeRule? existing;
  final Map<VolumeStream, StreamInfo> streams;

  const _RuleEditor({required this.existing, required this.streams});

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final TextEditingController _labelCtrl;
  late TimeOfDay _time;
  late Set<int> _days;
  late Map<VolumeStream, int> _levels;
  late bool _once;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _labelCtrl = TextEditingController(text: r?.label ?? '');
    _time = TimeOfDay(hour: r?.hour ?? 9, minute: r?.minute ?? 0);
    _days = {
      ...(r?.days ?? const {7, 1, 2, 3, 4, 5})
    };
    _levels = {
      ...(r?.levels ?? const {VolumeStream.notification: 30})
    };
    _once = r?.once ?? false;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  bool get _valid => (_once || _days.isNotEmpty) && _levels.isNotEmpty;

  void _save() {
    final existing = widget.existing;
    final rule = VolumeRule(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: _labelCtrl.text.trim(),
      hour: _time.hour,
      minute: _time.minute,
      days: _days,
      enabled: existing?.enabled ?? true,
      levels: _levels,
      once: _once,
      armedAt: existing?.armedAt,
    );
    Navigator.pop(context, rule);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.existing == null ? 'New change' : 'Edit change',
                  style: AppTypography.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: _time);
                      if (picked != null) setState(() => _time = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Text(_formatTime(_time.hour, _time.minute),
                              style: AppTypography.headlineMedium
                                  .copyWith(color: _accent)),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 16, color: _accent),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _labelCtrl,
                      style: AppTypography.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'Label (e.g. Office)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Repeat'),
                      icon: Icon(Icons.repeat)),
                  ButtonSegment(
                      value: true,
                      label: Text('Once'),
                      icon: Icon(Icons.looks_one_outlined)),
                ],
                selected: {_once},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _once = v.first),
              ),
              const SizedBox(height: 12),
              if (_once)
                Text(
                  'Runs the next time it\'s ${_formatTime(_time.hour, _time.minute)} after you switch '
                  'it on, then switches itself off. Flip the switch again whenever you want it.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.slate300),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in _weekdays)
                      FilterChip(
                        label: Text(w.short),
                        selected: _days.contains(w.day),
                        showCheckmark: false,
                        selectedColor: _accent.withValues(alpha: 0.3),
                        onSelected: (on) => setState(
                            () => on ? _days.add(w.day) : _days.remove(w.day)),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              for (final stream in VolumeStream.values) _streamControl(stream),
              const SizedBox(height: 8),
              Text(
                'Android only has a fixed number of volume steps per stream, so each percentage '
                'is rounded to the nearest step shown.',
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.slate400),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Save',
                icon: Icons.check_rounded,
                width: double.infinity,
                onPressed: _valid ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _streamControl(VolumeStream stream) {
    final percent = _levels[stream];
    final on = percent != null;
    final info = widget.streams[stream];
    final minPercent = stream.isRinger && info != null ? info.percentOf(1) : 0;

    String? stepText;
    if (on && info != null) {
      final step = info.stepFor(percent, isRinger: stream.isRinger);
      stepText = 'step $step/${info.max} (${info.percentOf(step)}%)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: on,
              activeColor: _accent,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _levels[stream] = 50;
                } else {
                  _levels.remove(stream);
                }
              }),
            ),
            Text(stream.label, style: AppTypography.bodyLarge),
            const Spacer(),
            if (on)
              Text('$percent%',
                  style: AppTypography.titleMedium.copyWith(color: _accent)),
          ],
        ),
        if (on) ...[
          Slider(
            value: percent.toDouble().clamp(minPercent.toDouble(), 100),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: _accent,
            onChanged: (v) => setState(
                () => _levels[stream] = v.round().clamp(minPercent, 100)),
          ),
          if (stepText != null)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Text(stepText,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.slate400)),
            ),
        ] else
          const SizedBox(height: 4),
      ],
    );
  }
}
