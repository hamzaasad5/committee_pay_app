import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:fluttertoast/fluttertoast.dart';

class WinnerSpinnerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final String committeeId;
  final int currentMonthIndex;
  final int totalMonths;

  const WinnerSpinnerScreen({
    super.key,
    required this.members,
    required this.committeeId,
    required this.currentMonthIndex,
    required this.totalMonths,
  });

  @override
  State<WinnerSpinnerScreen> createState() => _WinnerSpinnerScreenState();
}

class _WinnerSpinnerScreenState extends State<WinnerSpinnerScreen> {
  final StreamController<int> controller = StreamController<int>();
  int selectedIndex = 0;
  Map<String, dynamic>? selectedWinner;
  bool spinning = false;
  bool saved = false;

  // List of months
  final List<String> months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  /// Save winner to Firestore under committee's "winners" map
  Future<void> saveWinnerToFirestore(
      String uid, String name, String monthKey) async {
    final docRef =
    FirebaseFirestore.instance.collection("committees").doc(widget.committeeId);

    await docRef.set({
      "winners": {
        monthKey: {
          "uid": uid,
          "name": name,
        }
      }
    }, SetOptions(merge: true));
  }

  void spinWheel() async {
    if (widget.currentMonthIndex > widget.totalMonths) {
      Fluttertoast.showToast(
        msg: "All winners for this committee are already announced!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    if (widget.members.length < 2) {
      Fluttertoast.showToast(
        msg: "At least 2 members required to spin!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      spinning = true;
      saved = false;
      selectedWinner = null;
    });

    final random = Random();
    selectedIndex = random.nextInt(widget.members.length);
    controller.add(selectedIndex);

    // Simulate spinning duration
    await Future.delayed(const Duration(seconds: 5));

    final winner = widget.members[selectedIndex];
    final monthKey = months[widget.currentMonthIndex - 1]; // 1-based index

    setState(() {
      selectedWinner = winner;
      spinning = false;
    });

    // Save to Firestore
    await saveWinnerToFirestore(winner["uid"], winner["name"], monthKey);

    setState(() {
      saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    final monthName = widget.currentMonthIndex <= 12
        ? months[widget.currentMonthIndex - 1]
        : "Month ${widget.currentMonthIndex}";

    // Disable button if all months completed
    final allMonthsDone = widget.currentMonthIndex > widget.totalMonths;

    return Scaffold(
      appBar: AppBar(title: Text("Spin for $monthName")),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // Spinner
          if (members.isNotEmpty && !allMonthsDone)
            Expanded(
              child: FortuneWheel(
                selected: controller.stream,
                animateFirst: false,
                items: [
                  for (var m in members)
                    FortuneItem(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m["name"],
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            monthName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else if (allMonthsDone)
            Expanded(
              child: Center(
                child: Text(
                  "All winners for this committee are announced!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Winner Card
          if (selectedWinner != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    "🎉 Winner Selected!",
                    style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedWinner!["name"],
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "For $monthName",
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (saved)
                    const Text(
                      "✔ Winner saved successfully!",
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Spin Button
          ElevatedButton(
            onPressed: (spinning || allMonthsDone) ? null : spinWheel,
            style: ElevatedButton.styleFrom(
              backgroundColor: allMonthsDone ? Colors.grey : Colors.blue,
              padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: Text(
              allMonthsDone
                  ? "ALL WINNERS ANNOUNCED"
                  : spinning
                  ? "SPINNING..."
                  : "SPIN NOW",
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
