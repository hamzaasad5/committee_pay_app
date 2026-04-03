import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:committee_pay_app/views/my_committees/widgets/member_payment_history.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_app_bar.dart';

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
  int _paidMembersCount = 0;
  String _committeeType = "monthly";
  double _perMemberAmount = 0; // Amount per member per period (day/month)

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchCommitteeData();
  }

  Future<void> _fetchCommitteeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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

      _committee = data;
      _members = List<Map<String, dynamic>>.from(data["members"] ?? []);
      _committeeType = data["type"] ?? "monthly";

      final dailyAmount = (data["dailyAmount"] ?? 0).toDouble();
      final monthlyAmount = (data["monthlyAmount"] ?? 0).toDouble();
      final totalMembers = _members.length;
      final totalMonths = (data["monthsCount"] ?? 1).toInt();

      // Calculate per member amount based on committee type
      if (_committeeType == "daily") {
        _perMemberAmount = dailyAmount * 30; // Daily committee: per month amount
      } else {
        _perMemberAmount = monthlyAmount;
      }

      _totalMembers = totalMembers;
      _totalExpectedAmount = _perMemberAmount * totalMembers * totalMonths;

      final membersPayments = Map<String, dynamic>.from(data["membersPayments"] ?? {});
      double totalPaid = 0;
      int paidMembers = 0;

      membersPayments.forEach((memberId, payments) {
        if (payments is Map) {
          double memberTotal = 0;
          payments.forEach((key, value) {
            if (value is Map && value["amount"] != null) {
              memberTotal += (value["amount"] as num).toDouble();
            }
          });
          totalPaid += memberTotal;
          // Member is considered paid if they have paid at least one period
          if (memberTotal >= _perMemberAmount) {
            paidMembers++;
          }
        }
      });

      setState(() {
        _totalPaidAmount = totalPaid;
        _totalRemainingAmount = _totalExpectedAmount - totalPaid;
        _paidMembersCount = paidMembers;
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
    return '\$${amount.toStringAsFixed(0)}';
  }

  String _getPeriodText() {
    return _committeeType == "daily" ? "day" : "month";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.goldColor),
              SizedBox(height: 16),
              Text(
                "Loading members...",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchCommitteeData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_committee == null || _members.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 48,
                  color: AppColors.goldColor,
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

    final sortedMembers = List<Map<String, dynamic>>.from(_members);
    sortedMembers.sort((a, b) {
      if (a["uid"] == adminId) return -1;
      if (b["uid"] == adminId) return 1;
      return (a["name"] ?? "").compareTo(b["name"] ?? "");
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: CustomAppBar(
        title: "Committee Members",
        showBackButton: true,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Column(
              children: [
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        label: "Members",
                        value: "$_totalMembers",
                        icon: Icons.people_outline,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: "Paid Members",
                        value: "$_paidMembersCount",
                        icon: Icons.check_circle_outline,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Balance Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppColors.r16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "This ${_getPeriodText()} Balance",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatCurrency(_perMemberAmount * _totalMembers),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Paid by $_paidMembersCount out of $_totalMembers members",
                        style: TextStyle(
                          color: _paidMembersCount == _totalMembers
                              ? AppColors.green
                              : AppColors.goldColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Summary
                      Row(
                        children: [
                          Expanded(
                            child: _buildAmountItem(
                              label: "Total amount",
                              amount: _perMemberAmount * _totalMembers,
                              color: AppColors.orange,
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: AppColors.border,
                          ),
                          Expanded(
                            child: _buildAmountItem(
                              label: "Collected",
                              amount: _totalPaidAmount,
                              color: AppColors.green,
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: AppColors.border,
                          ),
                          Expanded(
                            child: _buildAmountItem(
                              label: "Remaining",
                              amount: (_perMemberAmount * _totalMembers) - _totalPaidAmount,
                              color: AppColors.red,
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Members List",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${sortedMembers.length} members",
                    style: const TextStyle(
                      color: AppColors.goldColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Members List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchCommitteeData,
              color: AppColors.goldColor,
              backgroundColor: AppColors.surfaceDark,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sortedMembers.length,
                itemBuilder: (context, index) {
                  final member = sortedMembers[index];
                  final uid = member["uid"];
                  final name = member["name"] ?? "Unknown Member";
                  final isCreator = uid == adminId;
                  final joinedAt = member["joinedAt"] != null
                      ? (member["joinedAt"] as Timestamp).toDate()
                      : null;

                  final membersPayments = Map<String, dynamic>.from(
                      _committee!["membersPayments"] ?? {}
                  );
                  final memberPayments = membersPayments[uid] ?? {};

                  double memberPaid = 0;
                  int paidPeriodsCount = 0;
                  memberPayments.forEach((key, value) {
                    if (value is Map && value["amount"] != null) {
                      memberPaid += (value["amount"] as num).toDouble();
                      paidPeriodsCount++;
                    }
                  });

                  final totalPeriods = (_committee!["monthsCount"] ?? 1).toInt();
                  final remainingPeriods = totalPeriods - paidPeriodsCount;
                  final paymentStatus = memberPaid >= (_perMemberAmount * totalPeriods) ? "completed" : "pending";
                  final memberExpected = _perMemberAmount * totalPeriods;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(AppColors.r16),
                      border: Border.all(
                        color: isCreator
                            ? AppColors.goldColor.withOpacity(0.3)
                            : AppColors.border,
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
                        borderRadius: BorderRadius.circular(AppColors.r16),
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
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isCreator
                                            ? [AppColors.goldColor, AppColors.goldColor.withOpacity(0.7)]
                                            : [AppColors.blue, AppColors.blue.withOpacity(0.7)],
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
                                  const SizedBox(width: 12),

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
                                                  fontSize: 15,
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
                                                  color: AppColors.goldSoft,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  "Creator",
                                                  style: TextStyle(
                                                    color: AppColors.goldColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (joinedAt != null)
                                          Text(
                                            "Joined ${DateFormat('dd MMM yyyy').format(joinedAt)}",
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Payment Status - Shows periods paid
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(AppColors.r12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: paymentStatus == "completed"
                                            ? AppColors.green
                                            : paidPeriodsCount > 0 ? AppColors.goldColor : AppColors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        paidPeriodsCount > 0
                                            ? "Paid $paidPeriodsCount ${_getPeriodText()}${paidPeriodsCount > 1 ? 's' : ''} • ${remainingPeriods > 0 ? '$remainingPeriods remaining' : 'All paid'}"
                                            : "No payments yet",
                                        style: TextStyle(
                                          color: paymentStatus == "completed"
                                              ? AppColors.green
                                              : paidPeriodsCount > 0 ? AppColors.goldColor : AppColors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(memberPaid),
                                      style: const TextStyle(
                                        color: AppColors.green,
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

                              // Action Buttons - Only History button
                              _buildActionButton(
                                icon: Icons.history,
                                label: "View Payment History",
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
                                color: AppColors.blue,
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

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppColors.r12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountItem({
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
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(amount),
          style: TextStyle(
            color: color,
            fontSize: 13,
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
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.r10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppColors.r10),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}