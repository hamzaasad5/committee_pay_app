import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

class WinnerSpinnerScreen extends StatefulWidget {
  final List<String> members; // list of names

  const WinnerSpinnerScreen({super.key, required this.members});

  @override
  State<WinnerSpinnerScreen> createState() => _WinnerSpinnerScreenState();
}

class _WinnerSpinnerScreenState extends State<WinnerSpinnerScreen> {
  StreamController<int> controller = StreamController<int>();
  int selectedIndex = 0;
  String? winner;

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  void spinWheel() {
    final int count = min(widget.members.length, 20);
    if (count < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("At least 2 members are required to spin the wheel!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final random = Random();
    selectedIndex = random.nextInt(count);
    winner = widget.members[selectedIndex];
    controller.add(selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final int memberCount = widget.members.length;
    final int displayCount = min(memberCount, 20);

    return Scaffold(
      appBar: AppBar(title: const Text("Spin the Wheel")),
      body: Column(
        children: [
          const SizedBox(height: 20),

          if (memberCount == 0)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                "No members available to spin.",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),

          if (memberCount > 20)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                "⚠ Only first 20 members will be used!",
                style: TextStyle(color: Colors.red.shade700, fontSize: 16),
              ),
            ),

          if (displayCount >= 2)
            Expanded(
              child: FortuneWheel(
                selected: controller.stream,
                animateFirst: false,
                items: [
                  for (var name in widget.members.take(displayCount))
                    FortuneItem(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          if (winner != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                "🎉 Winner: $winner",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ),

          ElevatedButton(
            onPressed: spinWheel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: const Text("SPIN NOW", style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
