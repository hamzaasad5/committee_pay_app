import 'package:committee_pay_app/views/my_committees/add_monthly_committee_screen.dart';
import 'package:committee_pay_app/views/my_committees/add_daily_committee_screen.dart';
import 'package:committee_pay_app/views/my_committees/add_user_payment.dart';
import 'package:committee_pay_app/views/my_committees/my_committees.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/committees_provider.dart';
import '../../services/error_handler.dart';
import '../../widgets/loading_overlay.dart';
import '../chats/widgets/member_assignment_home.dart';

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
  List<Map<String, dynamic>> _userCommittees = [];
  late CommitteesProvider _committeesProvider;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _committeesProvider = CommitteesProvider();
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
    _committeesProvider.dispose();
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

      final query = await FirebaseFirestore.instance
          .collection("committees")
          .where("committeeCode", isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ErrorHandler.showError(context, 'Invalid committee code');
        return;
      }

      final doc = query.docs.first;
      final committeeId = doc.id;
      final committeeData = doc.data();

      final startDate = (committeeData['startDate'] as Timestamp?)?.toDate();
      if (startDate != null && startDate.isBefore(DateTime.now())) {
        ErrorHandler.showError(context, 'This committee has already started');
        return;
      }

      final membersMap = Map<String, bool>.from(committeeData['membersMap'] ?? {});
      final members = List<Map<String, dynamic>>.from(committeeData['members'] ?? []);
      final membersPayments = Map<String, dynamic>.from(committeeData['membersPayments'] ?? {});

      if (membersMap.containsKey(_currentUser!.uid)) {
        ErrorHandler.showError(context, 'You are already a member of this committee');
        return;
      }

      if (members.length >= (committeeData['maxMembers'] ?? 10)) {
        ErrorHandler.showError(context, 'Committee is full');
        return;
      }

      membersMap[_currentUser!.uid] = true;

      members.add({
        "name": _userModel!.name,
        "phone": _userModel!.phone,
        "uid": _currentUser!.uid,
        "email": _userModel!.email,
        "joinedAt": Timestamp.now(),
        "status": "active",
      });

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

      // Update committee document
      await FirebaseFirestore.instance
          .collection("committees")
          .doc(committeeId)
          .update({
        "membersMap": membersMap,
        "members": members,
        "membersPayments": membersPayments,
        "updatedAt": Timestamp.now(),
      });

      // 🔹 Create or update chat document using the provider
      await _committeesProvider.createOrUpdateChatOnJoin(
        committeeId: committeeId,
        committeeName: committeeData['name'],
        committeeImage: committeeData['image'],
        userId: _currentUser!.uid,
        userName: _userModel!.name,
      );

      // Add activity
      await FirebaseFirestore.instance.collection("activity").add({
        "userId": _currentUser!.uid,
        "type": "committee_join",
        "committeeId": committeeId,
        "committeeName": committeeData['name'],
        "timestamp": Timestamp.now(),
        "details": "Joined committee: ${committeeData['name']}",
      });

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

    _showCommitteeSelectionDialog();
  }

  void _showCommitteeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r16),
        ),
        title: const Text(
          "Select Committee",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _userCommittees.length,
            itemBuilder: (context, index) {
              final committee = _userCommittees[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppColors.r12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
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
                        committee['type'] == 'daily' ? '📅' : '📆',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  title: Text(
                    committee['name'] ?? 'Unnamed Committee',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${committee['type']} committee',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
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
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: _currentUser == null
          ? _buildNotLoggedInView()
          : RefreshIndicator(
        onRefresh: _initializeUser,
        color: AppColors.goldColor,
        backgroundColor: AppColors.surfaceDark,
        child: _buildMainContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Committee Pay",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 20,
        ),
      ),
      backgroundColor: AppColors.surfaceDark,
      elevation: 0,
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: AppColors.goldColor),
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.goldColor, AppColors.goldColor.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_circle,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Not Logged In',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please login to access your committees',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.r12),
              ),
            ),
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldColor),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWelcomeSection(),
        const SizedBox(height: 20),
        _buildJoinCommitteeSection(),
        const SizedBox(height: 24),
        _buildQuickActions(),
        const SizedBox(height: 30),
        _buildActivitySection(),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.goldColor,
            AppColors.goldColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppColors.r16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _userModel?.name?[0]?.toUpperCase() ?? '?',
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
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  _userModel?.name?.split(' ')[0] ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_userCommittees.length} Committees',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCommitteeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Join a Committee",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the committee code provided by your organizer",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _joinCodeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter committee code",
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.code, color: AppColors.goldColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.r12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.r12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.r12),
                  borderSide: const BorderSide(color: AppColors.goldColor, width: 2),
                ),
                filled: true,
                fillColor: AppColors.surface2,
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
                  backgroundColor: AppColors.goldColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
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
            style: TextStyle(
              fontSize: 18,
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
            childAspectRatio: 1.1,
          ),
          children: [
            _QuickActionCard(
              title: "Daily\nCommittee",
              icon: Icons.add,
              color: AppColors.goldColor,
              onTap: () => _navigateToScreen(
                DailyCommitteeScreen(adminId: _currentUser!.uid),
              ),
            ),
            _QuickActionCard(
              title: "Monthly\nCommittee",
              icon: Icons.add_box_outlined,
              color: AppColors.orange,
              onTap: () => _navigateToScreen(
                MonthlyCommitteeScreen(adminId: _currentUser!.uid),
              ),
            ),
            _QuickActionCard(
              title: "Assign\nMonth",
              icon: Icons.add_task,
              color: AppColors.green,
              onTap: () => _navigateToScreen(
                MemberAssignmentHome(),
              ),
            ),
            _QuickActionCard(
              title: "My\nCommittees",
              icon: Icons.group,
              color: AppColors.purple,
              onTap: () => _navigateToScreen(
                MyCommitteesScreen(userId: _currentUser!.uid),
              ),
            ),
          ],
        ),
        if (_userCommittees.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(AppColors.r12),
              border: Border.all(color: AppColors.goldColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.goldColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are in ${_userCommittees.length} active ${_userCommittees.length == 1 ? 'committee' : 'committees'}',
                    style: TextStyle(color: Colors.white),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  dropdownColor: AppColors.surfaceDark,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.goldColor),
                  style: TextStyle(color: AppColors.textSecondary),
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
                Icon(Icons.error_outline, color: AppColors.red, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Error loading activities',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.goldColor),
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
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  "No activity found",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
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
                iconColor = AppColors.green;
                break;
              case "committee_join":
                iconData = Icons.group_add;
                iconColor = AppColors.blue;
                break;
              case "committee_create":
                iconData = Icons.add_circle;
                iconColor = AppColors.orange;
                break;
              default:
                iconData = Icons.notifications;
                iconColor = AppColors.goldColor;
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppColors.r12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity["details"] ?? "Activity",
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(timestamp),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
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
        content: const Text(
          'Notifications coming soon!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.goldColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.r12),
        ),
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
      borderRadius: BorderRadius.circular(AppColors.r16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppColors.r16),
          border: Border.all(color: AppColors.border),
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
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