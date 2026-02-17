import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/committees_provider.dart';
import '../../../utils/app_local_storage.dart';

class MemberAssignmentScreen extends StatefulWidget {
  final String committeeId;
  const MemberAssignmentScreen({super.key, required this.committeeId});

  @override
  State<MemberAssignmentScreen> createState() =>
      _MemberAssignmentScreenState();
}

class _MemberAssignmentScreenState extends State<MemberAssignmentScreen> {
  Map<String, dynamic>? _committee;
  bool loading = true;

  String? selectedMonth;
  String? selectedMemberId;
  String? currentUserId;

  final Map<int, String> monthNames = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
  };

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    currentUserId = await LocalStorage.getUserId();
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

  String _monthLabel(String monthKey) {
    final number = int.tryParse(monthKey.replaceAll("Month", ""));
    return monthNames[number] ?? monthKey;
  }

  @override
  Widget build(BuildContext context) {
    if (loading || _committee == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final committee = _committee!;
    final members = List<Map<String, dynamic>>.from(committee["members"]);
    final assignments = Map<String, dynamic>.from(committee["winners"] ?? {});
    final bool isCreator = committee["adminId"] == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Assignments"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ---------------- CREATOR ONLY FORM ----------------
          if (isCreator) ...[
            const Text(
              "Select Month for Assignment",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              value: selectedMonth,
              hint: const Text("Choose Month"),
              items: monthNames.entries
                  .map((e) => DropdownMenuItem(
                value: "Month${e.key}",
                child: Text(e.value),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedMonth = value;
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Assign Member for This Month",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              value: selectedMemberId,
              hint: const Text("Choose Member"),
              items: members
                  .map<DropdownMenuItem<String>>(
                    (m) => DropdownMenuItem<String>(
                  value: (m["uid"] ?? m["phone"]).toString(),
                  child: Text(m["name"]),
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedMemberId = value;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                if (selectedMonth == null) {
                  _showMsg("Please select a month");
                  return;
                }
                if (selectedMemberId == null) {
                  _showMsg("Please select a member");
                  return;
                }

                await _saveAssignment(
                  committeeId: committee["id"],
                  monthKey: selectedMonth!,
                  memberId: selectedMemberId!,
                );

                _showMsg("Assignment saved successfully!");
                await fetchCommittee();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Save Assignment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
          ],

          // ---------------- ASSIGNED MEMBERS LIST ----------------
          const Text(
            "Monthly Assigned Members",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 10),

          ...assignments.entries.map((entry) {
            final member = members.firstWhere(
                  (m) => (m["uid"] ?? m["phone"]) == entry.value,
              orElse: () => {},
            );

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  _monthLabel(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(member["name"] ?? "Unknown"),
                leading: const Icon(Icons.person, color: Colors.blue),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _saveAssignment({
    required String committeeId,
    required String monthKey,
    required String memberId,
  }) async {
    final provider = context.read<CommitteesProvider>();
    await provider.saveWinnerManual(
      committeeId: committeeId,
      monthKey: monthKey,
      memberId: memberId,
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
