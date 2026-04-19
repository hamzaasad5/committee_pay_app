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
import '../chats/widgets/member_assignment_home.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {

  final _joinCodeController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool      _isJoining     = false;
  bool      _isLoading     = true;
  String    _selectedFilter = 'Today';

  User?      _currentUser;
  UserModel? _userModel;
  List<Map<String, dynamic>> _userCommittees = [];

  late CommitteesProvider _committeesProvider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _committeesProvider = CommitteesProvider();
    _init();
  }

  @override
  void dispose() {
    _committeesProvider.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser != null) {
        await Future.wait([_loadUserData(), _loadUserCommittees()]);
      }
    } catch (_) {
      if (mounted) ErrorHandler.showError(context, 'Failed to load data');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    if (doc.exists) _userModel = UserModel.fromFirestore(doc);
  }

  Future<void> _loadUserCommittees() async {
    final snap = await FirebaseFirestore.instance
        .collection('committees')
        .where('membersMap.${_currentUser!.uid}', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();
    setState(() {
      _userCommittees = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  // ── Stats helpers ──────────────────────────────────────────────────────────

  int get _totalPaid => _userCommittees
      .where((c) {
    final payments =
    (c['membersPayments'] as Map?)?[_currentUser?.uid] as Map?;
    if (payments == null) return false;
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    return payments[month] == 'paid';
  })
      .length;

  String _formatAmount(int amount) {
    if (amount >= 100000) {
      return 'Rs ${(amount / 100000).toStringAsFixed(1)} Lac';
    }
    if (amount >= 1000) return 'Rs ${(amount / 1000).toStringAsFixed(0)}K';
    return 'Rs $amount';
  }

  int get _thisMonthTotal {
    int total = 0;
    for (final c in _userCommittees) {
      total += ((c['monthlyAmount'] ?? 0) as num).toInt();
    }
    return total;
  }

  // ── Activity query ─────────────────────────────────────────────────────────

  Query<Map<String, dynamic>> _activityQuery() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime start;
    DateTime end = now.add(const Duration(seconds: 1));

    switch (_selectedFilter) {
      case 'Today':
        start = today;
        break;
      case 'Yesterday':
        start = today.subtract(const Duration(days: 1));
        end   = today;
        break;
      default:
        start = DateTime(2000);
    }

    return FirebaseFirestore.instance
        .collection('activity')
        .where('userId', isEqualTo: _currentUser?.uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true);
  }

  // ── Join committee ─────────────────────────────────────────────────────────

  Future<void> _joinCommittee() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null || _userModel == null) {
      ErrorHandler.showError(context, 'Please login first');
      return;
    }
    setState(() => _isJoining = true);
    try {
      final code = _joinCodeController.text.trim().toUpperCase();
      final q    = await FirebaseFirestore.instance
          .collection('committees')
          .where('committeeCode', isEqualTo: code)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        ErrorHandler.showError(context, 'Committee not found');
        return;
      }

      final doc           = q.docs.first;
      final committeeId   = doc.id;
      final data          = doc.data();
      final startDate     = (data['startDate'] as Timestamp?)?.toDate();

      if (startDate != null && startDate.isBefore(DateTime.now())) {
        ErrorHandler.showError(context, 'This committee has already started');
        return;
      }

      final membersMap     = Map<String, bool>.from(data['membersMap'] ?? {});
      final members        = List<Map<String, dynamic>>.from(data['members'] ?? []);
      final membersPayments = Map<String, dynamic>.from(data['membersPayments'] ?? {});

      if (membersMap.containsKey(_currentUser!.uid)) {
        ErrorHandler.showError(context, 'You are already a member');
        return;
      }
      if (members.length >= (data['maxMembers'] ?? 10)) {
        ErrorHandler.showError(context, 'Committee is full');
        return;
      }

      membersMap[_currentUser!.uid] = true;
      members.add({
        'name':     _userModel!.name,
        'phone':    _userModel!.phone,
        'uid':      _currentUser!.uid,
        'email':    _userModel!.email,
        'joinedAt': Timestamp.now(),
        'status':   'active',
      });

      if (!membersPayments.containsKey(_currentUser!.uid)) {
        final startMonth = (data['startMonth'] as Timestamp?)?.toDate();
        final endMonth   = (data['endMonth']   as Timestamp?)?.toDate();
        if (startMonth != null && endMonth != null) {
          final payments = <String, String>{};
          var cur = DateTime(startMonth.year, startMonth.month);
          while (!cur.isAfter(endMonth)) {
            payments[DateFormat('yyyy-MM').format(cur)] = 'pending';
            cur = DateTime(cur.year, cur.month + 1);
          }
          membersPayments[_currentUser!.uid] = payments;
        }
      }

      await FirebaseFirestore.instance
          .collection('committees')
          .doc(committeeId)
          .update({
        'membersMap':     membersMap,
        'members':        members,
        'membersPayments': membersPayments,
        'updatedAt':      Timestamp.now(),
      });

      await _committeesProvider.createOrUpdateChatOnJoin(
        committeeId:   committeeId,
        committeeName: data['name'],
        committeeImage: data['image'],
        userId:        _currentUser!.uid,
        userName:      _userModel!.name,
      );

      await FirebaseFirestore.instance.collection('activity').add({
        'userId':        _currentUser!.uid,
        'type':          'committee_join',
        'committeeId':   committeeId,
        'committeeName': data['name'],
        'timestamp':     Timestamp.now(),
        'details':       'Joined committee: ${data['name']}',
      });

      await _loadUserCommittees();
      if (mounted) {
        ErrorHandler.showSuccess(context, 'Joined ${data['name']}');
        _joinCodeController.clear();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Failed to join: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  // ── Add payment routing ────────────────────────────────────────────────────

  void _addPayment() {
    if (_currentUser == null) {
      ErrorHandler.showError(context, 'Please login first');
      return;
    }
    if (_userCommittees.isEmpty) {
      ErrorHandler.showError(context, 'Join a committee first');
      return;
    }
    if (_userCommittees.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddUserPayment(
            committeeId:   _userCommittees.first['id'],
            currentUserId: _currentUser!.uid,
          ),
        ),
      );
      return;
    }
    _showCommitteePickerSheet();
  }

  void _showCommitteePickerSheet() {
    showModalBottomSheet(
      context:      context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color:        AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppColors.r20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select committee',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ..._userCommittees.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor:    AppColors.surface2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12)),
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color:        AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(AppColors.r8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (c['name'] as String? ?? 'C')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.goldColor),
                  ),
                ),
                title: Text(c['name'] ?? 'Committee',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
                subtitle: Text(
                    '${c['type'] ?? 'monthly'} · Rs ${c['monthlyAmount'] ?? 0}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddUserPayment(
                        committeeId:   c['id'],
                        currentUserId: _currentUser!.uid,
                      ),
                    ),
                  );
                },
              ),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    if (_currentUser == null) {
      ErrorHandler.showError(context, 'Please login first');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _currentUser == null
          ? _buildNotLoggedIn()
          : SafeArea(
        child: RefreshIndicator(
          onRefresh: _init,
          color:           AppColors.goldColor,
          backgroundColor: AppColors.surfaceDark,
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.goldColor))
              : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildTopBar()),
        // SliverToBoxAdapter(child: _buildStats()),
        SliverToBoxAdapter(child: _buildJoinSection()),
        SliverToBoxAdapter(child: _buildQuickActions()),
        SliverToBoxAdapter(child: _buildActivitySection()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final firstName = _userModel?.name?.split(' ').first ?? 'User';
    final initial   = firstName[0].toUpperCase();
    final hour      = DateTime.now().hour;
    final greeting  = hour < 12 ? 'Good morning' :
    hour < 17 ? 'Good afternoon' : 'Good evening';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        AppColors.goldColor,
              shape:        BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(firstName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(greeting,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: _showNotifications,
            padding:  EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:        AppColors.surface2,
                shape:        BoxShape.circle,
                border:       Border.all(color: AppColors.border, width: 0.5),
              ),
              child: const Icon(Icons.notifications_outlined,
                  size: 18, color: AppColors.goldColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  // Widget _buildStats() {
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
  //     child: Row(
  //       children: [
  //         _StatCard(
  //           icon:  Icons.group_outlined,
  //           value: '${_userCommittees.length}',
  //           label: 'Committees',
  //         ),
  //         const SizedBox(width: 10),
  //         _StatCard(
  //           icon:  Icons.payments_outlined,
  //           value: _formatAmount(_thisMonthTotal),
  //           label: 'This month',
  //         ),
  //         const SizedBox(width: 10),
  //         _StatCard(
  //           icon:  Icons.check_circle_outline,
  //           value: '$_totalPaid/${_userCommittees.length}',
  //           label: 'Paid',
  //           highlight: true,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ── Join section ───────────────────────────────────────────────────────────

  Widget _buildJoinSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppColors.r16),
          border:       Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Join a committee',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              const Text('Enter the code shared by your organizer',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller:        _joinCodeController,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      textCapitalization: TextCapitalization.characters,
                      onFieldSubmitted:  (_) => _joinCommittee(),
                      decoration: InputDecoration(
                        hintText:  'e.g. KMT-7823',
                        hintStyle: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.tag,
                            size: 18, color: AppColors.goldColor),
                        filled:     true,
                        fillColor:  AppColors.surface2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppColors.r12),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppColors.r12),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppColors.r12),
                          borderSide: const BorderSide(
                              color: AppColors.goldColor, width: 1.5),
                        ),
                        errorStyle: const TextStyle(fontSize: 0, height: 0),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '';
                        if (v.trim().length < 6) return '';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isJoining ? null : _joinCommittee,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldColor,
                        foregroundColor: AppColors.bg,
                        elevation:       0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(AppColors.r12)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text('Join'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'QUICK ACTIONS'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon:       Icons.calendar_today_outlined,
                  iconColor:  AppColors.green,
                  label:      'Daily committee',
                  sublabel:   'Collect daily',
                  onTap: () => _push(
                      DailyCommitteeScreen(adminId: _currentUser!.uid)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon:       Icons.calendar_month_outlined,
                  iconColor:  AppColors.purple,
                  label:      'Monthly committee',
                  sublabel:   'Collect monthly',
                  onTap: () => _push(
                      MonthlyCommitteeScreen(adminId: _currentUser!.uid)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon:      Icons.add_card_outlined,
                  iconColor: AppColors.goldColor,
                  label:     'Add payment',
                  sublabel:  'Record a payment',
                  onTap:     _addPayment,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon:      Icons.event_available_outlined,
                  iconColor: AppColors.blue,
                  label:     'Assign months',
                  sublabel:  'Set turn order',
                  onTap:     () => _push(MemberAssignmentHome()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon:      Icons.group_outlined,
            iconColor: AppColors.orange,
            label:     'My committees',
            sublabel:  'View all ${_userCommittees.length} committees',
            fullWidth: true,
            onTap:     () => _push(
                MyCommitteesScreen(userId: _currentUser!.uid)),
          ),
        ],
      ),
    );
  }

  // ── Activity section ───────────────────────────────────────────────────────

  Widget _buildActivitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionLabel(label: 'RECENT ACTIVITY'),
              const Spacer(),
              // Filter pills
              ...['Today', 'Yesterday', 'All'].map((f) => GestureDetector(
                onTap: () => setState(() => _selectedFilter = f),
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedFilter == f
                        ? AppColors.goldColor
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedFilter == f
                          ? AppColors.goldColor
                          : AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _selectedFilter == f
                              ? AppColors.bg
                              : AppColors.textSecondary)),
                ),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color:        AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppColors.r16),
              border:       Border.all(color: AppColors.border, width: 0.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: StreamBuilder<QuerySnapshot>(
              stream:  _activityQuery().snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Could not load activity',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.goldColor,
                            strokeWidth: 2)),
                  );
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: 40, horizontal: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 36, color: AppColors.textSecondary),
                          SizedBox(height: 10),
                          Text('No activity yet',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap:    true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:     docs.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: AppColors.border),
                  itemBuilder: (context, i) {
                    final act = docs[i].data() as Map<String, dynamic>;
                    final ts  = (act['timestamp'] as Timestamp).toDate();
                    return _ActivityRow(activity: act, timestamp: ts);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Not logged in ──────────────────────────────────────────────────────────

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.goldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.account_circle_outlined,
                  size: 40, color: AppColors.goldColor),
            ),
            const SizedBox(height: 20),
            const Text('Not logged in',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Please login to access your committees',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldColor,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12)),
              ),
              child: const Text('Login',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notifications coming soon'),
        backgroundColor: AppColors.goldColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.r12)),
      ),
    );
  }
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: .4));
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final bool     highlight;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppColors.r12),
          border: Border.all(
            color: highlight
                ? AppColors.goldColor.withOpacity(.4)
                : AppColors.border,
            width: highlight ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size:  18,
                color: highlight
                    ? AppColors.goldColor
                    : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       label;
  final String       sublabel;
  final VoidCallback onTap;
  final bool         fullWidth;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.r12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppColors.r12),
            border:       Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color:        iconColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(AppColors.r8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(sublabel,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> activity;
  final DateTime             timestamp;

  const _ActivityRow({required this.activity, required this.timestamp});

  IconData _icon(String type) {
    switch (type) {
      case 'payment':           return Icons.payments_outlined;
      case 'committee_join':    return Icons.group_add_outlined;
      case 'committee_create':  return Icons.add_circle_outline;
      default:                  return Icons.notifications_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'payment':          return AppColors.green;
      case 'committee_join':   return AppColors.blue;
      case 'committee_create': return AppColors.orange;
      default:                 return AppColors.goldColor;
    }
  }

  String _timeText() {
    final now  = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(timestamp);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final type = activity['type'] ?? 'unknown';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:  _color(type).withOpacity(.12),
              shape:  BoxShape.circle,
            ),
            child: Icon(_icon(type), size: 18, color: _color(type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['details'] ?? 'Activity',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_timeText(),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}