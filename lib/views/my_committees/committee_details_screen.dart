import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/committees_provider.dart';

class CommitteeDetailsScreen extends StatefulWidget {
  final String committeeId;
  final String currentUserId;

  const CommitteeDetailsScreen({
    super.key,
    required this.committeeId,
    required this.currentUserId,
  });

  @override
  State<CommitteeDetailsScreen> createState() => _CommitteeDetailsScreenState();
}

class _CommitteeDetailsScreenState extends State<CommitteeDetailsScreen> {
  Map<String, dynamic>? _committee;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  Future<void> loadDetails() async {
    final data = await context.read<CommitteesProvider>().fetchCommitteeById(widget.committeeId);
    setState(() => _committee = data);
  }

  Future<void> refreshAfterAction() async {
    setState(() => _refreshing = true);
    await loadDetails();
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_committee == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final committee = _committee!;
    final bool isAdmin = committee["adminId"] == widget.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          committee["name"],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(committee),
              const SizedBox(height: 20),

              const Text("Members",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),

              ..._buildMemberCards(committee, isAdmin),
            ],
          ),

          if (_refreshing)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(child: CircularProgressIndicator()),
            )
        ],
      ),
    );
  }

  // HEADER CARD
  Widget _buildHeaderCard(Map committee) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoRow("Monthly Amount", "Rs ${committee["monthlyAmount"]}"),
            const SizedBox(height: 8),
            infoRow(
              "Period",
              "${committee["startMonth"].toDate().month}/${committee["startMonth"].toDate().year}"
                  " - "
                  "${committee["endMonth"].toDate().month}/${committee["endMonth"].toDate().year}",
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            infoRow("Total Members", "${committee["members"].length}"),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMemberCards(Map committee, bool isAdmin) {
    final members = List<Map<String, dynamic>>.from(committee["members"]);

    return List.generate(members.length, (i) {
      final member = members[i];
      final phone = member["phone"];
      final uid = member["uid"] ?? phone;

      final payments = Map<String, String>.from(
        committee["membersPayments"][uid] ?? {},
      );

      int pendingMonths = payments.values.where((v) => v != "Done").length;
      int totalRemaining =
          pendingMonths * (committee["monthlyAmount"] as num).toInt();

      return Card(
        margin: const EdgeInsets.only(bottom: 14),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  member["name"][0].toUpperCase(),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member["name"],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          subtitle: Padding(
            padding: const EdgeInsets.only(left: 56, top: 6),
            child: Row(
              children: [
                Chip(
                  label: Text(
                    "Remaining: Rs $totalRemaining",
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.orange.shade100,
                ),
              ],
            ),
          ),

          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: payments.entries.map((entry) {
                  final monthKey = entry.key;
                  final status = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            _monthLabel(monthKey),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        // STATUS CHIP
                        Chip(
                          label: Text(status),
                          backgroundColor: status == "Done"
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          labelStyle: TextStyle(
                              color: status == "Done"
                                  ? Colors.green
                                  : Colors.red),
                        ),

                        const SizedBox(width: 12),

                        // ADMIN "MARK PAID" BUTTON
                        if (isAdmin && status != "Done")
                          ElevatedButton(
                            onPressed: () async {
                              await context
                                  .read<CommitteesProvider>()
                                  .updatePaymentStatus(
                                widget.committeeId,
                                uid,
                                monthKey,
                                "Done",
                              );

                              await refreshAfterAction();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                minimumSize: const Size(90, 32)),
                            child: const Text(
                              "Mark Paid",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        ),
      );
    });
  }

  Widget infoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  String _monthLabel(String key) {
    final parts = key.split("-");
    int month = int.parse(parts[1]);
    const monthNames = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return "${monthNames[month]} ${parts[0]}";
  }
}
