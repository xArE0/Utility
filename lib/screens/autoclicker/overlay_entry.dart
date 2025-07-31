import 'package:flutter/material.dart';

void overlayMain() {
  runApp(const OverlayDot());
}

class OverlayDot extends StatelessWidget {
  const OverlayDot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {
            debugPrint("Overlay dot tapped");
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.touch_app, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
