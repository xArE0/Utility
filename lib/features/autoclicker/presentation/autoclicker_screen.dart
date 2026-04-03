import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'autoclicker_controller.dart';
import '../data/android_autoclicker_repository.dart';

class AutoClickerScreen extends StatefulWidget {
  const AutoClickerScreen({super.key});

  @override
  State<AutoClickerScreen> createState() => _AutoClickerScreenState();
}

class _AutoClickerScreenState extends State<AutoClickerScreen> {
  late final AutoClickerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AutoClickerController(repository: AndroidAutoClickerRepository());
    _controller.init();
    _controller.addListener(_onControllerNotify);
  }

  void _onControllerNotify() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerNotify);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = AppColors.govGreen;

    final statusChip = Row(
      children: [
        Icon(
          _controller.accessEnabled ? Icons.verified_user : Icons.error_outline,
          color: _controller.accessEnabled ? accent : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          _controller.accessEnabled ? "Accessibility enabled" : "Accessibility not enabled",
          style: TextStyle(
            color: _controller.accessEnabled ? accent : Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _controller.openAccessibilitySettings,
          child: const Text("Open settings"),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text("AutoClicker")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: cs.surface.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("How it works", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      "1) Enable the Accessibility Service\n"
                      "2) Tap “Show floating dot”\n"
                      "3) Move the dot to where you want clicks\n"
                      "4) Tap the dot to start/stop autoclicking.\n\n"
                      "Works across apps (e.g., Chrome) because clicks are sent by the Accessibility Service.",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            statusChip,
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Target X", style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    key: ValueKey('x_${_controller.x}'),
                    initialValue: _controller.x.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? _controller.x;
                      _controller.saveCoords(val, _controller.y);
                    },
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Target Y", style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    key: ValueKey('y_${_controller.y}'),
                    initialValue: _controller.y.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? _controller.y;
                      _controller.saveCoords(_controller.x, val);
                    },
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Delay per click", style: Theme.of(context).textTheme.titleMedium),
                Text("${(_controller.delay / 1000).toStringAsFixed(1)} s", style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              value: _controller.delay.toDouble(),
              min: 200,
              max: 4000,
              divisions: 19,
              label: "${(_controller.delay / 1000).toStringAsFixed(1)}s",
              onChanged: (val) => _controller.saveDelay(val.toInt()),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "The delay is saved and read by the Accessibility Service when you tap the dot to start.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Spacer(),
            if (_controller.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _controller.error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _controller.checking ? null : () => _controller.startFloatingService(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                     child: Text(_controller.checking ? "Checking..." : "Show dot"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _controller.stopAutoclick(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Stop"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
