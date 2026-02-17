import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/committees_provider.dart';
import '../../../utils/app_local_storage.dart';
import '../member_assigned_list_screen.dart'; // rename if needed

class MemberAssignmentHome extends StatefulWidget {
  const MemberAssignmentHome({super.key});

  @override
  State<MemberAssignmentHome> createState() => _MemberAssignmentHomeState();
}

class _MemberAssignmentHomeState extends State<MemberAssignmentHome> {
  String? _currentUserId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initUserId();
  }

  Future<void> _initUserId() async {
    final authProvider = context.read<AuthProvider>();
    String? userId = authProvider.currentUser?.uid;

    if (userId == null) {
      userId = await LocalStorage.getUserId(); // fetch from local storage
    }

    setState(() {
      _currentUserId = userId;
      _loading = false;
    });

    // Fetch user's committees
    if (userId != null) {
      context.read<CommitteesProvider>().fetchUserCommittees(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _currentUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final committees = context.watch<CommitteesProvider>().committees;

    // Show all committees where user is member OR creator
    final userCommittees = committees
        .where((c) => (c["members"] as List)
        .any((m) => m["uid"] == _currentUserId) ||
        c["adminId"] == _currentUserId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Assignments"),
      ),
      body: userCommittees.isEmpty
          ? Center(
        child: Text(
          "You are not part of any committee yet.",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: userCommittees.length,
        itemBuilder: (context, index) {
          final committee = userCommittees[index];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                committee["name"],
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                  "Members: ${committee["members"].length} | Amount: Rs ${committee["monthlyAmount"]}"),
              trailing:
              const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberAssignmentScreen(
                      committeeId: committee["id"],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
