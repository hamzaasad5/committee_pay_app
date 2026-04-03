import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
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
  bool _isLoading = true; // Controls initial loading state
  bool _isFetchingCommittees = true; // Controls committees fetching state

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
      _isLoading = false;
      _isFetchingCommittees = true;
    });

    if (userId != null) {
      // Fetch committees and wait for completion
      final committeesProvider = context.read<CommitteesProvider>();
      await committeesProvider.fetchUserCommittees(userId);

      // After fetching, update state to stop showing loader
      if (mounted) {
        setState(() {
          _isFetchingCommittees = false;
        });
      }
    } else {
      // If no user ID, stop fetching state
      if (mounted) {
        setState(() {
          _isFetchingCommittees = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show initial loader while getting user ID
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.goldColor),
        ),
      );
    }

    // Show loader while fetching committees
    if (_isFetchingCommittees) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text(
            "Assign Members",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.goldColor),
              SizedBox(height: 16),
              Text(
                "Loading committees...",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // If no user ID, show error state
    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text(
            "Assign Members",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.red,
              ),
              const SizedBox(height: 16),
              Text(
                "User not found",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please login again",
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                ),
                child: const Text("Login"),
              ),
            ],
          ),
        ),
      );
    }

    final committees = context.watch<CommitteesProvider>().committees;

    final userCommittees = committees
        .where((c) => (c["members"] as List)
        .any((m) => m["uid"] == _currentUserId) ||
        c["adminId"] == _currentUserId)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          "Assign Members",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
          onPressed: () => Navigator.pop(context),
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Committee Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.goldColor,
                        AppColors.goldColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  child: Center(
                    child: Text(
                      committeeName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        committeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (isCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: AppColors.goldColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Creator",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.goldColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.people_outline,
                    value: "$membersCount",
                    label: "Members",
                    color: AppColors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.attach_money,
                    value: "\$${_formatAmount(monthlyAmount)}",
                    label: "Amount",
                    color: AppColors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.assignment_turned_in,
                    value: "$assignedCount/$totalMonths",
                    label: "Assigned",
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Divider
            Divider(
              color: AppColors.border,
              height: 1,
            ),

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.assignment_turned_in,
                    label: "View Assignments",
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
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.person_add_alt_1,
                    label: "Assign Member",
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
                    color: AppColors.goldColor,
                    isGold: true,
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
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isGold = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppColors.r12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isGold ? AppColors.goldSoft : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppColors.r12),
          border: isGold ? Border.all(color: AppColors.goldColor.withOpacity(0.3)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Universal amount formatter with $ sign
  String _formatAmount(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_off,
              size: 64,
              color: AppColors.goldColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No Committees Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You are not part of any committee.\nJoin or create a committee to get started.",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r12),
              ),
            ),
            child: const Text(
              "Browse Committees",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}