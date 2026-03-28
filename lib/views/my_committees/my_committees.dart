import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/committees_provider.dart';
import 'add_user_payment.dart';
import 'committee_members_screen.dart';
import 'winners_list_screen.dart';

class MyCommitteesScreen extends StatefulWidget {
  final String userId;

  const MyCommitteesScreen({super.key, required this.userId});

  @override
  State<MyCommitteesScreen> createState() => _MyCommitteesScreenState();
}

class _MyCommitteesScreenState extends State<MyCommitteesScreen> with AutomaticKeepAliveClientMixin {
  bool _isInitialLoadComplete = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Set loading to true immediately when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CommitteesProvider>();
      provider.isLoading = true;
      provider.notifyListeners();
      _fetchCommittees();
    });
  }

  void _fetchCommittees() {
    if (!mounted) return;

    final provider = context.read<CommitteesProvider>();

    // Only show loading if we have no committees and it's the first load
    if (provider.committees.isEmpty && !_isInitialLoadComplete) {
      provider.isLoading = true;
      provider.notifyListeners();
    }

    // Since fetchUserCommittees doesn't return a Future, we can't use .then()
    // Instead, we need to listen to the provider's state changes
    provider.fetchUserCommittees(widget.userId);

    // We'll set initial load complete after a short delay
    // The actual data will come through the provider's listeners
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isInitialLoadComplete = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _MyCommitteesScreenBody(
      userId: widget.userId,
      key: ValueKey('committees_${widget.userId}'),
    );
  }
}

class _MyCommitteesScreenBody extends StatelessWidget {
  final String userId;
  const _MyCommitteesScreenBody({super.key, required this.userId});

  // Pakistan Rupee symbol
  static const String _rupeeSymbol = 'Rs. ';

  String _formatDateRange(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return "";
    final s = start.toDate();
    final e = end.toDate();
    return "${s.day} ${_getMonthName(s.month)} ${s.year} - ${e.day} ${_getMonthName(e.month)} ${e.year}";
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _getCommitteeTypeIcon(String type) {
    return type.toLowerCase() == "daily" ? "📅 Daily" : "📆 Monthly";
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return Colors.green;
      case "completed":
        return Colors.orange;
      case "inactive":
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatPakistaniRupee(int amount) {
    if (amount >= 10000000) { // Crore
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) { // Lakh
      return '${(amount / 100000).toStringAsFixed(2)} Lac';
    } else {
      String numStr = amount.toString();
      String result = '';
      int len = numStr.length;

      if (len > 3) {
        result = numStr.substring(len - 3);
        numStr = numStr.substring(0, len - 3);

        while (numStr.isNotEmpty) {
          if (numStr.length >= 2) {
            result = numStr.substring(numStr.length - 2) + ',' + result;
            numStr = numStr.substring(0, numStr.length - 2);
          } else {
            result = numStr + ',' + result;
            numStr = '';
          }
        }
        return result;
      }
      return amount.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommitteesProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Committees",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              provider.isLoading = true;
              provider.notifyListeners();
              provider.fetchUserCommittees(userId);
            },
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, CommitteesProvider provider) {
    // ✅ Show loading on first load (when committees are empty and loading is true)
    if (provider.isLoading && provider.committees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              "Loading your committees...",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Show error if any (only when not loading)
    if (provider.error != null && !provider.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                "Error Loading Committees",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.error!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  provider.isLoading = true;
                  provider.notifyListeners();
                  provider.fetchUserCommittees(userId);
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Try Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Show empty state only when committees are empty AND not loading
    if (provider.committees.isEmpty && !provider.isLoading) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.group_off_rounded,
                  size: 64,
                  color: AppColors.primaryColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "No Committees Found",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "You haven't joined or created any committees yet.\nUse the quick actions on home screen to get started.",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show committees list
    return RefreshIndicator(
      onRefresh: () async {
        provider.isLoading = true;
        provider.notifyListeners();
        provider.fetchUserCommittees(userId);
        // Small delay to ensure loading state is shown
        await Future.delayed(const Duration(milliseconds: 100));
      },
      color: AppColors.primaryColor,
      backgroundColor: AppColors.surfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.committees.length,
        itemBuilder: (context, index) {
          final committee = provider.committees[index];
          return _buildCommitteeCard(context, committee, provider);
        },
      ),
    );
  }

  Widget _buildCommitteeCard(BuildContext context, Map<String, dynamic> committee, CommitteesProvider provider) {
    final startTimestamp = committee["startMonth"] as Timestamp?;
    final endTimestamp = committee["endMonth"] as Timestamp?;
    final dateRange = _formatDateRange(startTimestamp, endTimestamp);

    final status = committee["status"] ?? "Inactive";
    final isActive = status.toLowerCase() == "active";
    final committeeCode = committee["committeeCode"] ?? "N/A";
    final adminName = committee["adminName"] ?? "Unknown";
    final type = committee["type"] ?? "monthly";
    final monthlyAmount = (committee["monthlyAmount"] ?? 0).toInt();
    final totalMembers = committee["totalMembers"] ?? 0;
    final totalAmount = (committee["totalAmount"] ?? 0).toInt();
    final isAdmin = userId == (committee["adminId"] ?? "");

    // Calculate progress
    final currentMonth = committee["currentMonth"] ?? 1;
    final totalMonths = committee["totalMonths"] ?? 1;
    final progress = currentMonth / totalMonths;

    // Calculate collection percentage
    final membersPayments = Map<String, dynamic>.from(committee["membersPayments"] ?? {});
    double totalPaid = 0;
    membersPayments.forEach((_, payments) {
      if (payments is Map) {
        payments.forEach((_, value) {
          if (value is Map && value["amount"] != null) {
            totalPaid += (value["amount"] as num).toDouble();
          }
        });
      }
    });
    final collectionPercentage = totalAmount > 0 ? (totalPaid / totalAmount).toDouble() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceDark,
            AppColors.surfaceDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.primaryColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showCommitteeDetails(context, committee),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Type and Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _getCommitteeTypeIcon(type),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              committee["name"] ?? "Unnamed Committee",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Admin Info
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Created by $adminName",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Admin",
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Collection Progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Collection Progress",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${(collectionPercentage * 100).toStringAsFixed(1)}%",
                                style: const TextStyle(
                                  color: AppColors.primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: collectionPercentage,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryColor,
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Duration Progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Duration Progress",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "$currentMonth/$totalMonths months",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          label: "Members",
                          value: "$totalMembers",
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          label: type == "daily" ? "Per Day" : "Per Month",
                          value: "$_rupeeSymbol${_formatPakistaniRupee(monthlyAmount)}",
                          icon: Icons.currency_rupee,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          label: "Total",
                          value: "$_rupeeSymbol${_formatPakistaniRupee(totalAmount)}",
                          icon: Icons.account_balance_wallet,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Date Range
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dateRange.isNotEmpty ? dateRange : "Dates not set",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Committee Code Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Committee Code",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                committeeCode,
                                style: const TextStyle(
                                  fontSize: 16,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: committeeCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Code copied to clipboard",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.copy,
                                color: AppColors.primaryColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.people_outline,
                          label: "Members",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommitteeMembersScreen(
                                  committeeId: committee["id"], committeeName: committee["name"],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.emoji_events_outlined,
                          label: "Winners",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommitteeWinnerScreen(
                                  committeeId: committee["id"],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.payment_outlined,
                            label: "Add Payment",
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddUserPayment(
                                    committeeId: committee["id"],
                                    currentUserId: userId,
                                  ),
                                ),
                              );
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommitteeDetails(BuildContext context, Map<String, dynamic> committee) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              committee["name"] ?? "Committee Details",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow("Type", committee["type"] ?? "Monthly"),
            _buildDetailRow("Members", "${committee["totalMembers"] ?? 0}"),
            _buildDetailRow("Monthly Amount", "$_rupeeSymbol${_formatPakistaniRupee((committee["monthlyAmount"] ?? 0).toInt())}"),
            _buildDetailRow("Total Amount", "$_rupeeSymbol${_formatPakistaniRupee((committee["totalAmount"] ?? 0).toInt())}"),
            _buildDetailRow("Status", committee["status"] ?? "Inactive", isStatus: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(value).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: _getStatusColor(value),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}