import 'package:committee_pay_app/views/my_committees/add_monthly_committee_screen.dart';
import 'package:committee_pay_app/views/my_committees/add_daily_committee_screen.dart';
import 'package:committee_pay_app/views/my_committees/add_user_payment.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/error_handler.dart';
import '../../widgets/loading_overlay.dart';
// import '../../widgets/loading_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _joinCodeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isJoining = false;
  String _selectedFilter = "Today";
  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = true;

  // List to store user's committees for payment selection
  List<Map<String, dynamic>> _userCommittees = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser != null) {
        await _loadUserData();
        await _loadUserCommittees();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to initialize user data');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadUserCommittees() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('committees')
          .where('membersMap.${_currentUser!.uid}', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _userCommittees = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading user committees: $e');
    }
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> getActivityQuery() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    try {
      switch (_selectedFilter) {
        case "Today":
          start = DateTime(now.year, now.month, now.day);
          end = start.add(const Duration(days: 1));
          break;
        case "Yesterday":
          start = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 1));
          end = start.add(const Duration(days: 1));
          break;
        default:
          start = DateTime(2000);
          end = now.add(const Duration(days: 1));
      }

      return FirebaseFirestore.instance
          .collection("activity")
          .where("userId", isEqualTo: _currentUser?.uid)
          .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where("timestamp", isLessThan: Timestamp.fromDate(end))
          .orderBy("timestamp", descending: true);
    } catch (e) {
      debugPrint('Error creating activity query: $e');
      return FirebaseFirestore.instance
          .collection("activity")
          .where("userId", isEqualTo: _currentUser?.uid)
          .orderBy("timestamp", descending: true);
    }
  }

  Future<void> joinCommittee() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentUser == null || _userModel == null) {
      ErrorHandler.showError(context, 'User not logged in');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final code = _joinCodeController.text.trim().toUpperCase();

      // Find committee by code
      final query = await FirebaseFirestore.instance
          .collection("committees")
          .where("committeeCode", isEqualTo: code)
          .where("isActive", isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ErrorHandler.showError(context, 'Invalid committee code');
        return;
      }

      final doc = query.docs.first;
      final committeeId = doc.id;
      final committeeData = doc.data();

      // Check if committee has started
      final startDate = (committeeData['startDate'] as Timestamp?)?.toDate();
      if (startDate != null && startDate.isBefore(DateTime.now())) {
        ErrorHandler.showError(context, 'This committee has already started');
        return;
      }

      // Get current committee data
      final membersMap = Map<String, bool>.from(committeeData['membersMap'] ?? {});
      final members = List<Map<String, dynamic>>.from(committeeData['members'] ?? []);
      final membersPayments = Map<String, dynamic>.from(committeeData['membersPayments'] ?? {});

      // Check if already member
      if (membersMap.containsKey(_currentUser!.uid)) {
        ErrorHandler.showError(context, 'You are already a member of this committee');
        return;
      }

      // Check member limit
      if (members.length >= (committeeData['maxMembers'] ?? 10)) {
        ErrorHandler.showError(context, 'Committee is full');
        return;
      }

      // Add new member
      membersMap[_currentUser!.uid] = true;

      members.add({
        "name": _userModel!.name,
        "phone": _userModel!.phone,
        "uid": _currentUser!.uid,
        "email": _userModel!.email,
        "joinedAt": Timestamp.now(),
        "status": "active",
      });

      // Initialize payments
      if (!membersPayments.containsKey(_currentUser!.uid)) {
        final startMonth = (committeeData['startMonth'] as Timestamp?)?.toDate();
        final endMonth = (committeeData['endMonth'] as Timestamp?)?.toDate();

        if (startMonth != null && endMonth != null) {
          final payments = <String, String>{};
          var currentMonth = DateTime(startMonth.year, startMonth.month);

          while (!currentMonth.isAfter(endMonth)) {
            final key = DateFormat('yyyy-MM').format(currentMonth);
            payments[key] = "pending";
            currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
          }

          membersPayments[_currentUser!.uid] = payments;
        }
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection("committees")
          .doc(committeeId)
          .update({
        "membersMap": membersMap,
        "members": members,
        "membersPayments": membersPayments,
        "updatedAt": Timestamp.now(),
      });

      // Log activity
      await FirebaseFirestore.instance.collection("activity").add({
        "userId": _currentUser!.uid,
        "type": "committee_join",
        "committeeId": committeeId,
        "committeeName": committeeData['name'],
        "timestamp": Timestamp.now(),
        "details": "Joined committee: ${committeeData['name']}",
      });

      // Refresh user committees list
      await _loadUserCommittees();

      if (mounted) {
        ErrorHandler.showSuccess(
            context,
            'Successfully joined ${committeeData['name']}'
        );
      }

      _joinCodeController.clear();
      _formKey.currentState!.reset();

    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to join committee: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _navigateToScreen(Widget screen) {
    if (_currentUser == null) {
      ErrorHandler.showError(context, 'Please login first');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _navigateToAddPayment() {
    if (_currentUser == null) {
      ErrorHandler.showError(context, 'Please login first');
      return;
    }

    if (_userCommittees.isEmpty) {
      ErrorHandler.showError(context, 'You need to join a committee first');
      return;
    }

    // If user has only one committee, navigate directly
    if (_userCommittees.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddUserPayment(
            committeeId: _userCommittees.first['id'],
            currentUserId: _currentUser!.uid,
          ),
        ),
      );
      return;
    }

    // If user has multiple committees, show selection dialog
    _showCommitteeSelectionDialog();
  }

  void _showCommitteeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          "Select Committee",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _userCommittees.length,
            itemBuilder: (context, index) {
              final committee = _userCommittees[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    committee['type'] == 'daily' ? '📅' : '📆',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                title: Text(
                  committee['name'] ?? 'Unnamed Committee',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${committee['type']} committee',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddUserPayment(
                        committeeId: committee['id'],
                        currentUserId: _currentUser!.uid,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(),
      body: _currentUser == null
          ? _buildNotLoggedInView()
          : RefreshIndicator(
        onRefresh: _initializeUser,
        color: AppColors.primaryColor,
        backgroundColor: AppColors.surfaceDark,
        child: _buildMainContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "RupeeShare",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: AppColors.primaryColor,
      elevation: 4,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: _showNotifications,
        ),
      ],
    );
  }

  Widget _buildNotLoggedInView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Not Logged In',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please login to access your committees',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        _buildJoinCommitteeSection(),
        const SizedBox(height: 24),
        _buildQuickActions(),
        const SizedBox(height: 30),
        _buildActivitySection(),
      ],
    );
  }

  Widget _buildJoinCommitteeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Join a Committee",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the committee code provided by your organizer",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _joinCodeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter committee code",
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.code, color: AppColors.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a committee code';
                }
                if (value.trim().length < 6) {
                  return 'Code must be at least 6 characters';
                }
                return null;
              },
              textCapitalization: TextCapitalization.characters,
              onFieldSubmitted: (_) => joinCommittee(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : joinCommittee,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isJoining
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  "Join Committee",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            "Quick Actions",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          children: [
            _QuickActionCard(
              title: "Add Daily\nCommittee",
              icon: Icons.add,
              color: AppColors.primaryColor,
              onTap: () => _navigateToScreen(
                DailyCommitteeScreen(adminId: _currentUser!.uid),
              ),
            ),
            _QuickActionCard(
              title: "Add Monthly\nCommittee",
              icon: Icons.add_box_outlined,
              color: Colors.orange,
              onTap: () => _navigateToScreen(
                MonthlyCommitteeScreen(adminId: _currentUser!.uid),
              ),
            ),
            _QuickActionCard(
              title: "Add Payment",
              icon: Icons.add_task,
              color: Colors.green,
              onTap: _navigateToAddPayment,
            ),
            _QuickActionCard(
              title: "My\nCommittees",
              icon: Icons.group,
              color: Colors.purple,
              onTap: () {
                Navigator.pushNamed(context, '/my-committees', arguments: _currentUser!.uid);
              },
            ),
          ],
        ),
        if (_userCommittees.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are in ${_userCommittees.length} active ${_userCommittees.length == 1 ? 'committee' : 'committees'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Activity",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  dropdownColor: AppColors.surfaceDark,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                  style: TextStyle(color: Colors.grey[300]),
                  items: ["Today", "Yesterday", "All"].map((filter) {
                    return DropdownMenuItem(
                      value: filter,
                      child: Text(
                        filter,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null && mounted) {
                      setState(() => _selectedFilter = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        _buildActivityStream(),
      ],
    );
  }

  Widget _buildActivityStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: getActivityQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, color: Colors.red[300], size: 40),
                const SizedBox(height: 8),
                Text(
                  'Error loading activities',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 48,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 12),
                Text(
                  "No activity found",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final activity = docs[index].data() as Map<String, dynamic>;
            final timestamp = (activity["timestamp"] as Timestamp).toDate();
            final type = activity["type"] ?? "unknown";

            IconData iconData;
            Color iconColor;

            switch (type) {
              case "payment":
                iconData = Icons.payment;
                iconColor = Colors.green;
                break;
              case "committee_join":
                iconData = Icons.group_add;
                iconColor = Colors.blue;
                break;
              case "committee_create":
                iconData = Icons.add_circle;
                iconColor = Colors.orange;
                break;
              default:
                iconData = Icons.notifications;
                iconColor = Colors.grey;
            }

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.2),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
                title: Text(
                  activity["details"] ?? "Activity",
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                trailing: Text(
                  DateFormat('hh:mm a').format(timestamp),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notifications coming soon!',
          style: TextStyle(color: AppColors.primaryColor),
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}