import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/committees_provider.dart';
import '../../../utils/app_local_storage.dart';
import 'committee_chat_screen.dart';

class MemberAssignmentScreen extends StatefulWidget {
  final String committeeId;
  const MemberAssignmentScreen({super.key, required this.committeeId});

  @override
  State<MemberAssignmentScreen> createState() =>
      _MemberAssignmentScreenState();
}

class _MemberAssignmentScreenState extends State<MemberAssignmentScreen> {
  Map<String, dynamic>? _committee;
  bool loading = true;
  bool isSaving = false;

  String? selectedMonth;
  String? selectedMemberId;
  String? currentUserId;

  List<MapEntry<int, String>> _availableMonths = [];

  final Map<int, String> monthNames = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
  };

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchUser() async {
    currentUserId = await LocalStorage.getUserId();
    fetchCommittee();
  }

  Future<void> fetchCommittee() async {
    try {
      final provider = context.read<CommitteesProvider>();
      final data = await provider.fetchCommitteeById(widget.committeeId);

      if (mounted) {
        setState(() {
          _committee = data;
          _calculateAvailableMonths();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });
        Fluttertoast.showToast(
          msg: "Error loading committee: $e",
          backgroundColor: AppColors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _calculateAvailableMonths() {
    if (_committee == null) return;

    final startDateStr = _committee!["startDate"] as String?;

    if (startDateStr == null) {
      _availableMonths = monthNames.entries.toList();
      return;
    }

    try {
      final startDate = DateTime.parse(startDateStr);
      int startMonth = startDate.month;
      int startYear = startDate.year;

      final members = List<Map<String, dynamic>>.from(_committee!["members"] ?? []);
      final memberCount = members.length;

      if (memberCount == 0) {
        _availableMonths = [];
        return;
      }

      List<MapEntry<int, String>> generatedMonths = [];
      int currentMonth = startMonth;
      int currentYear = startYear;

      for (int i = 0; i < memberCount; i++) {
        generatedMonths.add(MapEntry(currentMonth, monthNames[currentMonth]!));

        if (currentMonth == 12) {
          currentMonth = 1;
          currentYear++;
        } else {
          currentMonth++;
        }
      }

      _availableMonths = generatedMonths;
    } catch (e) {
      _availableMonths = monthNames.entries.toList();
    }
  }

  String _monthLabel(String monthKey) {
    if (monthKey.isEmpty) return "";
    final number = int.tryParse(monthKey.replaceAll("Month", ""));
    return number != null ? monthNames[number] ?? monthKey : monthKey;
  }

  bool _isMonthAssigned(String monthKey) {
    if (_committee == null) return false;
    final assignments = _committee!["winners"];
    if (assignments == null) return false;
    return assignments.containsKey(monthKey);
  }

  bool _isMemberAssignedToAnyMonth(String memberId) {
    if (_committee == null || memberId.isEmpty) return false;
    final assignments = _committee!["winners"];
    if (assignments == null) return false;
    return assignments.containsValue(memberId);
  }

  String _getMonthNumber(String monthKey) {
    if (monthKey.isEmpty) return "";
    return monthKey.replaceAll("Month", "");
  }

  int _getUnassignedMembersCount(List<Map<String, dynamic>> members) {
    int count = 0;
    for (var member in members) {
      final id = (member["uid"] ?? member["phone"]).toString();
      if (!_isMemberAssignedToAnyMonth(id)) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.goldColor),
              SizedBox(height: 16),
              Text(
                "Loading committee...",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_committee == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text(
            "Assign Members",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.goldColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.red),
              SizedBox(height: 16),
              Text(
                "Failed to load committee data",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final committee = _committee!;
    final members = List<Map<String, dynamic>>.from(committee["members"] ?? []);
    final assignments = Map<String, dynamic>.from(committee["winners"] ?? {});
    final bool isCreator = committee["adminId"] == currentUserId;

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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: AppColors.goldColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommitteeChatScreen(
                      committeeId: widget.committeeId,
                      committeeName: committee["name"] ?? "Committee Chat",
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: isSaving
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.goldColor),
            const SizedBox(height: 16),
            Text(
              "Assigning member...",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: fetchCommittee,
        color: AppColors.goldColor,
        backgroundColor: AppColors.surfaceDark,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (isCreator) _buildAssignmentForm(committee, members),
                  if (isCreator) const SizedBox(height: 24),
                  _buildSectionHeader(assignments.length),
                  const SizedBox(height: 16),
                  if (assignments.isEmpty)
                    _buildEmptyState(isCreator)
                  else
                    ...assignments.entries.map((entry) =>
                        _buildAssignmentCard(entry, members)).toList(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentForm(
      Map<String, dynamic> committee,
      List<Map<String, dynamic>> members,
      ) {
    final unassignedCount = _getUnassignedMembersCount(members);
    final assignments = Map<String, dynamic>.from(committee["winners"] ?? {});
    final assignedCount = assignments.length;
    final totalMonths = _availableMonths.length;
    final remainingMonths = totalMonths - assignedCount;
    final allMembersAssigned = unassignedCount == 0;
    final allMonthsAssigned = assignedCount >= totalMonths;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: AppColors.goldColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Create Assignment",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(AppColors.r12),
                border: Border.all(color: AppColors.goldColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.goldColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Members: ${members.length} | "
                          "Months: $totalMonths | "
                          "Remaining: ${remainingMonths > 0 ? remainingMonths : 0}",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.goldColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (allMembersAssigned || allMonthsAssigned) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenBg,
                  borderRadius: BorderRadius.circular(AppColors.r12),
                  border: Border.all(color: AppColors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        allMembersAssigned
                            ? "All members have been assigned!"
                            : "All months have been assigned!",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Month Dropdown
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppColors.r12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedMonth,
                isExpanded: true,
                hint: Text(
                  "Select Month",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today, color: AppColors.goldColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                dropdownColor: AppColors.surfaceDark,
                style: const TextStyle(color: Colors.white),
                items: _availableMonths.map((entry) {
                  final key = "Month${entry.key}";
                  final monthName = entry.value;
                  final assigned = _isMonthAssigned(key);

                  return DropdownMenuItem<String>(
                    value: key,
                    enabled: !assigned,
                    child: Text(
                      assigned ? "$monthName (Assigned)" : monthName,
                      style: TextStyle(
                        color: assigned ? AppColors.textSecondary : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && !_isMonthAssigned(value)) {
                    setState(() => selectedMonth = value);
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Member Dropdown
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppColors.r12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedMemberId,
                isExpanded: true,
                hint: Text(
                  "Select Member",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person, color: AppColors.goldColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                dropdownColor: AppColors.surfaceDark,
                style: const TextStyle(color: Colors.white),
                items: members.map((m) {
                  final id = (m["uid"] ?? m["phone"]).toString();
                  final name = m["name"] ?? "Unknown";
                  final assigned = _isMemberAssignedToAnyMonth(id);

                  return DropdownMenuItem<String>(
                    value: id,
                    enabled: !assigned,
                    child: Text(
                      assigned ? "$name (Assigned)" : name,
                      style: TextStyle(
                        color: assigned ? AppColors.textSecondary : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && !_isMemberAssignedToAnyMonth(value)) {
                    setState(() => selectedMemberId = value);
                  }
                },
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (selectedMonth != null &&
                    selectedMemberId != null &&
                    !_isMonthAssigned(selectedMonth!) &&
                    !_isMemberAssignedToAnyMonth(selectedMemberId!))
                    ? _saveAssignment
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.r12),
                  ),
                ),
                child: const Text(
                  "Save Assignment",
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

  Widget _buildSectionHeader(int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.goldSoft,
            borderRadius: BorderRadius.circular(AppColors.r12),
          ),
          child: Icon(
            Icons.assignment_turned_in,
            color: AppColors.goldColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          "Assigned Members",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.goldColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(
      MapEntry<String, dynamic> entry,
      List<Map<String, dynamic>> members,
      ) {
    final member = members.firstWhere(
          (m) => (m["uid"] ?? m["phone"]).toString() == entry.value.toString(),
      orElse: () => {"name": "Unknown Member"},
    );

    final monthKey = entry.key.toString();
    final monthNumber = _getMonthNumber(monthKey);
    final monthLabel = _monthLabel(monthKey);
    final memberName = member["name"]?.toString() ?? "Unknown Member";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
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
                  monthNumber.isNotEmpty ? monthNumber : "?",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthLabel.isNotEmpty ? monthLabel : "Unknown Month",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        memberName,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.green,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCreator) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppColors.r20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 60,
              color: AppColors.goldColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No Assignments Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCreator
                ? "Create your first assignment above"
                : "No assignments have been created yet",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _saveAssignment() async {
    if (selectedMonth == null || selectedMemberId == null) return;

    setState(() => isSaving = true);

    try {
      final provider = context.read<CommitteesProvider>();
      await provider.saveWinnerManual(
        committeeId: widget.committeeId,
        monthKey: selectedMonth!,
        memberId: selectedMemberId!,
      );

      if (mounted) {
        setState(() {
          selectedMonth = null;
          selectedMemberId = null;
        });
        await fetchCommittee();

        Fluttertoast.showToast(
          msg: "Assignment saved successfully!",
          backgroundColor: AppColors.green,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Error: ${e.toString()}",
          backgroundColor: AppColors.red,
          textColor: Colors.white,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}