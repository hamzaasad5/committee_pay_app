import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Tab filter
  String _selectedFilter = "Today";

  @override
  void initState() {
    super.initState();

    // _controller = AnimationController(
    //   vsync: this,
    //   duration: const Duration(seconds: 5),
    // )..repeat(); // infinite spinning
    //
    // _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Filter query based on selected filter
  Query getActivityQuery() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_selectedFilter) {
      case "Today":
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case "Yesterday":
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        end = start.add(const Duration(days: 1));
        break;
      default: // "All"
        start = DateTime(2000);
        end = now.add(const Duration(days: 1));
    }

    return FirebaseFirestore.instance
        .collection("activity")
        .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where("timestamp", isLessThan: Timestamp.fromDate(end))
        .orderBy("timestamp", descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConstants.backgroundDark,
      appBar: AppBar(
        title: const Text("RupeeShare"),
        backgroundColor: ThemeConstants.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Animated spinning Rupee icon
          // SizedBox(
          //   height: 200,
          //   child: Center(
          //     child: AnimatedBuilder(
          //       animation: _animation,
          //       builder: (context, child) {
          //         return Transform.rotate(
          //           angle: _animation.value,
          //           child: child,
          //         );
          //       },
          //       child: Icon(
          //         Icons.currency_rupee,
          //         size: 100,
          //         color: ThemeConstants.primaryColor,
          //       ),
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 24),

          // Quick Action Cards
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            children: [
              _QuickActionCard(
                title: "My Committees",
                icon: Icons.group,
                color: ThemeConstants.primaryColor,
                onTap: () => Navigator.pushNamed(context, "/committees"),
              ),
              _QuickActionCard(
                title: "Payments",
                icon: Icons.payment,
                color: Colors.green,
                onTap: () => Navigator.pushNamed(context, "/payments"),
              ),
              _QuickActionCard(
                title: "Settings",
                icon: Icons.settings,
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, "/settings"),
              ),
              _QuickActionCard(
                title: "Announcements",
                icon: Icons.announcement,
                color: Colors.blueGrey,
                onTap: () => Navigator.pushNamed(context, "/announcements"),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Inspirational Text / Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeConstants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "💡 Keep track of your committees and payments seamlessly with RupeeShare!",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ThemeConstants.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Activity Filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ["Today", "Yesterday", "All"].map((filter) {
              final isSelected = _selectedFilter == filter;
              return ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                selectedColor: ThemeConstants.primaryColor,
                backgroundColor: ThemeConstants.primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : ThemeConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Firestore Activity List
          StreamBuilder<QuerySnapshot>(
            stream: getActivityQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: ThemeConstants.primaryColor,
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No activity found.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final activity = docs[index].data() as Map<String, dynamic>;
                  final type = activity["type"] ?? "Activity";
                  final details = activity["details"] ?? "";
                  final timestamp = (activity["timestamp"] as Timestamp?)?.toDate() ?? DateTime.now();

                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: ListTile(
                      leading: Icon(
                        type == "payment" ? Icons.payment : Icons.add,
                        color: type == "payment"
                            ? Colors.green
                            : ThemeConstants.primaryColor,
                      ),
                      title: Text(details),
                      subtitle: Text(
                        "${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// Quick Action Card Widget
class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: color.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
