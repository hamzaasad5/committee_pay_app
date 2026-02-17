import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/committees_provider.dart';
import 'add_committee_screen.dart';
import 'add_user_payment.dart';
import 'committee_members_screen.dart';
import 'winners_list_screen.dart';

class MyCommitteesScreen extends StatefulWidget {
  final String userId;

  const MyCommitteesScreen({super.key, required this.userId});

  @override
  State<MyCommitteesScreen> createState() => _MyCommitteesScreenState();
}

class _MyCommitteesScreenState extends State<MyCommitteesScreen> {
  @override
  void initState() {
    super.initState();
    print("commitees fetching");
    print("useridd: ${widget.userId}");
    Future.microtask(() {
      context.read<CommitteesProvider>().fetchUserCommittees(widget.userId);
    });
    print("commettees fetched");
  }

  @override
  Widget build(BuildContext context) {
    return _MyCommitteesScreenBody(userId: widget.userId);
  }
}

class _MyCommitteesScreenBody extends StatelessWidget {
  final String userId;
  const _MyCommitteesScreenBody({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommitteesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Committees",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: ThemeConstants.primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCommitteeScreen(adminId: userId),
                ),
              );
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Text(
                "Error: ${provider.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (provider.committees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off_rounded,
                    size: 80,
                    color: ThemeConstants.primaryColor.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No Committees Found",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text("Create or join a committee to get started"),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.committees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final committee = provider.committees[index];

              // Dates
              final start = committee["startMonth"] as Timestamp?;
              final end = committee["endMonth"] as Timestamp?;
              String dateRange = "";
              if (start != null && end != null) {
                final s = start.toDate();
                final e = end.toDate();
                dateRange =
                "${s.day}/${s.month}/${s.year} → ${e.day}/${e.month}/${e.year}";
              }

              final status = committee["status"] ?? "Inactive";
              final isActive = status == "Active";

              final committeeCode = committee["committeeCode"] ?? "N/A";
              final adminName = committee["adminName"] ?? "Unknown";
              final type = committee["type"] ?? "monthly";

              return Container(
                decoration: BoxDecoration(
                  color: ThemeConstants.inputBorderDark,
                  borderRadius:
                  BorderRadius.circular(ThemeConstants.borderRadiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NAME + STATUS + Popup Menu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            committee["name"],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            // Status Chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? ThemeConstants.primaryColor
                                    .withOpacity(0.15)
                                    : Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isActive
                                      ? ThemeConstants.primaryColor
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Popup Menu
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == "members") {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommitteeMembersScreen(
                                        committeeId: committee["id"],
                                      ),
                                    ),
                                  );
                                }
                                if (value == "winner") {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommitteeWinnerScreen(
                                        committeeId: committee["id"],
                                      ),
                                    ),
                                  );
                                }
                                if (value == "add_payment") {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddUserPayment(
                                        committeeId: committee["id"],
                                        currentUserId: userId,
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) {
                                // Always show Members & Winner
                                final items = <PopupMenuEntry<String>>[
                                  const PopupMenuItem(
                                    value: "members",
                                    child: Text("See Members"),
                                  ),
                                  const PopupMenuItem(
                                    value: "winner",
                                    child: Text("See Winner"),
                                  ),
                                ];

                                // Show Add Payment only for creator/admin
                                if (userId == (committee["adminId"] ?? "")) {
                                  items.add(
                                    const PopupMenuItem(
                                      value: "add_payment",
                                      child: Text("Add payment for user"),
                                    ),
                                  );
                                }

                                return items;
                              },
                            ),

                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // CREATED BY
                    Text(
                      "Created by: $adminName",
                      style: ThemeConstants.bodyMedium,
                    ),
                    const SizedBox(height: 6),

                    // MEMBERS + PER MONTH
                    Text(
                      "${committee["totalMembers"]} Members • "
                          "${type == "monthly" ? "Rs ${committee["monthlyAmount"]}/month" : "Rs ${committee["monthlyAmount"]}/day"}",
                      style: ThemeConstants.bodyMedium,
                    ),
                    const SizedBox(height: 6),

                    // DATES
                    if (dateRange.isNotEmpty)
                      Text(
                        "Duration: $dateRange",
                        style: ThemeConstants.bodyMedium,
                      ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // CODE + COPY BUTTON
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Committee Code:",
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      committeeCode,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: committeeCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Code copied!")),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
