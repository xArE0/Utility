import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

class AutoClickerScreen extends StatefulWidget {
  const AutoClickerScreen({super.key});

  @override
  State<AutoClickerScreen> createState() => _AutoClickerScreenState();
}

class _AutoClickerScreenState extends State<AutoClickerScreen> {
  static const platform = MethodChannel("floating_dot");

  int _delay = 1200;
  int _x = 500;
  int _y = 800;
  bool _accessEnabled = false;
  bool _checking = true;
  String? _error;

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _delay = prefs.getInt('autoclick_delay') ?? 1200;
      _x = prefs.getInt('autoclick_x') ?? _x;
      _y = prefs.getInt('autoclick_y') ?? _y;
    });
  }

  Future<void> _saveDelay(int value) async {
    setState(() => _delay = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoclick_delay', value);
  }

  Future<void> _saveCoords(int x, int y) async {
    setState(() {
      _x = x;
      _y = y;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoclick_x', x);
    await prefs.setInt('autoclick_y', y);
  }

  Future<void> _checkAccessibility() async {
    try {
      final enabled = await platform.invokeMethod<bool>("isAccessibilityEnabled") ?? false;
      setState(() => _accessEnabled = enabled);
    } catch (e) {
      debugPrint("Accessibility check failed: $e");
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod("openAccessibilitySettings");
    } catch (e) {
      setState(() => _error = "Couldn't open accessibility settings: $e");
    }
  }

  Future<void> _startFloatingService() async {
    setState(() => _error = null);
    await _checkAccessibility();
    if (!_accessEnabled) {
      setState(() => _error = "Enable the Accessibility Service first.");
      return;
    }
    try {
      await platform.invokeMethod("startAutoclick", {
        "x": _x,
        "y": _y,
        "delay": _delay,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Autoclicking started at ($_x, $_y) every ${_delay}ms.")),
        );
      }
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.wait([
      _loadPrefs(),
      _checkAccessibility(),
    ]).whenComplete(() {
      if (mounted) setState(() => _checking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = AppColors.govGreen;

    final statusChip = Row(
      children: [
        Icon(
          _accessEnabled ? Icons.verified_user : Icons.error_outline,
          color: _accessEnabled ? accent : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          _accessEnabled ? "Accessibility enabled" : "Accessibility not enabled",
          style: TextStyle(
            color: _accessEnabled ? accent : Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _openAccessibilitySettings,
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
                    initialValue: _x.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? _x;
                      _saveCoords(val, _y);
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
                    initialValue: _y.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? _y;
                      _saveCoords(_x, val);
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
                Text("${(_delay / 1000).toStringAsFixed(1)} s", style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              value: _delay.toDouble(),
              min: 200,
              max: 4000,
              divisions: 19,
              label: "${(_delay / 1000).toStringAsFixed(1)}s",
              onChanged: (val) => _saveDelay(val.toInt()),
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checking ? null : _startFloatingService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_checking ? "Checking..." : "Start"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await platform.invokeMethod("stopAutoclick");
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Autoclick stopped.")),
                          );
                        }
                      } catch (_) {}
                    },
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
