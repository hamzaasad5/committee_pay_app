import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:committee_pay_app/views/my_committees/widgets/member_payment_history.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class CommitteeMembersScreen extends StatefulWidget {
  final String committeeId;
  const CommitteeMembersScreen({super.key, required this.committeeId});

  @override
  State<CommitteeMembersScreen> createState() => _CommitteeMembersScreenState();
}

class _CommitteeMembersScreenState extends State<CommitteeMembersScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _committee;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchCommitteeData();
  }

  Future<void> _fetchCommitteeData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("committees")
          .doc(widget.committeeId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = "Committee not found";
          _isLoading = false;
        });
        return;
      }

      final data = doc.data();
      if (data == null || data["members"] == null) {
        setState(() {
          _members = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _committee = data;
        _members = List<Map<String, dynamic>>.from(data["members"]);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!, style: TextStyle(color: Colors.red))),
      );
    }

    if (_committee == null) {
      return const Scaffold(body: Center(child: Text("No data available")));
    }

    final type = _committee!["type"] ?? "monthly";
    final adminId = _committee!["adminId"];
    final membersPayments =
    Map<String, dynamic>.from(_committee!["membersPayments"] ?? {});

    final dailyAmount = _committee!["dailyAmount"] ?? 0;
    final totalMembers = _members.length;

    // Month payment = dailyAmount × 30
    final monthlyAmount = dailyAmount * 30;

    // Full committee amount = monthly × months
    final totalExpectedFull = monthlyAmount * totalMembers;

    // Sort members - creator first
    final sortedMembers = [..._members];
    sortedMembers.sort((a, b) => a["uid"] == adminId ? -1 : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Committee Members",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sortedMembers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final member = sortedMembers[index];
          final uid = member["uid"];
          final name = member["name"];
          final isCreator = uid == adminId;

          final payments = membersPayments[uid] ?? {};
          double totalPaid = 0;

          payments.forEach((key, value) {
            if (value is Map && value["amount"] != null) {
              totalPaid += (value["amount"] as num).toDouble();
            }
          });

          final double remaining = totalExpectedFull - totalPaid;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberPaymentsScreen(
                    committeeId: widget.committeeId,
                    member: member,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThemeConstants.inputBorderDark,
                borderRadius:
                BorderRadius.circular(ThemeConstants.borderRadiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: Offset(0, 2),
                    blurRadius: 6,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (isCreator)
                        Container(
                          padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text("Creator",
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Main calculation summary
                  Text("💰 Total Expected: Rs $totalExpectedFull",
                      style: _boldStyle()),
                  Text("🟢 Total Paid: Rs $totalPaid",
                      style: _boldStyle(color: Colors.green)),
                  Text("🔴 Remaining: Rs $remaining",
                      style: _boldStyle(color: Colors.red)),
                  const SizedBox(height: 6),

                  // Monthly / Daily info
                  Text("📆 Monthly Amount: Rs $monthlyAmount",
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text("👥 Total Months: $totalMembers",
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _boldStyle({Color color = Colors.black}) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: color,
  );
}
