import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:committee_pay_app/views/my_committees/widgets/member_payment_history.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

class CommitteeMembersScreen extends StatefulWidget {
  final String committeeId;
  const CommitteeMembersScreen({super.key, required this.committeeId});

  @override
  State<CommitteeMembersScreen> createState() => _CommitteeMembersScreenState();
}

class _CommitteeMembersScreenState extends State<CommitteeMembersScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _committee;
  List<Map<String, dynamic>> _members = [];

  // Summary statistics
  int _totalMembers = 0;
  double _totalExpectedAmount = 0;
  double _totalPaidAmount = 0;
  double _totalRemainingAmount = 0;
  int _activeMembers = 0;
  String _committeeType = "monthly";
  double _monthlyAmount = 0;

  @override
  bool get wantKeepAlive => true;

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
      if (data == null) {
        setState(() {
          _error = "Invalid committee data";
          _isLoading = false;
        });
        return;
      }

      // Extract committee data
      _committee = data;
      _members = List<Map<String, dynamic>>.from(data["members"] ?? []);
      _committeeType = data["type"] ?? "monthly";

      // Calculate financial data
      final dailyAmount = (data["dailyAmount"] ?? 0).toDouble();
      final monthlyAmount = (data["monthlyAmount"] ?? 0).toDouble();
      final totalMembers = _members.length;
      final totalMonths = (data["monthsCount"] ?? 1).toInt();

      // Calculate monthly amount based on committee type
      _monthlyAmount = _committeeType == "daily" ? dailyAmount * 30 : monthlyAmount;

      // Calculate totals
      _totalMembers = totalMembers;
      _totalExpectedAmount = _monthlyAmount * totalMembers * totalMonths;

      // Calculate paid amounts
      final membersPayments = Map<String, dynamic>.from(data["membersPayments"] ?? {});
      double totalPaid = 0;
      int activeCount = 0;

      membersPayments.forEach((memberId, payments) {
        if (payments is Map) {
          double memberTotal = 0;
          payments.forEach((key, value) {
            if (value is Map && value["amount"] != null) {
              memberTotal += (value["amount"] as num).toDouble();
            }
          });
          totalPaid += memberTotal;

          // Check if member is active (has made at least one payment)
          if (memberTotal > 0) {
            activeCount++;
          }
        }
      });

      setState(() {
        _totalPaidAmount = totalPaid;
        _totalRemainingAmount = _totalExpectedAmount - totalPaid;
        _activeMembers = activeCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load committee data";
        _isLoading = false;
      });
      debugPrint('Error fetching committee data: $e');
    }
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  double _getCollectionPercentage() {
    if (_totalExpectedAmount == 0) return 0;
    return (_totalPaidAmount / _totalExpectedAmount).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchCommitteeData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_committee == null || _members.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "No Members Found",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This committee doesn't have any members yet",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final adminId = _committee!["adminId"];
    final collectionPercentage = _getCollectionPercentage();

    // Sort members - creator first, then by name
    final sortedMembers = List<Map<String, dynamic>>.from(_members);
    sortedMembers.sort((a, b) {
      if (a["uid"] == adminId) return -1;
      if (b["uid"] == adminId) return 1;
      return (a["name"] ?? "").compareTo(b["name"] ?? "");
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Committee Members",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchCommitteeData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Overview Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildOverviewCard(
                        label: "Total Members",
                        value: "$_totalMembers",
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOverviewCard(
                        label: "Active",
                        value: "$_activeMembers",
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Collection Progress
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Collection Progress",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${(collectionPercentage * 100).toStringAsFixed(1)}%",
                              style: const TextStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: collectionPercentage,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryColor,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Summary
                      Row(
                        children: [
                          Expanded(
                            child: _buildAmountColumn(
                              label: "Expected",
                              amount: _totalExpectedAmount,
                              color: Colors.orange,
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Expanded(
                            child: _buildAmountColumn(
                              label: "Collected",
                              amount: _totalPaidAmount,
                              color: Colors.green,
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Expanded(
                            child: _buildAmountColumn(
                              label: "Remaining",
                              amount: _totalRemainingAmount,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Members List Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Member List",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${sortedMembers.length} members",
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Members List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchCommitteeData,
              color: AppColors.primaryColor,
              backgroundColor: AppColors.surfaceDark,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sortedMembers.length,
                itemBuilder: (context, index) {
                  final member = sortedMembers[index];
                  final uid = member["uid"];
                  final name = member["name"] ?? "Unknown Member";
                  final phone = member["phone"] ?? "No phone";
                  final isCreator = uid == adminId;
                  final joinedAt = member["joinedAt"] != null
                      ? (member["joinedAt"] as Timestamp).toDate()
                      : null;

                  // Calculate member's payment status
                  final membersPayments = Map<String, dynamic>.from(
                      _committee!["membersPayments"] ?? {}
                  );
                  final memberPayments = membersPayments[uid] ?? {};

                  double memberPaid = 0;
                  memberPayments.forEach((key, value) {
                    if (value is Map && value["amount"] != null) {
                      memberPaid += (value["amount"] as num).toDouble();
                    }
                  });

                  final memberExpected = _monthlyAmount * (memberPayments.length + 1);
                  final memberRemaining = memberExpected - memberPaid;
                  final paymentStatus = memberPaid >= memberExpected ? "completed" : "pending";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCreator
                            ? AppColors.primaryColor.withOpacity(0.3)
                            : Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
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
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Member Header
                              Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          isCreator
                                              ? AppColors.primaryColor
                                              : Colors.blue,
                                          isCreator
                                              ? AppColors.primaryLight
                                              : Colors.lightBlue,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Member Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (isCreator)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  "Creator",
                                                  style: TextStyle(
                                                    color: AppColors.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          phone,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (joinedAt != null)
                                          Text(
                                            "Joined ${DateFormat('dd MMM yyyy').format(joinedAt)}",
                                            style: TextStyle(
                                              color: AppColors.textSecondary.withOpacity(0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Payment Status
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // Status Indicator
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: paymentStatus == "completed"
                                            ? Colors.green
                                            : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      paymentStatus == "completed"
                                          ? "Payments Completed"
                                          : "Payments Pending",
                                      style: TextStyle(
                                        color: paymentStatus == "completed"
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),

                                    // Payment Amounts
                                    Text(
                                      _formatCurrency(memberPaid),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Text(
                                      " / ",
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      _formatCurrency(memberExpected),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.history,
                                      label: "History",
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
                                    ),
                                  ),
                                  if (memberRemaining > 0) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildActionButton(
                                        icon: Icons.payment,
                                        label: "Pay",
                                        color: Colors.green,
                                        onTap: () {
                                          // Navigate to payment screen
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(amount),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.primaryColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}