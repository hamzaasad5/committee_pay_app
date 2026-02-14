import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/committees_provider.dart';
import 'add_committee_screen.dart';
import 'committee_details_screen.dart';

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

    // Fetch user committees once
    Future.microtask(() {
      context.read<CommitteesProvider>().fetchUserCommittees(widget.userId);
    });
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
        title: Text(
          "My Committees",
          style: TextStyle(
            color: ThemeConstants.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: ThemeConstants.primaryColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddCommitteeScreen(adminId: userId)),
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
                child: Text("Error: ${provider.error}",
                    style: const TextStyle(color: Colors.red)));
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
                  const Text(
                    "Create or join a committee to get started",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.committees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final committee = provider.committees[index];

              // Dates
              final startMonth = committee["startMonth"] as Timestamp?;
              final endMonth = committee["endMonth"] as Timestamp?;

              String dateRange = "";
              if (startMonth != null && endMonth != null) {
                dateRange =
                "${startMonth.toDate().month}/${startMonth.toDate().year} - ${endMonth.toDate().month}/${endMonth.toDate().year}";
              }

              final status = committee["status"] ?? "Inactive";
              final isActive = status == "Active";

              return InkWell(
                onTap: () {
                  final committeeId = committee["id"]; // doc id
                  if (committeeId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommitteeDetailsScreen(
                          committeeId: committeeId,
                          currentUserId: userId,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Committee ID not found")),
                    );
                  }
                },
                borderRadius:
                BorderRadius.circular(ThemeConstants.borderRadiusMedium),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeConstants.cardLight,
                    borderRadius:
                    BorderRadius.circular(ThemeConstants.borderRadiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: name and status chip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              committee["name"],
                              style: ThemeConstants.titleLarge,
                            ),
                          ),
                          Chip(
                            label: Text(status),
                            backgroundColor: isActive
                                ? ThemeConstants.primaryColor.withOpacity(0.15)
                                : ThemeConstants.accentColor.withOpacity(0.15),
                            labelStyle: TextStyle(
                              color: isActive
                                  ? ThemeConstants.primaryColor
                                  : ThemeConstants.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${committee["members"].length} Members • Rs ${committee["monthlyAmount"]}/month",
                        style: ThemeConstants.bodyMedium,
                      ),
                      if (dateRange.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(dateRange, style: ThemeConstants.bodyMedium),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
