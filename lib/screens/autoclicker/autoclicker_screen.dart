import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class AutoClickerScreen extends StatefulWidget {
  const AutoClickerScreen({super.key});

  @override
  State<AutoClickerScreen> createState() => _AutoClickerScreenState();
}

class _AutoClickerScreenState extends State<AutoClickerScreen> {
  static const platform = MethodChannel("floating_dot");

  Timer? _timer;
  int _delay = 2000;
  int _clickCount = 0;
  bool _running = false;

  Future<void> _requestOverlayPermission() async {
    final isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      final granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) {
        debugPrint("Overlay permission denied");
        return;
      }
    }
  }

  Future<void> _startFloatingService() async {
    try {
      await _requestOverlayPermission();

      final result = await platform.invokeMethod("startService");
      debugPrint("Service started result: $result");
    } on PlatformException catch (e) {
      debugPrint("Failed to start service: ${e.message}");
    }
  }

  void _startAutoClicking() {
    _running = true;
    _timer = Timer.periodic(Duration(milliseconds: _delay), (timer) {
      setState(() {
        _clickCount++;
      });
    });
  }

  void _stopAutoClicking() {
    _timer?.cancel();
    setState(() {
      _running = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AutoClicker")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("AutoClicker for manga reading"),
            const SizedBox(height: 20),
            Text("Delay: ${_delay / 1000} seconds"),
            Slider(
              value: _delay.toDouble(),
              min: 500,
              max: 5000,
              divisions: 9,
              label: "${(_delay / 1000).toStringAsFixed(1)}s",
              onChanged: _running ? null : (val) {
                setState(() {
                  _delay = val.toInt();
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _running ? _stopAutoClicking : _startAutoClicking,
              child: Text(_running ? "Stop" : "Start"),
            ),
            const SizedBox(height: 20),
            Text("Clicks: $_clickCount"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startFloatingService,
              child: const Text("Start Floating Dot"),
            ),
          ],
        ),
      ),
    );
  }
}
