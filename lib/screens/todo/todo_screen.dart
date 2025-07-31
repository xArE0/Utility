import 'package:flutter/material.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("To-Do List")),
      body: const Center(child: Text("To-Do screen goes here")),
    );
  }
}
