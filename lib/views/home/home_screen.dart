import 'package:firebase_auth/firebase_auth.dart';
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
  final TextEditingController _joinCodeController = TextEditingController();
  bool _isJoining = false;

  // Tab filter
  String _selectedFilter = "Today";

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  // Firebase Activity Query
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
        start =
            DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        end = start.add(const Duration(days: 1));
        break;
      default:
        start = DateTime(2000);
        end = now.add(const Duration(days: 1));
    }

    return FirebaseFirestore.instance
        .collection("activity")
        .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where("timestamp", isLessThan: Timestamp.fromDate(end))
        .orderBy("timestamp", descending: true);
  }

  // Fetch actual user phone number from Firestore
  Future<String?> getUserPhone(String userId) async {
    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['phone'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching user phone: $e");
    }
    return null;
  }

  // 🔥 JOIN COMMITTEE FUNCTION
  Future<void> joinCommittee({
    required String userId,
    required String userName,
    required String userPhone,
  }) async {
    final code = _joinCodeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a committee code")),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      // Find committee by code
      final query = await FirebaseFirestore.instance
          .collection("committees")
          .where("committeeCode", isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid committee code")),
        );
        setState(() => _isJoining = false);
        return;
      }

      final doc = query.docs.first;
      final committeeId = doc.id;

      // Get current committee data
      final committeeData = doc.data();

      // Update membersMap with user UID
      Map<String, dynamic> membersMap =
      Map<String, dynamic>.from(committeeData["membersMap"] ?? {});
      membersMap[userId] = true;

      // Update members list
      List members = List.from(committeeData["members"] ?? []);
      bool alreadyMember =
      members.any((m) => m["uid"] == userId || m["phone"] == userPhone);

      if (!alreadyMember) {
        members.add({
          "name": userName,
          "phone": userPhone,
          "uid": userId,
          "status": "Joined",
          "payments": {},
        });
      }

      // Initialize payments if not exists
      Map<String, dynamic> membersPayments =
      Map<String, dynamic>.from(committeeData["membersPayments"] ?? {});
      if (!membersPayments.containsKey(userId)) {
        DateTime startMonth = (committeeData["startMonth"] as Timestamp).toDate();
        DateTime endMonth = (committeeData["endMonth"] as Timestamp).toDate();

        Map<String, String> payments = {};
        DateTime temp = DateTime(startMonth.year, startMonth.month);
        while (!temp.isAfter(endMonth)) {
          String key = "${temp.year}-${temp.month.toString().padLeft(2, '0')}";
          payments[key] = "Pending";
          temp = DateTime(temp.year, temp.month + 1);
        }
        membersPayments[userId] = payments;
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection("committees")
          .doc(committeeId)
          .update({
        "membersMap": membersMap,
        "members": members,
        "membersPayments": membersPayments,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully joined committee: ${committeeData["name"]}"),
        ),
      );

      _joinCodeController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isJoining = false);
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
          const SizedBox(height: 10),

          // 🔥 JOIN COMMITTEE SECTION
          Text(
            "Enter your code to join your committee",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: TextField(
              controller: _joinCodeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Enter committee code",
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: _isJoining
                ? null
                : () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No logged-in user found.")),
                );
                return;
              }

              final userId = user.uid;
              final userName = user.displayName ?? "No Name";

              // Fetch actual phone from Firestore
              final userPhone = await getUserPhone(userId);
              if (userPhone == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User phone not found.")),
                );
                return;
              }

              await joinCommittee(
                userId: userId,
                userName: userName,
                userPhone: userPhone,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConstants.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isJoining
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
              "Join Committee",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 24),

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

          const SizedBox(height: 30),

          // Activity Title
          Text(
            "Recent Activity",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Filters
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
                backgroundColor: Colors.white10,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Activity Stream
          StreamBuilder<QuerySnapshot>(
            stream: getActivityQuery().snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No activity found.",
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final activity = docs[index].data() as Map<String, dynamic>;
                  final timestamp = (activity["timestamp"] as Timestamp).toDate();

                  return Card(
                    color: Colors.white10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: Icon(
                        activity["type"] == "payment"
                            ? Icons.payment
                            : Icons.add_circle,
                        color: ThemeConstants.primaryColor,
                      ),
                      title: Text(
                        activity["details"] ?? "",
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "${timestamp.day}/${timestamp.month}/${timestamp.year}",
                        style: const TextStyle(color: Colors.white70),
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
        color: color.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }
}
