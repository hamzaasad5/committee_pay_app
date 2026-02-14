import 'package:committee_pay_app/views/winner_announcement/widgets/winner_spinner_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/committees_provider.dart';

class WinnerAnnouncementScreen extends StatefulWidget {
  final String committeeId;
  const WinnerAnnouncementScreen({super.key, required this.committeeId});

  @override
  State<WinnerAnnouncementScreen> createState() =>
      _WinnerAnnouncementScreenState();
}

class _WinnerAnnouncementScreenState extends State<WinnerAnnouncementScreen> {
  Map<String, dynamic>? _committee;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchCommittee();
  }

  Future<void> fetchCommittee() async {
    final provider = context.read<CommitteesProvider>();
    final data = await provider.fetchCommitteeById(widget.committeeId);
    setState(() {
      _committee = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading || _committee == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final committee = _committee!;
    final members = List<Map<String, dynamic>>.from(committee["members"] ?? []);
    final membersPayments =
    Map<String, Map<String, String>>.from(committee["membersPayments"] ?? {});
    final winners = Map<String, dynamic>.from(committee["winners"] ?? {});

    // Get list of member names for spinner
    final memberNames = members.map((m) => m["name"].toString()).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Winner Announcement - ${committee["name"]}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to spinner screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WinnerSpinnerScreen(
                    members: memberNames,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.casino),
            label: const Text("Spin to Choose Winner"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Members & Status",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Members list
          ...members.map((member) {
            final uid = member["uid"] ?? member["phone"];
            final payments = Map<String, String>.from(membersPayments[uid] ?? {});

            int pendingMonths =
                payments.values.where((v) => v != "Done").length;
            int totalRemaining = pendingMonths * (committee["monthlyAmount"] as num).toInt();

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member["name"],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(member["phone"],
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text("Remaining: Rs $totalRemaining"),
                      backgroundColor: Colors.orange.shade100,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: payments.entries.map((p) {
                        final monthKey = p.key;
                        final status = p.value;
                        final winnerName = winners[monthKey] != null
                            ? members
                            .firstWhere(
                                (m) =>
                            (m["uid"] ?? m["phone"]) ==
                                winners[monthKey],
                            orElse: () => {})
                            .putIfAbsent("name", () => "")
                            : null;
                        return Chip(
                          label: Text(
                            status == "Done" && winnerName != null
                                ? "$monthKey - Winner: $winnerName"
                                : "$monthKey - $status",
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: status == "Done"
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          labelStyle: TextStyle(
                              color: status == "Done"
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600),
                        );
                      }).toList(),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
