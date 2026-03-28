import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/committees_provider.dart';
import '../../../utils/app_local_storage.dart';
import '../committee_chat_screen.dart';
import '../member_assigned_list_screen.dart';

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
      userId = await LocalStorage.getUserId();
    }

    setState(() {
      _currentUserId = userId;
      _loading = false;
    });

    // Fetch committees after the widget is built
    if (userId != null) {
      // Use addPostFrameCallback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CommitteesProvider>().fetchUserCommittees(userId!);
      });
    }
  }

  // Future<void> _refreshCommittees() async {
  //   if (_currentUserId != null) {
  //     await context
  //         .read<CommitteesProvider>()
  //         .fetchUserCommittees(_currentUserId!);
  //   }
  // }

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
      backgroundColor: Theme.of(context).primaryColorDark,
      appBar: AppBar(
        title: const Text(
          "Committees",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // TODO: Implement notifications
              },
            ),
          ),
        ],
      ),
      body: userCommittees.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: userCommittees.length,
            itemBuilder: (context, index) {
              final committee = userCommittees[index];
              final isCreator = committee["adminId"] == _currentUserId;
              final membersCount = (committee["members"] as List).length;
              final monthlyAmount = committee["monthlyAmount"] ?? 0;
              final assignments = Map<String, dynamic>.from(
                  committee["winners"] ?? {});
              final assignedCount = assignments.length;

              return _buildCommitteeCard(
                context: context,
                committee: committee,
                isCreator: isCreator,
                membersCount: membersCount,
                monthlyAmount: monthlyAmount,
                assignedCount: assignedCount,
                totalMonths: membersCount,
              );
            },
          ),
    );
  }

  Widget _buildCommitteeCard({
    required BuildContext context,
    required Map<String, dynamic> committee,
    required bool isCreator,
    required int membersCount,
    required int monthlyAmount,
    required int assignedCount,
    required int totalMonths,
  }) {
    final committeeId = committee["id"];
    final committeeName = committee["name"] ?? "Committee";
    final completionPercentage = totalMonths > 0
        ? (assignedCount / totalMonths) * 100
        : 0;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        color: theme.cardColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberAssignmentScreen(
                  committeeId: committeeId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row with Title and Chat Button
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // Creator Badge
                          if (isCreator)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 12,
                                    color: theme.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Creator",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              committeeName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : const Color(0xFF2C3E50),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chat Button
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          color: theme.primaryColor,
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommitteeChatScreen(
                                committeeId: committeeId,
                                committeeName: committeeName,
                              ),
                            ),
                          );
                        },
                        tooltip: "Open Chat",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Stats Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatChip(
                      icon: Icons.people_outline,
                      label: "$membersCount Members",
                      color: Colors.blue,
                      isDarkTheme: isDarkMode,
                    ),
                    _buildStatChip(
                      icon: Icons.currency_rupee,
                      label: "Rs $monthlyAmount",
                      color: Colors.green,
                      isDarkTheme: isDarkMode,
                    ),
                    _buildStatChip(
                      icon: Icons.assignment_turned_in,
                      label: "$assignedCount/$totalMonths Assigned",
                      color: Colors.orange,
                      isDarkTheme: isDarkMode,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress Indicator
                if (totalMonths > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Completion Progress",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "${completionPercentage.toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completionPercentage / 100,
                          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.primaryColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Divider
                Divider(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  height: 1,
                ),

                const SizedBox(height: 8),

                // Footer with Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.assignment_turned_in,
                        label: "Assignments",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberAssignmentScreen(
                                committeeId: committeeId,
                              ),
                            ),
                          );
                        },
                        color: theme.primaryColor,
                        isDarkTheme: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: "Chat",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommitteeChatScreen(
                                committeeId: committeeId,
                                committeeName: committeeName,
                              ),
                            ),
                          );
                        },
                        color: Colors.blue,
                        isDarkTheme: isDarkMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? color.withOpacity(0.2)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required bool isDarkTheme,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDarkTheme
              ? color.withOpacity(0.2)
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_off,
              size: 64,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No Committees Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You are not part of any committee.\nJoin or create a committee to get started.",
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}