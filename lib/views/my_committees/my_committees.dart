import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/committees_provider.dart';
import '../../widgets/custom_app_bar.dart';
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
    if (provider.committees.isEmpty && !_isInitialLoadComplete) {
      provider.isLoading = true;
      provider.notifyListeners();
    }
    provider.fetchUserCommittees(widget.userId);
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

  static const String _currencySymbol = '\$';

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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return AppColors.green;
      case "completed":
        return AppColors.orange;
      case "inactive":
        return AppColors.red;
      default:
        return AppColors.textSecondary;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommitteesProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: CustomAppBar(
        title: "My Committees",
        showBackButton: false,
      ),
      body: _buildBody(context, provider, screenWidth),
    );
  }

  Widget _buildBody(BuildContext context, CommitteesProvider provider, double screenWidth) {
    if (provider.isLoading && provider.committees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.goldColor),
            SizedBox(height: 16),
            Text(
              "Loading your committees...",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

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
                  color: AppColors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, size: 48, color: AppColors.red),
              ),
              const SizedBox(height: 16),
              Text(
                "Error Loading Committees",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                  backgroundColor: AppColors.goldColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                  color: AppColors.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_off_rounded,
                  size: 64,
                  color: AppColors.goldColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "No Committees Found",
                style: TextStyle(
                  fontSize: screenWidth < 400 ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You haven't joined or created any committees yet.\nCreate a committee or join using a committee code.",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: screenWidth < 400 ? 12 : 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        provider.isLoading = true;
        provider.notifyListeners();
        provider.fetchUserCommittees(userId);
        await Future.delayed(const Duration(milliseconds: 100));
      },
      color: AppColors.goldColor,
      backgroundColor: AppColors.surfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.committees.length,
        itemBuilder: (context, index) {
          final committee = provider.committees[index];
          return _buildCommitteeCard(context, committee, provider, screenWidth);
        },
      ),
    );
  }

  Widget _buildCommitteeCard(BuildContext context, Map<String, dynamic> committee, CommitteesProvider provider, double screenWidth) {
    final status = committee["status"] ?? "Inactive";
    final isActive = status.toLowerCase() == "active";
    final committeeCode = committee["committeeCode"] ?? "N/A";
    final adminName = committee["adminName"] ?? "Unknown";
    final type = committee["type"] ?? "monthly";
    final monthlyAmount = (committee["monthlyAmount"] ?? 0).toInt();
    final totalMembers = committee["totalMembers"] ?? 0;
    final totalAmount = (committee["totalAmount"] ?? 0).toInt();
    final isAdmin = userId == (committee["adminId"] ?? "");

    // Responsive values
    final cardPadding = screenWidth < 400 ? 12.0 : 16.0;
    final iconSize = screenWidth < 400 ? 40.0 : 50.0;
    final fontSize = screenWidth < 400 ? 14.0 : 16.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(
          color: isActive ? AppColors.goldColor.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
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
                      committee["name"]?[0]?.toUpperCase() ?? "C",
                      style: TextStyle(
                        fontSize: screenWidth < 400 ? 20.0 : 24.0,
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
                        committee["name"] ?? "Unnamed Committee",
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                adminName,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.goldSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Admin",
                                style: TextStyle(
                                  color: AppColors.goldColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w600,
                          fontSize: screenWidth < 400 ? 9.0 : 10.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Stats Row
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSimpleStat(
                              value: "$totalMembers",
                              label: "Members",
                              icon: Icons.people_outline,
                              screenWidth: screenWidth,
                            ),
                          ),
                          Expanded(
                            child: _buildSimpleStat(
                              value: "$_currencySymbol${_formatAmount(monthlyAmount)}",
                              label: type == "daily" ? "Per Day" : "Per Month",
                              icon: Icons.attach_money,
                              screenWidth: screenWidth,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSimpleStat(
                              value: "$_currencySymbol${_formatAmount(totalAmount)}",
                              label: "Total",
                              icon: Icons.account_balance_wallet_outlined,
                              screenWidth: screenWidth,
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildSimpleStat(
                          value: "$totalMembers",
                          label: "Members",
                          icon: Icons.people_outline,
                          screenWidth: screenWidth,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _buildSimpleStat(
                          value: "$_currencySymbol${_formatAmount(monthlyAmount)}",
                          label: type == "daily" ? "Per Day" : "Per Month",
                          icon: Icons.attach_money,
                          screenWidth: screenWidth,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _buildSimpleStat(
                          value: "$_currencySymbol${_formatAmount(totalAmount)}",
                          label: "Total",
                          icon: Icons.account_balance_wallet_outlined,
                          screenWidth: screenWidth,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // Committee Code & Share Section
            Container(
              padding: EdgeInsets.all(screenWidth < 400 ? 8.0 : 12.0),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppColors.r12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.code, size: 16, color: AppColors.goldColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Committee Code",
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              committeeCode,
                              style: TextStyle(
                                fontSize: screenWidth < 400 ? 12.0 : 14.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: committeeCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Code copied to clipboard"),
                              backgroundColor: AppColors.goldColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppColors.r12),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.goldSoft,
                            borderRadius: BorderRadius.circular(AppColors.r8),
                          ),
                          child: Icon(Icons.copy, size: 16, color: AppColors.goldColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      borderRadius: BorderRadius.circular(AppColors.r8),
                    ),
                    child: InkWell(
                      onTap: () {
                        _showShareDialog(context, committeeCode, committee["name"] ?? "Committee", screenWidth);
                      },
                      borderRadius: BorderRadius.circular(AppColors.r8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, size: 16, color: AppColors.goldColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Share code with friends to join",
                              style: TextStyle(
                                fontSize: screenWidth < 400 ? 10.0 : 12.0,
                                color: AppColors.goldColor,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Buttons - Responsive
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 450) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.people_outline,
                              label: "View Members",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommitteeMembersScreen(
                                      committeeId: committee["id"],
                                    ),
                                  ),
                                );
                              },
                              screenWidth: screenWidth,
                            ),
                          ),
                        ],
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 8),
                        _buildActionButton(
                          icon: Icons.payment_outlined,
                          label: "Add Payment",
                          isGold: true,
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
                          screenWidth: screenWidth,
                        ),
                      ],
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.people_outline,
                          label: "View Members",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommitteeMembersScreen(
                                  committeeId: committee["id"],
                                ),
                              ),
                            );
                          },
                          screenWidth: screenWidth,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.emoji_events_outlined,
                          label: "See Assigned Members",
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
                          screenWidth: screenWidth,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.payment_outlined,
                            label: "Add Payment",
                            isGold: true,
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
                            screenWidth: screenWidth,
                          ),
                        ),
                      ],
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStat({
    required String value,
    required String label,
    required IconData icon,
    required double screenWidth,
  }) {
    final fontSize = screenWidth < 400 ? 12.0 : 14.0;
    final labelSize = screenWidth < 400 ? 9.0 : 10.0;
    final iconSize = screenWidth < 400 ? 16.0 : 18.0;

    return Column(
      children: [
        Icon(icon, size: iconSize, color: AppColors.goldColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: labelSize,
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
    required VoidCallback onTap,
    required double screenWidth,
    bool isGold = false,
  }) {
    final fontSize = screenWidth < 400 ? 10.0 : 12.0;
    final iconSize = screenWidth < 400 ? 16.0 : 18.0;
    final padding = screenWidth < 400 ? 8.0 : 12.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.r12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: padding),
          decoration: BoxDecoration(
            color: isGold ? AppColors.goldSoft : AppColors.surface2,
            borderRadius: BorderRadius.circular(AppColors.r12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: isGold ? AppColors.goldColor : AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isGold ? AppColors.goldColor : AppColors.textSecondary,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, String committeeCode, String committeeName, double screenWidth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.r20)),
        ),
        padding: EdgeInsets.all(screenWidth < 400 ? 16.0 : 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.goldColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: screenWidth < 400 ? 60.0 : 70.0,
              height: screenWidth < 400 ? 60.0 : 70.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.goldColor, AppColors.goldColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(AppColors.r16),
              ),
              child: Icon(Icons.share, size: screenWidth < 400 ? 30.0 : 35.0, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              "Invite Friends",
              style: TextStyle(
                fontSize: screenWidth < 400 ? 20.0 : 22.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Share this code with friends to join\n$committeeName",
              style: TextStyle(
                fontSize: screenWidth < 400 ? 12.0 : 14.0,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(screenWidth < 400 ? 12.0 : 16.0),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppColors.r12),
                border: Border.all(color: AppColors.goldColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    "Committee Code",
                    style: TextStyle(
                      fontSize: screenWidth < 400 ? 10.0 : 12.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    committeeCode,
                    style: TextStyle(
                      fontSize: screenWidth < 400 ? 24.0 : 28.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.goldColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: committeeCode));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Code copied!"),
                              backgroundColor: AppColors.goldColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: Icon(Icons.copy, color: AppColors.goldColor, size: screenWidth < 400 ? 20.0 : 24.0),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {
                          // Implement share functionality
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.share, color: AppColors.goldColor, size: screenWidth < 400 ? 20.0 : 24.0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommitteeDetails(BuildContext context, Map<String, dynamic> committee) {
    final startTimestamp = committee["startMonth"] as Timestamp?;
    final endTimestamp = committee["endMonth"] as Timestamp?;
    final dateRange = _formatDateRange(startTimestamp, endTimestamp);
    final status = committee["status"] ?? "Inactive";
    final monthlyAmount = (committee["monthlyAmount"] ?? 0).toInt();
    final totalAmount = (committee["totalAmount"] ?? 0).toInt();
    final totalMembers = committee["totalMembers"] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.r20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.goldColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.goldColor, AppColors.goldColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(AppColors.r16),
              ),
              child: Center(
                child: Text(
                  committee["name"]?[0]?.toUpperCase() ?? "C",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              committee["name"] ?? "Committee Details",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildDetailRow("Type", committee["type"] ?? "Monthly"),
            _buildDetailRow("Members", "$totalMembers"),
            _buildDetailRow("Per Month", "$_currencySymbol${_formatAmount(monthlyAmount)}"),
            _buildDetailRow("Total Amount", "$_currencySymbol${_formatAmount(totalAmount)}"),
            _buildDetailRow("Date Range", dateRange),
            _buildDetailRow("Status", status, isStatus: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppColors.r12),
              ),
              child: Row(
                children: [
                  Icon(Icons.code, size: 16, color: AppColors.goldColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      committee["committeeCode"] ?? "N/A",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: committee["committeeCode"] ?? ""));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Code copied")),
                      );
                    },
                    child: Icon(Icons.copy, size: 16, color: AppColors.goldColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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